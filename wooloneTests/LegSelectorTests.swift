//
//  LegSelectorTests.swift
//  wooloneTests
//
//  Created by Fikrah Damar Huda on 25/08/26.
//

import CoreGraphics
import Testing
import Vision
@testable import woolone

struct LegSelectorTests {
    @Test func picksTheStrongerLegWhenItHasNoHistory() {
        var selector = LegSelector()
        _ = selector.select(from: frame(left: 0.6, right: 0.9))
        #expect(selector.side == .right)
    }

    @Test func holdsThroughNoiseSmallerThanTheMargin() {
        var selector = LegSelector()
        _ = selector.select(from: frame(left: 0.9, right: 0.6))
        _ = selector.select(from: frame(left: 0.80, right: 0.85))
        _ = selector.select(from: frame(left: 0.82, right: 0.88))
        #expect(selector.side == .left)
    }

    @Test func switchesOnceTheOtherLegClearsTheMargin() {
        var selector = LegSelector()
        _ = selector.select(from: frame(left: 0.9, right: 0.6))
        let joints = selector.select(from: frame(left: 0.6, right: 0.95))
        #expect(selector.side == .right)
        #expect(joints.first?.name == .rightHip)
    }

    @Test func fallsBackToTheOnlyCompleteLeg() {
        var selector = LegSelector()
        _ = selector.select(from: frame(left: 0.9, right: 0.9))
        // the right ankle drops below the draw gate, so the right leg stops being drawable at all
        let joints = selector.select(from: frame(left: 0.7, right: 0.9, rightAnkle: 0.2))
        #expect(joints.count == 3)
        #expect(selector.side == .left)
    }

    @Test func drawsNothingWhenNeitherLegIsComplete() {
        var selector = LegSelector()
        let joints = selector.select(from: frame(left: 0.2, right: 0.2))
        #expect(joints.isEmpty)
    }

    // MARK: - Fixtures

    private func frame(left: Float, right: Float, rightAnkle: Float? = nil) -> PoseFrame {
        var joints: [HumanBodyPoseObservation.JointName: woolone.Joint] = [:]
        for name in [.leftHip, .leftKnee, .leftAnkle] as [HumanBodyPoseObservation.JointName] {
            joints[name] = woolone.Joint(name: name, position: .zero, confidence: left)
        }
        for name in [.rightHip, .rightKnee, .rightAnkle] as [HumanBodyPoseObservation.JointName] {
            joints[name] = woolone.Joint(name: name, position: .zero, confidence: right)
        }
        if let rightAnkle {
            joints[.rightAnkle] = woolone.Joint(name: .rightAnkle, position: .zero, confidence: rightAnkle)
        }
        return PoseFrame(
            joints: joints,
            observationConfidence: 1,
            imageSize: CGSize(width: 720, height: 1280),
            orientation: .right,
            supportedJointCount: 19,
            inferenceMilliseconds: 18
        )
    }
}
