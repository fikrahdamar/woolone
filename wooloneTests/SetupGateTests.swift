//
//  SetupGateTests.swift
//  wooloneTests
//
//  Created by Fikrah Damar Huda on 01/09/26.
//

import CoreGraphics
import Foundation
import Testing
import Vision
@testable import woolone

struct SetupGateTests {
    @Test func nobodyInFrameNeverArms() {
        var gate = SetupGate()
        #expect(gate.update(.empty, at: 0) == .waiting(.noPerson))
    }

    @Test func aMissingJointNamesItselfRatherThanFailingSilently() {
        var joints = Self.body(spread: 0.10, knee: 175)
        joints[.neck] = nil
        let state = Self.run(Self.frame(joints), seconds: 0...4)

        guard case .waiting(.missingJoints(let missing)) = state else {
            Issue.record("expected missing joints, got \(state)")
            return
        }
        #expect(missing.contains(.neck))
    }

    /// Counting and grading are gated differently: a crooked camera still starts a set, it just
    /// cannot be trusted with an angle. Blocking the arm here would destroy the one signal that survives.
    @Test func aCrookedBodyStillArmsButIsNotSquare() {
        var gate = SetupGate()
        let frame = Self.frame(Self.body(spread: 0.30, knee: 175))
        _ = gate.update(frame, at: 0)
        #expect(gate.update(frame, at: 3.0) == .armed)
        #expect(gate.isSquare == false)
    }

    @Test func aSquareBodyArmsAndIsGradeable() {
        var gate = SetupGate()
        let frame = Self.frame(Self.body(spread: 0.10, knee: 175))
        _ = gate.update(frame, at: 0)
        #expect(gate.update(frame, at: 3.0) == .armed)
        #expect(gate.isSquare)
    }

    /// The counter measures every descent against this, so one jittery sample would shift every rep.
    @Test func theHoldProducesABaselineFromTheWholeWindow() throws {
        var gate = SetupGate()
        let frame = Self.frame(Self.body(spread: 0.10, knee: 175))
        for index in 0..<90 { _ = gate.update(frame, at: Double(index) / 30) }
        _ = gate.update(frame, at: 3.0)

        let baseline = try #require(gate.baseline)
        let expected = try #require(frame.repSignal)
        #expect(abs(baseline - expected) < 0.001)
    }

    @Test func squattingIsNotAStartPosition() {
        let frame = Self.frame(Self.body(spread: 0.10, knee: 95))
        #expect(Self.run(frame, seconds: 0...5) == .waiting(.notStanding))
    }

    @Test func threeSecondsSquareAndStandingArmsIt() {
        let frame = Self.frame(Self.body(spread: 0.10, knee: 175))
        var gate = SetupGate()

        _ = gate.update(frame, at: 0)
        guard case .holding = gate.state else {
            Issue.record("expected holding, got \(gate.state)")
            return
        }
        _ = gate.update(frame, at: 2.9)
        guard case .holding = gate.state else {
            Issue.record("expected still holding at 2.9s, got \(gate.state)")
            return
        }
        #expect(gate.update(frame, at: 3.0) == .armed)
    }

    /// One jittery frame must not flip the verdict on a body that has been square all along.
    @Test func aSingleBadFrameDoesNotUnsquareIt() {
        let good = Self.frame(Self.body(spread: 0.10, knee: 175))
        let blip = Self.frame(Self.body(spread: 0.40, knee: 175))
        var gate = SetupGate()

        for index in 0..<20 { _ = gate.update(good, at: Double(index) / 30) }
        _ = gate.update(blip, at: 20 / 30)
        #expect(gate.isSquare)
    }

    /// Sustained crookedness is a fault, not jitter — the window has to notice eventually.
    @Test func sustainedCrookednessIsNoticed() {
        let good = Self.frame(Self.body(spread: 0.10, knee: 175))
        let crooked = Self.frame(Self.body(spread: 0.40, knee: 175))
        var gate = SetupGate()

        for index in 0..<20 { _ = gate.update(good, at: Double(index) / 30) }
        for index in 20..<45 { _ = gate.update(crooked, at: Double(index) / 30) }
        #expect(gate.isSquare == false)
    }

    /// Walking out of frame mid-set has to disarm, not keep grading an empty room.
    @Test func losingAJointMidSetDisarms() {
        let frame = Self.frame(Self.body(spread: 0.10, knee: 175))
        var gate = SetupGate()
        _ = gate.update(frame, at: 0)
        #expect(gate.update(frame, at: 3.0) == .armed)

        #expect(gate.update(.empty, at: 3.5) == .waiting(.noPerson))
    }

    /// Bending is what a squat is. Judging must survive the shoulders opening up as the torso leans.
    @Test func armedSurvivesTheBendThatFollowsIt() {
        var gate = SetupGate()
        _ = gate.update(Self.frame(Self.body(spread: 0.10, knee: 175)), at: 0)
        #expect(gate.update(Self.frame(Self.body(spread: 0.10, knee: 175)), at: 3.0) == .armed)

        let bent = Self.frame(Self.body(spread: 0.28, knee: 92))
        #expect(gate.update(bent, at: 4.0) == .armed)
    }

    // MARK: - Fixtures

    private static func run(_ frame: PoseFrame, seconds: ClosedRange<Double>) -> SetupGate.State {
        var gate = SetupGate()
        var state = gate.state
        var now = seconds.lowerBound
        while now <= seconds.upperBound {
            state = gate.update(frame, at: now)
            now += 1.0 / 30
        }
        return state
    }

    private static func frame(
        _ joints: [HumanBodyPoseObservation.JointName: woolone.Joint]
    ) -> PoseFrame {
        PoseFrame(
            joints: joints,
            observationConfidence: 1,
            imageSize: CGSize(width: 720, height: 1280),
            orientation: .leftMirrored,
            supportedJointCount: 19,
            inferenceMilliseconds: 21
        )
    }

    // torso is 200px tall, so the shoulders are placed at `spread * 200` apart; the knee angle is
    // built by pushing the ankle sideways until hip-knee-ankle opens to the angle asked for
    private static func body(
        spread: CGFloat,
        knee: CGFloat
    ) -> [HumanBodyPoseObservation.JointName: woolone.Joint] {
        let torso: CGFloat = 200
        let half = spread * torso / 2
        let shin: CGFloat = 250
        let bend = (180 - knee) * .pi / 180
        let ankle = CGPoint(x: 360 + sin(bend) * shin, y: 850 + cos(bend) * shin)

        func joint(_ name: HumanBodyPoseObservation.JointName, _ point: CGPoint) -> woolone.Joint {
            woolone.Joint(name: name, position: point, confidence: 0.9)
        }
        return [
            .neck: joint(.neck, CGPoint(x: 360, y: 400)),
            .root: joint(.root, CGPoint(x: 360, y: 400 + torso)),
            .leftShoulder: joint(.leftShoulder, CGPoint(x: 360 - half, y: 400)),
            .rightShoulder: joint(.rightShoulder, CGPoint(x: 360 + half, y: 400)),
            .leftHip: joint(.leftHip, CGPoint(x: 360 - half, y: 600)),
            .rightHip: joint(.rightHip, CGPoint(x: 360 + half, y: 600)),
            .leftKnee: joint(.leftKnee, CGPoint(x: 360, y: 850)),
            .leftAnkle: joint(.leftAnkle, ankle),
            .rightKnee: joint(.rightKnee, CGPoint(x: 360, y: 850)),
            .rightAnkle: joint(.rightAnkle, ankle)
        ]
    }
}
