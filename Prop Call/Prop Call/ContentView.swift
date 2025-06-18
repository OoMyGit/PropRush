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

class SpeechRecognizer: ObservableObject {
    @Published var transcript: String = ""
    @Published var predictedObject: String = ""
    @Published var isListening: Bool = false

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private let request = SFSpeechAudioBufferRecognitionRequest()
    private var recognitionTask: SFSpeechRecognitionTask?

    func startListening() {
        let node = audioEngine.inputNode
        let recordingFormat = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.request.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self, let result = result else { return }
            DispatchQueue.main.async {
                let spokenText = result.bestTranscription.formattedString
                self.transcript = spokenText
                self.classifyText(text: spokenText)
            }
        }

        isListening = true
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }

    private func classifyText(text: String) {
        let objects = ["tv", "bottle", "person", "laptop"]
        predictedObject = text.lowercased().split(separator: " ").compactMap { word in
            objects.contains(String(word)) ? String(word) : nil
        }.first ?? ""
    }
}

class VisionObjectDetector: ObservableObject {
    @Published var detectedLabel: String = ""
    @Published var matchFound: Bool = false
    @Published var score: Int = 0

    private var classificationRequest: VNCoreMLRequest?

    init() {
        configureVisionModel()
    }

    private func configureVisionModel() {
        do {
            let config = MLModelConfiguration()
            let model = try VNCoreMLModel(for: YOLOv8n(configuration: config).model)
            classificationRequest = VNCoreMLRequest(model: model) { [weak self] request, error in
                self?.processClassifications(for: request)
            }
            classificationRequest?.imageCropAndScaleOption = .centerCrop
        } catch {
            print("Failed to load model: \(error)")
        }
    }

    func detectObject(in pixelBuffer: CVPixelBuffer, spokenObject: String) {
        guard let request = classificationRequest else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Vision request failed: \(error)")
        }
    }

    private func processClassifications(for request: VNRequest) {
        DispatchQueue.main.async {
            guard let observations = request.results as? [VNRecognizedObjectObservation], !observations.isEmpty else {
                self.detectedLabel = "Nothing"
                return
            }

            if let best = observations.max(by: { $0.confidence < $1.confidence }),
               let label = best.labels.first,
               label.confidence > 0.5 {
                self.detectedLabel = label.identifier
            }
        }
    }

    func checkMatch(with spoken: String) {
        if detectedLabel.lowercased() == spoken.lowercased() {
            matchFound = true
            score += 1
        } else {
            matchFound = false
        }
    }
}


struct ARVoiceIntentView: View {
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var detector = VisionObjectDetector()

    @State private var timer: Timer?

    var body: some View {
        ZStack(alignment: .bottom) {
            CameraView(didCaptureBuffer: { pixelBuffer in
                detector.detectObject(in: pixelBuffer, spokenObject: speechRecognizer.predictedObject)
                detector.checkMatch(with: speechRecognizer.predictedObject)
            })

            VStack(spacing: 10) {
                Text("You said: \(speechRecognizer.predictedObject)")
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
                }

            }
            .padding()
            .background(Color.black.opacity(0.6))
            .cornerRadius(16)
            .padding()
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    var didCaptureBuffer: (CVPixelBuffer) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.didCaptureBuffer = didCaptureBuffer
        return vc
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var didCaptureBuffer: ((CVPixelBuffer) -> Void)?
    private let captureSession = AVCaptureSession()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    private func setupCamera() {
        captureSession.sessionPreset = .medium

        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera) else { return }

        captureSession.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(output)

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        captureSession.startRunning()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        didCaptureBuffer?(buffer)
    }
}


struct ARViewContainer: UIViewRepresentable {
    var arView: ARView

    func makeUIView(context: Context) -> ARView {
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

extension simd_float4x4 {
    init(translation: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.3 = SIMD4<Float>(translation, 1)
    }
}


#Preview {
    ARVoiceIntentView()
}
