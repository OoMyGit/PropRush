//
//  ARViewContainer.swift
//  Prop Call
//
//  Created by Alfred Hans Witono on 18/06/25.
//

import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    var didCaptureBuffer: (CVPixelBuffer) -> Void

    func makeCoordinator() -> ARCoordinator {
        let coordinator = ARCoordinator()
        coordinator.didCaptureBuffer = didCaptureBuffer
        return coordinator
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        arView.session.run(config)
        arView.session.delegate = context.coordinator
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
