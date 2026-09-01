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

    var label: String { name.label }
}

nonisolated extension HumanBodyPoseObservation.JointName {
    // the new Swift enum uses camelCase; the old VN API's "left_knee_joint" is gone, so the
    // underscore stripping this used to do had been a no-op since #5
    var label: String {
        rawValue.reduce(into: "") { text, character in
            if character.isUppercase, !text.isEmpty { text.append(" ") }
            text.append(contentsOf: character.lowercased())
        }
    }
}
