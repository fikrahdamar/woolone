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
    var leftLeg: [Joint] { leg(.left, above: PoseConfidence.draw) }
    var rightLeg: [Joint] { leg(.right, above: PoseConfidence.draw) }

    /// Knee angle in degrees, judged not drawn — nil the moment any of the three is missing or unsure.
    func kneeAngle(_ side: LegSelector.Side) -> CGFloat? {
        let joints = leg(side, above: PoseConfidence.judge)
        guard joints.count == 3 else { return nil }
        return angle(joints[0].position, joints[1].position, joints[2].position)
    }

    /// hip, knee, ankle in that order — the drawing order and the angle's argument order are the same one.
    func leg(_ side: LegSelector.Side, above gate: Float) -> [Joint] {
        let names: [HumanBodyPoseObservation.JointName] = side == .left
            ? [.leftHip, .leftKnee, .leftAnkle]
            : [.rightHip, .rightKnee, .rightAnkle]
        return chain(names, above: gate) ?? []
    }

    /// Every bone chain whose joints all clear the gate — the debug skeleton.
    func chains(above gate: Float) -> [[Joint]] {
        Skeleton.chains.compactMap { chain($0, above: gate) }
    }

    // all-or-nothing: a chain missing a joint is dropped whole, never shortened — a shortened arm
    // draws shoulder straight to wrist and looks like a pose rather than a gap
    private func chain(
        _ names: [HumanBodyPoseObservation.JointName],
        above gate: Float
    ) -> [Joint]? {
        let found = names.compactMap { joints[$0] }
        guard found.count == names.count,
              found.allSatisfy({ $0.confidence >= gate }) else { return nil }
        return found
    }
}
