//
//  Pose3DProbe.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 04/09/26.
//

import CoreGraphics
import CoreMedia
import Foundation
import ImageIO
import Vision
import simd

/// Spike only. Runs the 3D request beside the 2D one so both knee angles can be read off the HUD
/// at the same instant, square and then turned 45°. Throwaway — delete with the branch.
actor Pose3DProbe {
    /// One frame in 3D, next to nothing else.
    nonisolated struct Reading: Sendable, Equatable {
        let leftKnee: CGFloat?
        let rightKnee: CGFloat?
        let milliseconds: Double
        let confidence: Float
        let jointCount: Int
        /// 3D returns no per-joint confidence at all — there is nothing to gate on.
        let bodyHeightMetres: Double?
        /// `.reference` means the height is an assumed default, so the depth scale is a guess.
        let isHeightMeasured: Bool
        /// Never swallowed: a frozen number with no error is the failure this project keeps hitting.
        let failure: String?

        static let none = Reading(
            leftKnee: nil, rightKnee: nil, milliseconds: 0, confidence: 0,
            jointCount: 0, bodyHeightMetres: nil, isHeightMeasured: false, failure: nil
        )
    }

    private let request: DetectHumanBodyPose3DRequest
    private var orientation: CGImagePropertyOrientation = .right

    init() {
        // no frameAnalysisSpacing: a stateful request given pixel buffers has no timestamp to
        // advance the spacing with, and every frame came back identical
        request = DetectHumanBodyPose3DRequest()
    }

    func use(_ orientation: CGImagePropertyOrientation) {
        // the 3D pipeline refuses a mirrored orientation outright — a mirrored body is not one it
        // can build. The skeleton comes back left/right swapped, which the front camera already is
        self.orientation = Self.unmirrored(orientation)
    }

    private static func unmirrored(_ orientation: CGImagePropertyOrientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .upMirrored: .up
        case .downMirrored: .down
        case .leftMirrored: .right
        case .rightMirrored: .left
        default: orientation
        }
    }

    func detect(_ frame: CapturedFrame) async -> Reading {
        let started = DispatchTime.now().uptimeNanoseconds
        do {
            let observations = try await request.perform(
                on: frame.pixelBuffer, orientation: orientation
            )
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds &- started) / 1_000_000

            guard let observation = observations.max(by: { $0.confidence < $1.confidence }) else {
                return Reading(
                    leftKnee: nil, rightKnee: nil, milliseconds: elapsed,
                    confidence: 0, jointCount: 0, bodyHeightMetres: nil,
                    isHeightMeasured: false, failure: "no observation"
                )
            }
            return Reading(
                leftKnee: Self.angle(observation, .leftHip, .leftKnee, .leftAnkle),
                rightKnee: Self.angle(observation, .rightHip, .rightKnee, .rightAnkle),
                milliseconds: elapsed,
                confidence: observation.confidence,
                jointCount: observation.availableJointNames.count,
                bodyHeightMetres: observation.bodyHeight.converted(to: .meters).value,
                isHeightMeasured: observation.heightEstimationTechnique == .measured,
                failure: nil
            )
        } catch {
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds &- started) / 1_000_000
            return Reading(
                leftKnee: nil, rightKnee: nil, milliseconds: elapsed,
                confidence: 0, jointCount: 0, bodyHeightMetres: nil,
                isHeightMeasured: false, failure: "\(error)"
            )
        }
    }

    // the same acos on a normalised dot product as the 2D angle, with a third axis. Camera-relative,
    // not `position` — one unambiguous frame of reference for all three joints
    private static func angle(
        _ observation: HumanBodyPose3DObservation,
        _ a: HumanBodyPose3DObservation.JointName,
        _ vertex: HumanBodyPose3DObservation.JointName,
        _ c: HumanBodyPose3DObservation.JointName
    ) -> CGFloat? {
        let available = Set(observation.availableJointNames)
        guard available.isSuperset(of: [a, vertex, c]) else { return nil }
        let origin = translation(observation.cameraRelativePosition(for: vertex))
        let u = translation(observation.cameraRelativePosition(for: a)) - origin
        let w = translation(observation.cameraRelativePosition(for: c)) - origin
        let lengths = simd_length(u) * simd_length(w)
        guard lengths > 0 else { return nil }
        // clamped for the same reason as the 2D one: float error past 1.0 makes acos return NaN
        let cosine = max(-1, min(1, simd_dot(u, w) / lengths))
        return CGFloat(acos(cosine)) * 180 / .pi
    }

    private static func translation(_ transform: simd_float4x4) -> SIMD3<Float> {
        let column = transform.columns.3
        return SIMD3(column.x, column.y, column.z)
    }
}
