//
//  PoseFrame.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import CoreGraphics
import ImageIO
import Vision

/// One detection: joints already in pixels, plus what it cost to get them.
nonisolated struct PoseFrame: Sendable {
    let joints: [HumanBodyPoseObservation.JointName: Joint]
    let observationConfidence: Float
    let imageSize: CGSize
    let orientation: CGImagePropertyOrientation
    let supportedJointCount: Int
    let inferenceMilliseconds: Double

    static let empty = PoseFrame(
        joints: [:],
        observationConfidence: 0,
        imageSize: .zero,
        orientation: .up,
        supportedJointCount: 0,
        inferenceMilliseconds: 0
    )

    var hasPerson: Bool { observationConfidence >= PoseConfidence.observation }

    var drawableJointCount: Int {
        joints.values.filter { $0.confidence >= PoseConfidence.draw }.count
    }

    /// Everything Vision returned, gates included — the debug view, not the product one.
    var allJoints: [Joint] { Array(joints.values) }

    /// Joints below the draw gate, worst first — the ones about to cost you a reading.
    var weakJoints: [Joint] {
        joints.values
            .filter { $0.confidence < PoseConfidence.draw }
            .sorted { $0.confidence < $1.confidence }
    }

    /// hip, knee, ankle — empty unless all three clear the draw gate.
    var leftLeg: [Joint] { leg(.leftHip, .leftKnee, .leftAnkle) }
    var rightLeg: [Joint] { leg(.rightHip, .rightKnee, .rightAnkle) }

    // all-or-nothing: a two-joint leg still draws, and the joint that vanished is the one you needed
    private func leg(_ names: HumanBodyPoseObservation.JointName...) -> [Joint] {
        let found = names.compactMap { joints[$0] }
        guard found.count == names.count,
              found.allSatisfy({ $0.confidence >= PoseConfidence.draw }) else { return [] }
        return found
    }
}
