//
//  FrameLineTests.swift
//  wooloneTests
//
//  Created by Fikrah Damar Huda on 30/08/26.
//

import CoreGraphics
import Foundation
import Testing
import Vision
@testable import woolone

struct FrameLineTests {
    // MARK: - The round trip

    @Test func everyJointSurvivesWithItsPositionAndItsConfidence() throws {
        let pose = Self.fullBody()
        let line = FrameLine.encode(pose, at: 1.5)
        let decoded = try #require(FrameLine.decode(line, header: Self.header()))

        #expect(decoded.pose.joints.count == Self.allJointNames.count)
        for name in Self.allJointNames {
            let original = try #require(pose.joints[name])
            let result = try #require(decoded.pose.joints[name])
            #expect(abs(result.position.x - original.position.x) < 0.005)
            #expect(abs(result.position.y - original.position.y) < 0.005)
            #expect(abs(result.confidence - original.confidence) < 0.001)
        }
    }

    /// The whole point of the recording: #22's drawing-exit threshold cannot come from a filtered log.
    @Test func aJointBelowEveryGateIsStillWritten() throws {
        let weak = woolone.Joint(name: .rightKnee, position: CGPoint(x: 352.14, y: 880.37), confidence: 0.12)
        let pose = Self.pose([.rightKnee: weak])
        let line = FrameLine.encode(pose, at: 0)
        let decoded = try #require(FrameLine.decode(line, header: Self.header()))

        let result = try #require(decoded.pose.joints[.rightKnee])
        #expect(abs(result.confidence - 0.12) < 0.001)
    }

    @Test func theClockAndTheInferenceCostSurvive() throws {
        let pose = Self.pose([:], observation: 0.994, milliseconds: 22.44)
        let decoded = try #require(FrameLine.decode(FrameLine.encode(pose, at: 13.755), header: Self.header()))

        #expect(abs(decoded.seconds - 13.755) < 0.0005)
        #expect(abs(decoded.pose.observationConfidence - 0.994) < 0.001)
        #expect(abs(decoded.pose.inferenceMilliseconds - 22.44) < 0.005)
    }

    /// Frame lines carry no image size: it comes from the header, which is why the flip is locked while recording.
    @Test func theHeaderSuppliesTheSetupTheFrameLinesOmit() throws {
        let decoded = try #require(FrameLine.decode(FrameLine.encode(Self.fullBody(), at: 0), header: Self.header()))

        #expect(decoded.pose.imageSize == CGSize(width: 720, height: 1280))
        #expect(decoded.pose.orientation == .right)
        #expect(decoded.pose.supportedJointCount == 19)
    }

    // MARK: - The file survives being interrupted

    @Test func aTruncatedLineIsSkippedRatherThanFailingTheFile() {
        let line = FrameLine.encode(Self.fullBody(), at: 4)
        let cut = String(line.dropLast(24))

        #expect(FrameLine.decode(cut, header: Self.header()) == nil)
        #expect(FrameLine.decode(line, header: Self.header()) != nil)
    }

    @Test func aBlankLineIsSkipped() {
        #expect(FrameLine.decode("", header: Self.header()) == nil)
        #expect(FrameLine.decode("   ", header: Self.header()) == nil)
    }

    @Test func aHeaderLineIsNotReadAsAFrame() throws {
        let line = try Self.header().line()
        #expect(FrameLine.decode(line, header: Self.header()) == nil)
    }

    // MARK: - The line is honest JSON

    @Test func aLineIsValidJsonAndHoldsNoNewline() throws {
        let line = FrameLine.encode(Self.fullBody(), at: 2.25)

        #expect(!line.contains("\n"))
        let object = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
        #expect(object?["kind"] as? String == "frame")
    }

    /// `nan` is not JSON — one non-finite coordinate would otherwise cost the entire frame.
    @Test func aNonFinitePositionDropsItsJointRatherThanBreakingTheLine() throws {
        let broken = woolone.Joint(name: .leftWrist, position: CGPoint(x: Double.nan, y: 100), confidence: 0.8)
        let sound = woolone.Joint(name: .leftAnkle, position: CGPoint(x: 355, y: 1100), confidence: 0.8)
        let line = FrameLine.encode(Self.pose([.leftWrist: broken, .leftAnkle: sound]), at: 0)

        #expect(!line.lowercased().contains("nan"))
        let decoded = try #require(FrameLine.decode(line, header: Self.header()))
        #expect(decoded.pose.joints[.leftWrist] == nil)
        #expect(decoded.pose.joints[.leftAnkle] != nil)
    }

    /// Dictionary iteration order is not stable, and an unstable line makes two recordings of one setup undiffable.
    @Test func theSamePoseAlwaysWritesTheSameBytes() {
        var forwards: [HumanBodyPoseObservation.JointName: woolone.Joint] = [:]
        for name in Self.allJointNames { forwards[name] = Self.joint(name, at: 3) }
        var backwards: [HumanBodyPoseObservation.JointName: woolone.Joint] = [:]
        for name in Self.allJointNames.reversed() { backwards[name] = Self.joint(name, at: 3) }

        #expect(FrameLine.encode(Self.pose(forwards), at: 1) == FrameLine.encode(Self.pose(backwards), at: 1))
    }

    // MARK: - Header and conditions

    @Test func theHeaderCarriesTheGatesInForceSoTheyCanBeChangedLater() throws {
        let decoded = try #require(RecordingHeader.decode(try Self.header().line()))

        #expect(decoded.gates.observation == PoseConfidence.observation)
        #expect(decoded.gates.draw == PoseConfidence.draw)
        #expect(decoded.gates.judge == PoseConfidence.judge)
        #expect(decoded.condition == RecordingCondition.offAxis.rawValue)
        #expect(decoded.imageSize == CGSize(width: 720, height: 1280))
        #expect(decoded.imageOrientation == .right)
    }

    @Test func conditionSlugsAreUniqueAndSafeInAFilename() {
        let slugs = RecordingCondition.allCases.map(\.rawValue)
        #expect(Set(slugs).count == slugs.count)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz-")
        for slug in slugs {
            #expect(slug.unicodeScalars.allSatisfy { allowed.contains($0) })
        }
    }

    // MARK: - Fixtures

    // JointName is not CaseIterable, and the count is the invariant: 19, not the slide's 17
    private static let allJointNames: [HumanBodyPoseObservation.JointName] = [
        .leftEar, .leftEye, .rightEar, .rightEye, .neck, .nose,
        .leftShoulder, .leftElbow, .leftWrist,
        .rightShoulder, .rightElbow, .rightWrist,
        .root, .leftHip, .leftKnee, .leftAnkle, .rightHip, .rightKnee, .rightAnkle
    ]

    private static func joint(_ name: HumanBodyPoseObservation.JointName, at index: Int) -> woolone.Joint {
        woolone.Joint(
            name: name,
            position: CGPoint(x: 100.5 + Double(index) * 13.25, y: 200.25 + Double(index) * 37.5),
            confidence: Float(index + 1) * 0.05
        )
    }

    private static func fullBody() -> PoseFrame {
        var joints: [HumanBodyPoseObservation.JointName: woolone.Joint] = [:]
        for (index, name) in allJointNames.enumerated() {
            joints[name] = joint(name, at: index)
        }
        return pose(joints)
    }

    private static func pose(
        _ joints: [HumanBodyPoseObservation.JointName: woolone.Joint],
        observation: Float = 1,
        milliseconds: Double = 22.4
    ) -> PoseFrame {
        PoseFrame(
            joints: joints,
            observationConfidence: observation,
            imageSize: CGSize(width: 720, height: 1280),
            orientation: .right,
            supportedJointCount: 19,
            inferenceMilliseconds: milliseconds
        )
    }

    private static func header() -> RecordingHeader {
        RecordingHeader(
            condition: .offAxis,
            camera: .back,
            startedAt: Date(timeIntervalSince1970: 1_787_000_000),
            sample: pose([:]),
            captureFps: 30
        )
    }
}
