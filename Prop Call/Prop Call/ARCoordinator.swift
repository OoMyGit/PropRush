//
//  ARCoordinator.swift
//  Prop Call
//
//  Created by Alfred Hans Witono on 18/06/25.
//

import SwiftUI
import RealityKit
import ARKit

class ARCoordinator: NSObject, ObservableObject, ARSessionDelegate {
    var arView: ARView?
    var didCaptureBuffer: ((CVPixelBuffer) -> Void)?
    private var lastProcessedTime: TimeInterval = 0
    private let processingInterval: TimeInterval = 0.5  // 0.5s = 2 fps

    init(didCaptureBuffer: ((CVPixelBuffer) -> Void)? = nil) {
        self.didCaptureBuffer = didCaptureBuffer
        super.init()
        setupARView()
    }

    private func setupARView() {
        arView = ARView(frame: .zero)
        guard let arView = arView else { return }

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.delegate = self
        arView.session.run(config)

        let label = create3DText("Find item starting with B", color: .blue, scale: 0.01)
        label.position = SIMD3(x: 0, y: 0, z: -0.5)
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(label)
        arView.scene.anchors.append(anchor)
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastProcessedTime >= processingInterval else { return }

        lastProcessedTime = currentTime
        let buffer = frame.capturedImage
        didCaptureBuffer?(buffer)
    }

    func create3DText(_ string: String, color: UIColor, scale: Float) -> ModelEntity {
        let mesh = MeshResource.generateText(string, extrusionDepth: 0.02, font: .systemFont(ofSize: 0.15))
        let material = SimpleMaterial(color: color, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.scale = SIMD3<Float>(repeating: scale)
        return entity
    }
}
