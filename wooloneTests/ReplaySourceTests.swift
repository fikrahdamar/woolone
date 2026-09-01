//
//  ReplaySourceTests.swift
//  wooloneTests
//
//  Created by Fikrah Damar Huda on 31/08/26.
//

import CoreGraphics
import Foundation
import Testing
import Vision
@testable import woolone

struct ReplaySourceTests {
    /// The round trip #12 could not test alone: FrameLogger writes it, ReplaySource reads it back.
    @Test func aLoggedRecordingReplaysEveryFrameThatWasWritten() async throws {
        let (recording, url) = try await Self.write(frames: 10)
        defer { try? FileManager.default.removeItem(at: url) }

        let source = try ReplaySource(recording)
        #expect(source.frameCount == 10)

        for index in 0..<10 {
            await source.seek(to: index)
            let frame = try #require(await source.current)
            let knee = try #require(frame.joints[.leftKnee])
            #expect(abs(knee.confidence - Self.marker(index)) < 0.001)
        }
    }

    @Test func playingRunsToTheLastFrameAndStops() async throws {
        let (recording, url) = try await Self.write(frames: 10)
        defer { try? FileManager.default.removeItem(at: url) }

        let source = try ReplaySource(recording)
        await source.play()
        await source.waitForPlayback()

        let index = await source.index
        let playing = await source.isPlaying
        #expect(index == 9)
        #expect(playing == false)
    }

    @Test func seekLandsOnTheRequestedFrame() async throws {
        let (recording, url) = try await Self.write(frames: 10)
        defer { try? FileManager.default.removeItem(at: url) }
        let source = try ReplaySource(recording)

        await source.seek(to: 7)
        let index = await source.index
        #expect(index == 7)

        let frame = try #require(await source.current)
        let knee = try #require(frame.joints[.leftKnee])
        #expect(abs(knee.confidence - Self.marker(7)) < 0.001)
    }

    @Test func seekClampsRatherThanCrashing() async throws {
        let (recording, url) = try await Self.write(frames: 10)
        defer { try? FileManager.default.removeItem(at: url) }
        let source = try ReplaySource(recording)

        await source.seek(to: 999)
        let high = await source.index
        #expect(high == 9)

        await source.seek(to: -5)
        let low = await source.index
        #expect(low == 0)
    }

    @Test func stepMovesOneFrameAndStopsAtBothEnds() async throws {
        let (recording, url) = try await Self.write(frames: 10)
        defer { try? FileManager.default.removeItem(at: url) }
        let source = try ReplaySource(recording)

        await source.step(by: 1)
        let forward = await source.index
        #expect(forward == 1)

        await source.step(by: -1)
        await source.step(by: -1)
        let atStart = await source.index
        #expect(atStart == 0)

        await source.seek(to: 9)
        await source.step(by: 1)
        let atEnd = await source.index
        #expect(atEnd == 9)
    }

    /// A recording killed mid-write ends in a half-line. It costs one frame, not the file.
    @Test func aTruncatedLastLineCostsOneFrameNotTheRecording() async throws {
        let (_, url) = try await Self.write(frames: 10)
        defer { try? FileManager.default.removeItem(at: url) }

        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"kind\":\"frame\",\"t\":9.9,\"ob".utf8))
        try handle.close()

        let source = try ReplaySource(try Recording(url: url))
        #expect(source.frameCount == 10)
    }

    @Test func theHeaderSuppliesWhatTheFrameLinesOmit() async throws {
        let (recording, url) = try await Self.write(frames: 3)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(recording.header.condition == RecordingCondition.cleanSide.rawValue)

        let source = try ReplaySource(recording)
        await source.seek(to: 1)
        let frame = try #require(await source.current)

        #expect(frame.imageSize == CGSize(width: 720, height: 1280))
        #expect(frame.orientation == .leftMirrored)
        #expect(frame.supportedJointCount == 19)
    }

    /// A recorded session has no camera to flip, and the seam must accept the request anyway.
    @Test func flippingTheCameraIsAcceptedAndIgnored() async throws {
        let (recording, url) = try await Self.write(frames: 3)
        defer { try? FileManager.default.removeItem(at: url) }

        let source = try ReplaySource(recording)
        try await source.use(.front)
        #expect(source.frameCount == 3)
    }

    // MARK: - Fixtures

    // one distinguishable confidence per frame, so a seek can be checked against where it landed
    private static func marker(_ index: Int) -> Float { Float(index + 1) / 100 }

    private static func write(frames count: Int) async throws -> (Recording, URL) {
        let logger = FrameLogger(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        let url = try await logger.start(.cleanSide, camera: .front, sample: pose(confidence: 0.5))
        for index in 0..<count {
            await logger.record(pose(confidence: marker(index)))
        }
        await logger.stop()
        return (try Recording(url: url), url)
    }

    private static func pose(confidence: Float) -> PoseFrame {
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
