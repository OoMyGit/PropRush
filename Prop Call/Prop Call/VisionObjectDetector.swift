//
//  VisionObjectDetector.swift
//  Prop Call
//
//  Created by Alfred Hans Witono on 18/06/25.
//

import SwiftUI
import ARKit
import CoreML
import NaturalLanguage

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
    
    func resetRound() {
        detectedLabel = ""
        matchFound = false
    }

    func resetGame() {
        detectedLabel = ""
        matchFound = false
        score = 0
    }

}
