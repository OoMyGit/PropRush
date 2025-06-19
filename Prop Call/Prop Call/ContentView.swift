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

    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(didCaptureBuffer: { scannedImage in
                detector.detectObject(in: scannedImage, spokenObject: speechRecognizer.spokenText)
                detector.checkMatch(with: speechRecognizer.spokenText)
            })
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 10) {
                Text("You said: \(speechRecognizer.spokenText)")
                Text("Detected: \(detector.detectedLabel)")
                Text("✅ Match: \(detector.matchFound ? "Yes" : "No")")
                Text("🎯 Score: \(detector.score)")

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
                                    } else {
                                        print("Microphone access denied")
                                    }
                                }
                            } else {
                                print("Speech recognition access denied")
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

            }
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(16)
            .padding()
        }
    }
}

#Preview {
    ARVoiceIntentView()
}
