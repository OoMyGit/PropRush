//
//  ContentView.swift
//  Prop Call
//
//  Created by Alfred Hans Witono on 04/06/25.
//

import SwiftUI
import RealityKit
import ARKit
import Speech
import CoreML
import AVFoundation

// Defines the different stages of the application flow
enum GamePhase {
    case usernameEntry
    case lobby
    case inGame
}

extension Notification.Name {
    static let gameStateDidChange = Notification.Name("gameStateDidChange")
}

extension Notification.Name {
    static let gameDidEnd = Notification.Name("gameDidEnd")
}

extension Font {
    static var headingNowTitle: Font {
        .custom("HeadingNowTrial-68Heavy", size: 24) // adjust size if needed
    }
    static var subTitleNow: Font {
        .custom("HeadingNowTrial-68Heavy", size: 16) // adjust size if needed
    }
}

struct ARVoiceIntentView: View {
    // MARK: - State Objects
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var detector = VisionObjectDetector()
    @StateObject private var multiplayer = MultipeerManager()
    @StateObject private var gameManager = GameRoundManager()
    
    
    
    // MARK: - State Properties
    @State private var gamePhase: GamePhase = .usernameEntry
    @State private var username: String = ""
    @State private var showUsernameTakenAlert = false
    
    @State private var showNotification = false
    @State private var gameOver = false
    @State private var winner: String = ""
    @State private var winnerScore: Int = 0
    
    @State private var lastScoringUsername: String = ""
    @State private var lastFoundWord: String = ""
    
    @State private var isLoading = true
    @State private var isInWaitingRoom = false
    
    let totalRounds = 5
    
    var body: some View {
        ZStack {
            if isLoading {
                Image("LoadingPage")
                    .resizable()
                    .scaledToFill()
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        
                        DispatchQueue.main.async {
                            do {
                                let audioSession = AVAudioSession.sharedInstance()
                                try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                                speechRecognizer.startListening()
                            } catch {
                                print("Audio Session error: \(error)")
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isLoading = false
                        }
                    }
            }
            else {
                
                ZStack {
                    
                    // The main view switches based on the current game phase
                    switch gamePhase {
                    case .usernameEntry:
                        UsernameEntryView()
                    case .lobby:
                        LobbyView()
                    case .inGame:
                        GameView()
                    }
                }
                .onReceive(multiplayer.gameShouldStartPublisher) {
                    startGameLocallyAndBroadcastIfHost()
                }
                .onAppear {
                    // Ensures the host also starts immediately after pressing "Start Game"
                    if multiplayer.username == multiplayer.hostName && gamePhase == .lobby {
                        multiplayer.gameShouldStartPublisher.send()
                    }
                    
                    // Observe local game state change (e.g., timer expired without match)
                    NotificationCenter.default.addObserver(forName: .gameStateDidChange, object: nil, queue: .main) { _ in
                        if multiplayer.username == multiplayer.hostName {
                            multiplayer.sendGameState(
                                round: gameManager.round,
                                score: gameManager.score,
                                currentLetter: gameManager.currentLetter,
                                timeRemaining: gameManager.timeRemaining
                            )
                        }
                    }
                }
                .onReceive(multiplayer.receivedGameStatePublisher) { state in
                    gameManager.setState(
                        round: state.round,
                        score: gameManager.score, // Keep local score
                        currentLetter: state.currentLetter,
                        timeRemaining: state.timeRemaining
                    )
                }
                .onReceive(NotificationCenter.default.publisher(for: .roundDidEnd)) { _ in
                    if !showNotification {
                        showNotification = true
                        gameManager.endRound()

                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            detector.resetRound()
                            speechRecognizer.spokenText = ""
                            showNotification = false
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .gameDidEnd)) { notification in
                    if let win = notification.object as? String {
                        self.winner = win
                        self.gameOver = true
                    }
                }
                
                
            }
        }
        
    }
    
    private func startGameLocallyAndBroadcastIfHost() {
        gameManager.startGame()
        
        if multiplayer.username == multiplayer.hostName {
            multiplayer.sendGameState(
                round: gameManager.round,
                score: gameManager.score,
                currentLetter: gameManager.currentLetter,
                timeRemaining: gameManager.timeRemaining
            )
        }
        
        gamePhase = .inGame
    }
    
    
    // MARK: - Subviews for each Game Phase
    
    /// View for entering the player's name.
    @ViewBuilder
    private func UsernameEntryView() -> some View {
        ZStack{
            Image("MainPage")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing:50)
            {
                
                TextField("Enter your name", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .padding(.vertical, 10)
                    .padding(.horizontal, 60)
                    .onChange(of: username) { _, newValue in
                        if newValue.isEmpty { // Don't trigger alert for empty string
                            showUsernameTakenAlert = false
                        } else if multiplayer.peerScores.keys.contains(newValue) && newValue != multiplayer.username {
                            // Only show alert if the new username is in peerScores AND it's NOT our own username
                            showUsernameTakenAlert = true
                        } else {
                            showUsernameTakenAlert = false
                        }
                    }
                    .alert("Username Taken", isPresented: $showUsernameTakenAlert) {
                        Button("OK", role: .cancel) {
                            username = "" // Still good to clear if it was genuinely taken by someone else
                        }
                    }
                
                Button("                                                ") {
                    multiplayer.configureUsername(username)
                    gamePhase = .lobby
                }
                //                .disabled(username.isEmpty || showUsernameTakenAlert)
                .padding()
                .background(Color.clear)
                .foregroundColor(.white)
                .cornerRadius(10)
                .offset(y: 208)
                .padding(.horizontal, 70)
                .padding(.vertical, 50)
                
                .frame(width: 300, height:45)
            }
            .padding()
            .alert("Username Taken", isPresented: $showUsernameTakenAlert) {
                Button("OK", role: .cancel) { username = "" }
            }
            
        }
        
    }
    
    /// View for the waiting room lobby.
    @ViewBuilder
    private func LobbyView() -> some View {
        ZStack {
            if multiplayer.username == multiplayer.hostName {
                
                Image("WaitingHost")
                    .resizable()
                    .scaledToFill()
                    .edgesIgnoringSafeArea(.all)
            }
            else
            {
                Image("WaitingPlayer")
                    .resizable()
                    .scaledToFill()
                    .edgesIgnoringSafeArea(.all)
            }
            
            VStack (spacing: 0) {
                // List of connected players
                
                
                //            Button("🔄 Refresh") {
                //                if multiplayer.username == multiplayer.hostName {
                //                    multiplayer.sendFullPlayerList()
                //                }
                //            }
                
                // "Start Game" button, only visible to the host
                if multiplayer.username == multiplayer.hostName {
                    
                    if let host = multiplayer.hostName {
                        Text("👑 Host: \(host)")
                            .font(.headingNowTitle)
                            .fontWeight(.semibold)
                            .offset(y:130)
                            .font(.custom("Funtastic", size: 18))
                    }
                    
                    List {
                        Section {
                            ForEach(Array(multiplayer.peerScores.keys.sorted().enumerated()), id: \.element) { index, playerName in
                                Text("P\(index + 1). \(playerName)")
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                                    .listRowBackground(Color.clear)
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .offset(y: 310)
                    .padding(.horizontal, 50)
                    
                    
                    Button("            ") {
                        // This command will trigger the 'gameShouldStartPublisher' for everyone
                        multiplayer.sendStartGameCommand()
                        startGameLocallyAndBroadcastIfHost() // Host starts game locally
                    }
                    .padding(.horizontal, 55)
                    .padding(.vertical, 15)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .offset(y:-120)
                    
                } else {
                    if let host = multiplayer.hostName {
                        Text("👑 Host: \(host)")
                            .font(.headingNowTitle)
                            .fontWeight(.semibold)
                            .offset(y:130)
                            .foregroundColor(.white)
                    }
                    
                    List {
                        Section {
                            ForEach(Array(multiplayer.peerScores.keys.sorted().enumerated()), id: \.element) { index, playerName in
                                Text("P\(index + 1) \(playerName)")
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                                    .listRowBackground(Color.clear)
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .offset(y: 310)
                    .padding(.horizontal, 50)
                }
            }
            .padding()
            .onAppear {
                if multiplayer.username == multiplayer.hostName {
                    Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                        multiplayer.sendFullPlayerList()
                    }
                }
            }
        }
    }
    
    /// The main AR game view.
    @ViewBuilder
    private func GameView() -> some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(didCaptureBuffer: { scannedImage in
                // Core game logic remains the same
                detector.detectObject(in: scannedImage)
                detector.checkMatch(
                    with: speechRecognizer.spokenText,
                    startsWith: gameManager.currentLetter
                ) {
                    if !showNotification {
                        showNotification = true
                        gameManager.endRound()
                        multiplayer.sendRoundEnded()
                        
                        if gameManager.round < totalRounds {
                                gameManager.incrementScoreAndNextRound {
                                    multiplayer.sendGameState(
                                        round: gameManager.round,
                                        score: gameManager.score,
                                        currentLetter: gameManager.currentLetter,
                                        timeRemaining: gameManager.timeRemaining
                                    )
                                    multiplayer.sendScore(gameManager.score)
                                }
                        } else {
                            gameManager.stop()
                            winner = multiplayer.peerScores.max(by: { $0.value < $1.value })?.key ?? "DRAW"
                            winnerScore = multiplayer.peerScores.max(by: { $0.value < $1.value })?.value ?? 0
                            gameOver = true
                            multiplayer.sendGameOver(winner: winner) //
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            detector.resetRound()
                            speechRecognizer.spokenText = ""
                            showNotification = false
                            lastScoringUsername = ""
                            lastFoundWord = ""
                        }
                    }
                }
            })
            .edgesIgnoringSafeArea(.all)
            .onReceive(gameManager.$roundEnded) { ended in
                if ended && gameManager.lastEndedByTimeout && !showNotification {
                    showNotification = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        showNotification = false
                    }
                }
            }

            // Game Info Overlay
            GameOverlayView()
        }
        ZStack {
            if gameOver {
                ZStack {
                    Image("Winner")
                        .resizable()
                        .scaledToFill()
                        .frame(width: UIScreen.main.bounds.width,
                               height: UIScreen.main.bounds.height)
                        .ignoresSafeArea()
                    
                    Text("\(winner) Won!")
                        .font(.headingNowTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .offset(y: -107)
                    
                    Text("\(winnerScore)")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .offset(y: 179)
                    
                    // A "Back to Lobby" button
                    Button("     ") {
                        
                        gameManager.score = 0
                            gameManager.round = 0
                            gameManager.currentLetter = ""
                            gameManager.timeRemaining = 0

                            multiplayer.sendScore(0)
                            multiplayer.sendResetGame()
                            
                            gamePhase = .lobby
                    }
                    .font(.headingNowTitle)
                    .padding(.horizontal, 70)
                    .padding(.vertical, 20)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                    .offset(y: 264)
                }
            }
        }
        
        
        //        .alert(isPresented: $gameOver) {
        //
        //
        //
        //
        //            Alert(
        //                title: Text("🏆 Game Over"),
        //                message: Text("Winner: \(winner)"),
        //                dismissButton: .default(Text("Back to Lobby")) {
        //                    // Reset game state and return to lobby
        //                    gameManager.score = 0
        //                    multiplayer.sendScore(0) // Announce reset score to leaderboard
        //                    gamePhase = .lobby
        //                }
        //            )
        //        }
    }
    
    /// The overlay displaying game stats during play.
    @ViewBuilder
    private func GameOverlayView() -> some View {
        VStack(spacing: 10) {
            Button(action: {
                if speechRecognizer.isListening {
                    speechRecognizer.stopListening()
                } else {
                    // Permission requests and start listening
                    SFSpeechRecognizer.requestAuthorization { authStatus in
                        if authStatus == .authorized {
                            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                                if granted {
                                    DispatchQueue.main.async {
                                        speechRecognizer.startListening()
                                    }
                                }
                            }
                        }
                    }
                }
            })  {
                
                ZStack{
                    
                    Image("FindLetter")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    
                    Text("Round \(gameManager.round) / \(totalRounds)")
                        .font(.system(size: 15))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .offset(y: -300)
                    
                    Text("Detected: \(detector.detectedLabel)")
                        .font(.system(size: 10))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .offset(y: -150)
                    
                    Text("⏳ Time Left: \(gameManager.timeRemaining) sec")
                        .font(.system(size: 15))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .offset(y: -180)
                    
                    Text("\"\(gameManager.currentLetter)\"")
                        .font(.system(size: 12))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .offset(x:22, y: -226)
                    
                    Text("""
                        You said:
                        \(speechRecognizer.spokenText)
                        """)
                    .font(.subTitleNow)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .offset(y: 185)
                    
                    Image(speechRecognizer.isListening ? "Submit" : "Answer")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .offset(y: 50)
                    
                    Text("🎯 Your Score: \(gameManager.score)")
                        .font(.system(size: 10))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .offset(y: 225)
                }
            }
            // "You found it!" Notification
            if showNotification {
                
                ZStack{
                    Image("Leaderboard")
                        .resizable()
                        .scaledToFill()
                        .frame(width: UIScreen.main.bounds.width,
                               height: UIScreen.main.bounds.height)
                        .ignoresSafeArea()
                    
                    Text("\(lastScoringUsername)")
                        .font(.headingNowTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .offset(y: -347)
                    
                    Text("\(lastFoundWord)")
                        .font(.headingNowTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .offset(y: -300)
                    
                    CountdownView()
                        .offset(x: 52, y: 350)
                
                    VStack(alignment: .leading) {
                        
                        ForEach(multiplayer.peerScores.sorted(by: { $0.value > $1.value }), id: \.key) { name, score in
                            Text("\(name)\(multiplayer.hostName == name ? " 👑" : ""): \(score)")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .offset(y: 30)
                            
                        }
                    }
                }
            }
        }
        .padding()
        .cornerRadius(16)
        .padding()
    }
}
#Preview {
    ARVoiceIntentView()
}
