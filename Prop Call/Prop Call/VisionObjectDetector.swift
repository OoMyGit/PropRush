//
//  VisionObjectDetector.swift
//  Prop Call
//
//  Created by Alfred Hans Witono on 18/06/25.
//

//
//  VisionObjectDetector.swift
//  Prop Call
//
//  Created by Alfred Hans Witono on 18/06/25.
//

import SwiftUI
import ARKit
import CoreML
import Vision

class VisionObjectDetector: ObservableObject {
    @Published var detectedLabel: String = ""
    @Published var matchFound: Bool = false

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
            print("❌ Failed to load model: \(error)")
        }
    }

    func detectObject(in image: UIImage) {
        guard let cgImage = image.cgImage,
              let request = classificationRequest else { return }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("❌ Vision request failed: \(error)")
        }
    }

    private func processClassifications(for request: VNRequest) {
        DispatchQueue.main.async {
            guard let observations = request.results as? [VNRecognizedObjectObservation],
                  !observations.isEmpty else {
                self.detectedLabel = ""
                return
            }

            if let best = observations.max(by: { $0.confidence < $1.confidence }),
               let label = best.labels.first,
               label.confidence > 0.5 {
                self.detectedLabel = label.identifier
            }
        }
    }

    func checkMatch(with spoken: String, startsWith letter: String, onSuccess: () -> Void) {
        let detected = detectedLabel.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let spokenLower = spoken.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = letter.lowercased()

        print("🧠 Checking match... Detected: \(detected), Spoken: \(spokenLower), Letter: \(prefix)")

        if detected.hasPrefix(prefix) && spokenLower.hasPrefix(prefix) {
            matchFound = true
            onSuccess() // ← Notify game manager to add score and start next round
        } else {
            matchFound = false
        }
    }

    func resetRound() {
        detectedLabel = ""
        matchFound = false
    }

    func resetGame() {
        resetRound()
    }
}
