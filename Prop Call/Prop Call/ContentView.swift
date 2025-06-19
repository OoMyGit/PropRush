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
import NaturalLanguage
import Foundation
import Speech
import AVFoundation


struct ARVoiceIntentView: View {
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var detector = VisionObjectDetector()
    @StateObject private var multiplayer = MultipeerManager()
    @StateObject private var gameManager = GameRoundManager()

    @State private var showNotification = false
    @State private var currentRound = 1
    @State private var gameOver = false
    @State private var winner: String = ""
    @State private var isHost: Bool = UIDevice.current.name.contains("YourNameHere")
    @State private var username: String = ""
    @State private var isUsernameSet = false

    let totalRounds = 5

    var body: some View {
        ZStack(alignment: .bottom) {
            if isUsernameSet {
                ARViewContainer(didCaptureBuffer: { scannedImage in
                    detector.detectObject(in: scannedImage)
                    detector.checkMatch(
                        with: speechRecognizer.spokenText,
                        startsWith: gameManager.currentLetter
                    ) {
                        gameManager.incrementScoreAndNextRound {
                            multiplayer.sendScore(gameManager.score)
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

                            Button("Next Round") {
                                detector.resetRound()
                                speechRecognizer.spokenText = ""
                                showNotification = false

                                multiplayer.sendScore(gameManager.score)

                                if gameManager.round < totalRounds {
                                    gameManager.incrementScoreAndNextRound()
                                } else {
                                    gameOver = true
                                    gameManager.stop()
                                    winner = multiplayer.peerScores.max(by: { $0.value < $1.value })?.key ?? "No one"
                                }
                            }
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
                .onChange(of: detector.matchFound) { newValue in
                    if newValue && !showNotification {
                        showNotification = true
                        gameManager.endRound()
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
                VStack {
                    Text("Enter your name")
                        .font(.title)
                        .padding()

                    TextField("Your name", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()

                    Button("Start Game") {
                        multiplayer.setUsername(username)
                        isUsernameSet = true
                        gameManager.startGame()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
            }
        }
    }
}


#Preview {
    ARVoiceIntentView()
}
