//
//  Joint.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import CoreGraphics
import Vision

/// A joint in image pixels — normalized coordinates never leave PoseDetector.
nonisolated struct Joint: Sendable, Equatable {
    let name: HumanBodyPoseObservation.JointName
    let position: CGPoint
    let confidence: Float

    private static let kneeAngleNames: Set<HumanBodyPoseObservation.JointName> = [
        .leftHip, .leftKnee, .leftAnkle, .rightHip, .rightKnee, .rightAnkle
    ]

    /// One of the six the knee angle can be built from — a weak one of these costs the reading.
    var measuresKneeAngle: Bool { Self.kneeAngleNames.contains(name) }

    // Vision decorates its raw names; the HUD has one line to spare, not three
    var label: String {
        name.rawValue
            .replacingOccurrences(of: "_joint", with: "")
            .replacingOccurrences(of: "_", with: " ")
    }
}
