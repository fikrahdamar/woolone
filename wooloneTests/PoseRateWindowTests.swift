//
//  PoseRateWindowTests.swift
//  wooloneTests
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import Testing
@testable import woolone

struct PoseRateWindowTests {
    @Test func holdsSilentUntilAFullSecondHasPassed() {
        var window = PoseRateWindow(start: 0)
        #expect(window.record(inferenceMilliseconds: 30, at: 0.5) == nil)
        #expect(window.record(inferenceMilliseconds: 30, at: 0.9) == nil)
    }

    @Test func reportsRateAndMeanOverTheWindow() throws {
        var window = PoseRateWindow(start: 0)
        _ = window.record(inferenceMilliseconds: 20, at: 0.4)
        let emitted = window.record(inferenceMilliseconds: 40, at: 1.0)
        let stats = try #require(emitted)

        #expect(stats.framesPerSecond == 2)
        #expect(stats.meanInferenceMilliseconds == 30)
        #expect(stats.peakInferenceMilliseconds == 40)
    }

    @Test func startsCleanAfterEmitting() throws {
        var window = PoseRateWindow(start: 0)
        let first = window.record(inferenceMilliseconds: 90, at: 1.0)
        _ = try #require(first)
        let emitted = window.record(inferenceMilliseconds: 10, at: 2.0)
        let second = try #require(emitted)

        #expect(second.framesPerSecond == 1)
        #expect(second.meanInferenceMilliseconds == 10)
        #expect(second.peakInferenceMilliseconds == 10)
    }
}
