//
//  Skeleton.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 28/08/26.
//

import Vision

/// The bones, because Vision has none — it returns labelled points and no edges at all.
nonisolated enum Skeleton {
    // ordered chains, not edge pairs: the same array that draws a limb can feed angle() with the
    // vertex in the middle
    static let chains: [[HumanBodyPoseObservation.JointName]] = [
        [.leftShoulder, .leftElbow, .leftWrist],
        [.rightShoulder, .rightElbow, .rightWrist],
        [.leftShoulder, .neck, .rightShoulder],
        [.neck, .root],
        [.leftHip, .root, .rightHip],
        [.leftHip, .leftKnee, .leftAnkle],
        [.rightHip, .rightKnee, .rightAnkle]
    ]
}
