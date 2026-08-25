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
}
