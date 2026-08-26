//
//  PoseDetector.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import CoreGraphics
import Foundation
import ImageIO
import Vision

/// Owns the one request for the app's lifetime — an actor, so detection never lands on main.
actor PoseDetector {
    // built once: the first perform compiles the model (24s measured on device), every later one is warm
    private let request: DetectHumanBodyPoseRequest

    private var orientation: CGImagePropertyOrientation = .right

    init() {
        var request = DetectHumanBodyPoseRequest()
        request.detectsHands = false
        self.request = request
    }

    func use(_ orientation: CGImagePropertyOrientation) {
        self.orientation = orientation
    }

    func detect(_ frame: CapturedFrame) async throws -> PoseFrame {
        let started = DispatchTime.now().uptimeNanoseconds
        let observations = try await request.perform(on: frame.pixelBuffer, orientation: orientation)
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds &- started) / 1_000_000

        // Vision normalizes against the oriented image, so a quarter turn swaps the axes the joints scale to
        let size = orientation.swapsAxes
            ? CGSize(width: frame.size.height, height: frame.size.width)
            : frame.size

        let supported = request.supportedJointNames.count
        guard let observation = observations.max(by: { $0.confidence < $1.confidence }),
              observation.confidence >= PoseConfidence.observation else {
            return PoseFrame(
                joints: [:],
                observationConfidence: observations.map(\.confidence).max() ?? 0,
                imageSize: size,
                orientation: orientation,
                supportedJointCount: supported,
                inferenceMilliseconds: elapsed
            )
        }

        var joints: [HumanBodyPoseObservation.JointName: Joint] = [:]
        joints.reserveCapacity(supported)
        for (name, joint) in observation.allJoints() {
            // pixels here or nowhere — normalized x and y are scaled to width and height separately
            let pixel = joint.location.toImageCoordinates(size, origin: .upperLeft)
            joints[name] = Joint(name: name, position: pixel, confidence: joint.confidence)
        }

        return PoseFrame(
            joints: joints,
            observationConfidence: observation.confidence,
            imageSize: size,
            orientation: orientation,
            supportedJointCount: supported,
            inferenceMilliseconds: elapsed
        )
    }
}
