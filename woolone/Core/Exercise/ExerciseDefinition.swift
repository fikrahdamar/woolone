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
            // 96° is the midpoint of a gap with nothing in it. Replaying every recording that was
            // square at arming: 24 clean reps bottomed at 62–91°, 6 deliberately shallow ones at
            // 102–111°. Only valid while the framing gate holds — at 0.25 spread the same clean
            // reps read 82–93° and several would fail this. See c4/thresholds.md.
            Fault(
                name: "depth",
                joints: [.leftHip, .leftKnee, .leftAnkle],
                validRange: 0...96,
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
