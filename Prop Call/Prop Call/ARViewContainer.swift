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
    var didCaptureBuffer: (UIImage) -> Void

    func makeCoordinator() -> ARCoordinator {
        return ARCoordinator(didCaptureBuffer: didCaptureBuffer)
    }

    func makeUIView(context: Context) -> ARView {
        return context.coordinator.arView!
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
