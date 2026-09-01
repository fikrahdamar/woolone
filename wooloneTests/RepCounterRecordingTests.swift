//
//  RepCounterRecordingTests.swift
//  wooloneTests
//
//  Created by Fikrah Damar Huda on 01/09/26.
//

import CoreGraphics
import Foundation
import Testing
@testable import woolone

/// Synthetic waveforms prove the state machine. Only a real recording proves the thresholds.
struct RepCounterRecordingTests {
    @Test func theBundledRecordingsAreReachable() {
        #expect(Recording.bundled().count >= 4)
    }

    @Test func aCleanSideSetCountsItsReps() async throws {
        #expect(try await Self.count(in: "clean-side") == 4)
    }

    @Test func aPausedBottomSetCountsItsReps() async throws {
        #expect(try await Self.count(in: "paused-bottom") == 4)
    }

    /// The rule the whole project rests on: a bad camera angle counts honestly and refuses to grade.
    /// This recording sits 0.49 off square and its knee angle reads about 21° too shallow.
    // the exact count is deliberately not asserted — it has never been hand-labelled, and the
    // angle-based count that would have supplied it is exactly the number this file makes wrong
    @Test func anOffAxisSetStillCountsButIsNotGradeable() async throws {
        let result = try await Self.run(condition: "off-axis")
        #expect(result.count >= 3)
        #expect(result.isSquare == false)
    }

    @Test func aCleanSideSetIsGradeable() async throws {
        #expect(try await Self.run(condition: "clean-side").isSquare)
    }

    // MARK: - Fixtures

    private static func count(in condition: String) async throws -> Int {
        try await run(condition: condition).count
    }

    // the same chain the ViewModel runs, minus the camera: gate → signal → EMA → counter
    private static func run(condition: String) async throws -> (count: Int, isSquare: Bool) {
        let recording = try #require(Recording.bundled().first { $0.header.condition == condition })
        let source = try ReplaySource(recording)

        var signalEMA = EMA()
        var angleEMA = EMA()
        var selector = LegSelector()
        var gate = SetupGate()
        var counter = RepCounter()
        var wasArmed = false

        for index in 0..<source.frameCount {
            await source.seek(to: index)
            guard let frame = await source.current else { continue }
            let now = Double(index) / 30

            let state = gate.update(frame, at: now)
            _ = selector.select(from: frame)
            let angle = angleEMA.update(selector.side.flatMap { frame.kneeAngle($0) })
            let signal = signalEMA.update(frame.repSignal)

            if state == .armed {
                if !wasArmed, let baseline = gate.baseline {
                    counter.arm(baseline: baseline)
                }
                counter.update(signal: signal, angle: angle, at: now)
            }
            wasArmed = state == .armed
        }
        return (counter.count, gate.isSquare)
    }
}
