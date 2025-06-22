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

    let totalRounds = 5

    var body: some View {
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
        .onReceive(NotificationCenter.default.publisher(for: .gameDidEnd)) { notification in
            if let win = notification.object as? String {
                self.winner = win
                self.gameOver = true
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
        VStack(spacing: 20) {
            Text("Welcome to Prop Call")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            TextField("Enter your name", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
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
            
            Button("Join Lobby") {
                multiplayer.configureUsername(username)
                gamePhase = .lobby
            }
            .disabled(username.isEmpty || showUsernameTakenAlert)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
        .alert("Username Taken", isPresented: $showUsernameTakenAlert) {
            Button("OK", role: .cancel) { username = "" }
        }
    }
    
    /// View for the waiting room lobby.
    @ViewBuilder
    private func LobbyView() -> some View {
        VStack(spacing: 25) {
            Text("Lobby")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Display the host
            if let host = multiplayer.hostName {
                Text("👑 Host: \(host)")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            // List of connected players
            List {
                Section(header: Text("Players (\(multiplayer.peerScores.count))")) {
                    ForEach(multiplayer.peerScores.keys.sorted(), id: \.self) { playerName in
                        Text(playerName)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            
            Button("🔄 Refresh") {
                if multiplayer.username == multiplayer.hostName {
                    multiplayer.sendFullPlayerList()
                }
            }
            
            // "Start Game" button, only visible to the host
            if multiplayer.username == multiplayer.hostName {
                Button("Start Game") {
                    // This command will trigger the 'gameShouldStartPublisher' for everyone
                    multiplayer.sendStartGameCommand()
                    startGameLocallyAndBroadcastIfHost() // Host starts game locally
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            } else {
                Text("Waiting for the host to start the game...")
                    .foregroundColor(.gray)
            }
        }
        .padding()
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
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            detector.resetRound()
                            speechRecognizer.spokenText = ""
                            showNotification = false
                            
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
                                winner = multiplayer.peerScores.max(by: { $0.value < $1.value })?.key ?? "No one"
                                gameOver = true
                                multiplayer.sendGameOver(winner: winner) // 🔥 Send to all peers
                            }
                        }
                    }
                }
            })
            .edgesIgnoringSafeArea(.all)
            
            // Game Info Overlay
            GameOverlayView()
        }
        .alert(isPresented: $gameOver) {
            Alert(
                title: Text("🏆 Game Over"),
                message: Text("Winner: \(winner)"),
                dismissButton: .default(Text("Back to Lobby")) {
                    // Reset game state and return to lobby
                    gameManager.score = 0
                    multiplayer.sendScore(0) // Announce reset score to leaderboard
                    gamePhase = .lobby
                }
            )
        }
    }

    /// The overlay displaying game stats during play.
    @ViewBuilder
    private func GameOverlayView() -> some View {
        VStack(spacing: 10) {
            // Game Info Texts
            VStack {
                Text("🎤 \(gameManager.promptText())")
                Text("⏳ Time Left: \(gameManager.timeRemaining) sec")
                Text("You said: \(speechRecognizer.spokenText)")
                Text("Detected: \(detector.detectedLabel)")
                Text("✅ Match: \(detector.matchFound ? "Yes" : "No")")
                Text("🎯 Score: \(gameManager.score)")
                Text("🔄 Round \(gameManager.round) / \(totalRounds)")
            }

            // Start/Stop Listening Button
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
            }) {
                Text(speechRecognizer.isListening ? "Stop Listening" : "Start Listening")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }

            // "You found it!" Notification
            if showNotification {
                Text("🎉 You found it!")
                    .foregroundColor(.green)
                    .font(.headline)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
            }

            // Local Leaderboard
            VStack(alignment: .leading) {
                Text("📡 Local Leaderboard")
                    .font(.headline)
                    .foregroundColor(.yellow)
                
                ForEach(multiplayer.peerScores.sorted(by: { $0.value > $1.value }), id: \.key) { name, score in
                    Text("\(name)\(multiplayer.hostName == name ? " 👑" : ""): \(score)")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(16)
        .padding()
    }
}
#Preview {
    ARVoiceIntentView()
}
