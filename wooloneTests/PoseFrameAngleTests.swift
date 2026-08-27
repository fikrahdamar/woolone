//
//  PoseFrameAngleTests.swift
//  wooloneTests
//
//  Created by Fikrah Damar Huda on 27/08/26.
//

import CoreGraphics
import Testing
import Vision
@testable import woolone

struct PoseFrameAngleTests {
    @Test func aStandingLegReadsNearOneEighty() throws {
        let frame = frame(hip: 0.9, knee: 0.9, ankle: 0.9)
        let value = try #require(frame.kneeAngle(.left))
        #expect(value > 170)
    }

    /// Between the two gates: too unsure to draw, sure enough to judge.
    @Test func aJointBelowTheDrawGateStillProducesAnAngle() throws {
        let frame = frame(hip: 0.9, knee: 0.35, ankle: 0.9)
        #expect(frame.leftLeg.isEmpty)
        #expect(frame.kneeAngle(.left) != nil)
    }

    @Test func aJointBelowTheJudgeGateRefusesToGuess() {
        let frame = frame(hip: 0.9, knee: 0.9, ankle: 0.2)
        #expect(frame.kneeAngle(.left) == nil)
    }

    @Test func aMissingJointRefusesToGuess() {
        var joints = Self.legJoints(hip: 0.9, knee: 0.9, ankle: 0.9)
        joints[.leftAnkle] = nil
        let frame = PoseFrame(
            joints: joints,
            observationConfidence: 1,
            imageSize: CGSize(width: 720, height: 1280),
            orientation: .right,
            supportedJointCount: 19,
            inferenceMilliseconds: 18
        )
        #expect(frame.kneeAngle(.left) == nil)
    }

    // MARK: - Fixtures

    private func frame(hip: Float, knee: Float, ankle: Float) -> PoseFrame {
        PoseFrame(
            joints: Self.legJoints(hip: hip, knee: knee, ankle: ankle),
            observationConfidence: 1,
            imageSize: CGSize(width: 720, height: 1280),
            orientation: .right,
            supportedJointCount: 19,
            inferenceMilliseconds: 18
        )
    }

    // hip above, knee below it, ankle below that — a leg standing almost straight
    private static func legJoints(
        hip: Float,
        knee: Float,
        ankle: Float
    ) -> [HumanBodyPoseObservation.JointName: woolone.Joint] {
        [
            .leftHip: woolone.Joint(name: .leftHip, position: CGPoint(x: 360, y: 600), confidence: hip),
            .leftKnee: woolone.Joint(name: .leftKnee, position: CGPoint(x: 360, y: 850), confidence: knee),
            .leftAnkle: woolone.Joint(name: .leftAnkle, position: CGPoint(x: 355, y: 1100), confidence: ankle)
        ]
    }
}
