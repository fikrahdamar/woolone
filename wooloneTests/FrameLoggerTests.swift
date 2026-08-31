//
//  FrameLoggerTests.swift
//  wooloneTests
//
//  Created by Fikrah Damar Huda on 30/08/26.
//

import CoreGraphics
import Foundation
import Testing
import Vision
@testable import woolone

struct FrameLoggerTests {
    /// The round trip is the acceptance criterion: a log ReplaySource cannot read taught nothing.
    @Test func aFinishedRecordingReadsBackAsTheFramesThatWentIn() async throws {
        let logger = FrameLogger()
        let url = try await logger.start(.cleanSide, camera: .back, sample: Self.pose())
        defer { try? FileManager.default.removeItem(at: url) }

        // 45 crosses the 30-frame flush, so both the buffered write and the remainder on stop are exercised
        for index in 0..<45 {
            await logger.record(Self.pose(confidence: Float(index % 19 + 1) * 0.05))
        }
        await logger.stop()

        let lines = try Self.lines(of: url)
        let first = try #require(lines.first)
        let header = try #require(RecordingHeader.decode(first))
        let frames = lines.dropFirst().compactMap { FrameLine.decode($0, header: header) }

        #expect(frames.count == 45)
        #expect(frames.allSatisfy { $0.pose.joints.count == 3 })
        #expect(zip(frames, frames.dropFirst()).allSatisfy { $0.seconds <= $1.seconds })
    }

    @Test func theHeaderDescribesTheSetupTheFramesWereShotUnder() async throws {
        let logger = FrameLogger()
        let url = try await logger.start(.offAxis, camera: .front, sample: Self.pose())
        defer { try? FileManager.default.removeItem(at: url) }
        await logger.record(Self.pose())
        await logger.stop()

        let first = try #require(Self.lines(of: url).first)
        let header = try #require(RecordingHeader.decode(first))
        #expect(header.condition == RecordingCondition.offAxis.rawValue)
        #expect(header.camera == CameraFacing.front.label)
        #expect(header.orientation == CameraFacing.front.imageOrientation.label)
        #expect(header.imageSize == CGSize(width: 720, height: 1280))
    }

    @Test func theFilenameNamesTheCondition() async throws {
        let logger = FrameLogger()
        let url = try await logger.start(.pausedBottom, camera: .back, sample: Self.pose())
        defer { try? FileManager.default.removeItem(at: url) }
        await logger.stop()

        #expect(url.lastPathComponent.hasPrefix("paused-bottom-"))
        #expect(url.pathExtension == "ndjson")
    }

    @Test func framesArrivingBeforeAStartAreNotWritten() async {
        let logger = FrameLogger()
        await logger.record(Self.pose())
        #expect(await logger.isRecording == false)
        #expect(await logger.stop() == nil)
    }

    @Test func aSecondStartIsRefusedRatherThanAbandoningTheFirstFile() async throws {
        let logger = FrameLogger()
        let url = try await logger.start(.tooFar, camera: .back, sample: Self.pose())
        defer { try? FileManager.default.removeItem(at: url) }

        await #expect(throws: FrameLogger.Failure.self) {
            try await logger.start(.tooClose, camera: .back, sample: Self.pose())
        }
        await logger.stop()
    }

    // MARK: - Fixtures

    private static func lines(of url: URL) throws -> [String] {
        try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n")
            .map(String.init)
    }

    private static func pose(confidence: Float = 0.9) -> PoseFrame {
        PoseFrame(
            joints: [
                .leftHip: woolone.Joint(name: .leftHip, position: CGPoint(x: 360, y: 600), confidence: confidence),
                .leftKnee: woolone.Joint(name: .leftKnee, position: CGPoint(x: 360, y: 850), confidence: confidence),
                .leftAnkle: woolone.Joint(name: .leftAnkle, position: CGPoint(x: 355, y: 1100), confidence: confidence)
            ],
            observationConfidence: 1,
            imageSize: CGSize(width: 720, height: 1280),
            orientation: .leftMirrored,
            supportedJointCount: 19,
            inferenceMilliseconds: 22.4
        )
    }
}
