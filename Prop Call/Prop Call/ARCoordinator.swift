//
//  ARCoordinator.swift
//  Prop Call
//
//  Created by Alfred Hans Witono on 18/06/25.
//

import SwiftUI
import RealityKit
import ARKit

class ARCoordinator: NSObject, ARSessionDelegate {
    var didCaptureBuffer: ((CVPixelBuffer) -> Void)?

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let buffer = frame.capturedImage
        didCaptureBuffer?(buffer)
    }
}
