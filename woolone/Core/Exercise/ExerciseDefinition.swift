//
//  ExerciseDefinition.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 01/09/26.
//

import CoreGraphics
import Foundation
import Vision

/// A movement as data. A second movement is a new value of this type, never a new type.
nonisolated struct ExerciseDefinition: Sendable, Equatable {
    enum Plane: String, Sendable, Equatable {
        case sagittal
        case frontal
    }

    enum CameraView: String, Sendable, Equatable {
        case side
        case front
    }

    /// One measurement, the range it has to fall in, and what to say when it does not.
    struct Fault: Sendable, Equatable {
        let name: String
        /// The triple the angle is measured from, named on the left. The judged side is mirrored.
        let joints: [HumanBodyPoseObservation.JointName]
        let validRange: ClosedRange<CGFloat>
        let cue: String
    }

    let name: String
    let plane: Plane
    let cameraView: CameraView
    let faults: [Fault]
    /// Faults this view cannot see honestly. Written down rather than faked.
    let outOfScope: [String]

    static let squat = ExerciseDefinition(
        name: "squat",
        plane: .sagittal,
        cameraView: .side,
        faults: [
            // 86° is the midpoint of a gap with nothing in it. Every recording whose framing median
            // across the set was ≤0.15: 72 clean reps bottomed at 42–80°, 17 deliberately shallow
            // ones at 92–115°. Twelve degrees empty between them, and 86 sits 6° from each edge.
            //
            // This replaced 96, which came from a narrower slice — filtered on framing at the moment
            // the gate armed, which in pre-gate recordings often lands mid-walk. 96 let 3 of the 17
            // shallow reps pass. Converted to the flexion convention the literature uses, the empty
            // gap is 89–99°, which is where "parallel" is usually put.
            //
            // Only valid while the framing gate holds — at 0.25 spread the same clean reps read
            // 82–93°. See c4/thresholds.md.
            Fault(
                name: "depth",
                joints: [.leftHip, .leftKnee, .leftAnkle],
                validRange: 0...86,
                cue: "go deeper"
            )
        ],
        outOfScope: [
            // measured: turning 45° changes the knee angle by 21–56°, and knee travel is sideways —
            // the one direction a side camera has no resolution in
            "knees caving inward — frontal plane, invisible from the side",
            "lumbar rounding — finer than the measurement error",
            "heels lifting — Vision returns no toe or heel joint"
        ]
    )
}
