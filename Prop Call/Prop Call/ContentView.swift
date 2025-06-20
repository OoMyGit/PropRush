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

struct ARVoiceIntentView: View {
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var detector = VisionObjectDetector()
    @StateObject private var multiplayer = MultipeerManager()
    @StateObject private var gameManager = GameRoundManager()

    @State private var showNotification = false
    @State private var gameOver = false
    @State private var winner: String = ""
    @State private var isUsernameSet = false
    @State private var username: String = ""

    @State private var isLoading = true // Loading state

    let totalRounds = 5

    var body: some View {
        ZStack {
            if isLoading {
                // Loading screen
                Image("2")
                    .resizable()
                    .scaledToFill()
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isLoading = false
                        }
                    }
            } else {
                // Main game content
                ZStack(alignment: .bottom) {
                    if isUsernameSet {
                        ARViewContainer(didCaptureBuffer: { scannedImage in
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
                                            }
                                        } else {
                                            gameOver = true
                                            gameManager.stop()
                                            winner = multiplayer.peerScores.max(by: { $0.value < $1.value })?.key ?? "No one"
                                        }
                                    }
                                }
                            }
                        })
                        .edgesIgnoringSafeArea(.all)

                        VStack(spacing: 10) {
                            Text("🎤 \(gameManager.promptText())")
                            Text("⏳ Time Left: \(gameManager.timeRemaining) sec")
                            Text("You said: \(speechRecognizer.spokenText)")
                            Text("Detected: \(detector.detectedLabel)")
                            Text("✅ Match: \(detector.matchFound ? "Yes" : "No")")
                            Text("🎯 Score: \(gameManager.score)")
                            Text("🔄 Round \(gameManager.round) / \(totalRounds)")

                            Button(action: {
                                if speechRecognizer.isListening {
                                    speechRecognizer.stopListening()
                                } else {
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

                            if showNotification {
                                VStack {
                                    Text("🎉 You found it!")
                                        .foregroundColor(.green)
                                        .font(.headline)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                            }

                            VStack(alignment: .leading) {
                                Text("📡 Local Leaderboard")
                                    .font(.headline)
                                    .foregroundColor(.yellow)

                                ForEach(multiplayer.peerScores.sorted(by: { $0.value > $1.value }), id: \.key) { name, score in
                                    Text("\(name): \(score)")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .alert(isPresented: $gameOver) {
                            Alert(
                                title: Text("🏆 Game Over"),
                                message: Text("Winner: \(winner)"),
                                dismissButton: .default(Text("OK"))
                            )
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(16)
                        .padding()
                    } else {
                        
                        ZStack {
                                // Background image
                                Image("MainPage")
                                    .resizable()
                                    .scaledToFill()
                                    .edgesIgnoringSafeArea(.all)

                                // Foreground content over the image
                                VStack(spacing: 50) {
                                    TextField("Your name", text: $username)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .padding(.horizontal, 80)
                                        .padding(.vertical, 233)
                                    
                                    Button(" ") {
                                        multiplayer.setUsername(username)
                                        isUsernameSet = true
                                        gameManager.startGame()

                                        multiplayer.sendGameState(
                                            round: gameManager.round,
                                            score: gameManager.score,
                                            currentLetter: gameManager.currentLetter,
                                            timeRemaining: gameManager.timeRemaining
                                        )
                                    }
                                    .padding(.horizontal, 80)
                                    .padding(.vertical, 20)
                                    .background(Color.clear)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .frame(width: 200, height: 50)
                                    .opacity(1)
                                }
                                .padding()
                               
                                .cornerRadius(16)
                            }
                    }
                }
                .onReceive(multiplayer.receivedGameStatePublisher) { state in
                    gameManager.setState(round: state.round, score: state.score, currentLetter: state.currentLetter, timeRemaining: state.timeRemaining)
                }
            }
        }
    }
}

#Preview {
    ARVoiceIntentView()
}
