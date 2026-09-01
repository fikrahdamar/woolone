//
//  RepCounterTests.swift
//  wooloneTests
//
//  Created by Fikrah Damar Huda on 01/09/26.
//

import CoreGraphics
import Foundation
import Testing
@testable import woolone

struct RepCounterTests {
    @Test func nothingIsCountedBeforeTheGateArmsIt() {
        var counter = RepCounter()
        for (index, value) in Self.reps(5).enumerated() {
            counter.update(signal: value, angle: 90, at: Double(index) / 30)
        }
        #expect(counter.count == 0)
        #expect(counter.isArmed == false)
    }

    @Test func fiveCleanRepsCountFive() {
        var counter = RepCounter()
        counter.arm(baseline: 0)
        for (index, value) in Self.reps(5).enumerated() {
            counter.update(signal: value, angle: 90, at: Double(index) / 30)
        }
        #expect(counter.count == 5)
    }

    /// The reason there are two thresholds at all: one would count this waveform twice per rep.
    @Test func jitterOnTheThresholdDoesNotDoubleCount() {
        var counter = RepCounter()
        counter.arm(baseline: 0)

        var samples: [CGFloat] = []
        for rep in 0..<3 {
            samples += Self.descend(to: 0.30)
            // hover either side of the drop threshold, the shape that breaks a single threshold
            for step in 0..<20 {
                samples.append(RepCounter.drop + (step % 2 == 0 ? 0.01 : -0.01))
            }
            samples += Self.rise(from: 0.30)
            _ = rep
        }
        for (index, value) in samples.enumerated() {
            counter.update(signal: value, angle: 90, at: Double(index) / 30)
        }
        #expect(counter.count == 3)
    }

    /// A descent that is abandoned halfway is not a rep. Counting on the way up is what makes that true.
    @Test func anAbandonedDescentIsNotCounted() {
        var counter = RepCounter()
        counter.arm(baseline: 0)

        let samples = Self.descend(to: 0.30) + Self.rise(from: 0.30, to: 0.15) + Self.descend(from: 0.15, to: 0.30)
        for (index, value) in samples.enumerated() {
            counter.update(signal: value, angle: 90, at: Double(index) / 30)
        }
        #expect(counter.count == 0)
        #expect(counter.isDown)
    }

    @Test func aRepCarriesItsDepthAndItsTempo() throws {
        var counter = RepCounter()
        counter.arm(baseline: 0)

        var rep: RepCounter.Rep?
        let samples = Self.descend(to: 0.30) + Self.rise(from: 0.30)
        for (index, value) in samples.enumerated() {
            // the angle bottoms out in the middle of the descent, where a real one does
            let angle: CGFloat = value > 0.25 ? 84 : 150
            if let produced = counter.update(signal: value, angle: angle, at: Double(index) / 30) {
                rep = produced
            }
        }
        let counted = try #require(rep)
        #expect(counted.index == 1)
        #expect(counted.lowestAngle == 84)
        #expect(counted.seconds > 0)
    }

    @Test func aFrameWithNoReadingIsSkippedNotCounted() {
        var counter = RepCounter()
        counter.arm(baseline: 0)

        var samples: [CGFloat?] = Self.descend(to: 0.30).map { $0 }
        samples += [nil, nil, nil]
        samples += Self.rise(from: 0.30).map { $0 }
        for (index, value) in samples.enumerated() {
            counter.update(signal: value, angle: 90, at: Double(index) / 30)
        }
        #expect(counter.count == 1)
    }

    // MARK: - Fixtures

    private static func descend(from: CGFloat = 0, to: CGFloat) -> [CGFloat] {
        stride(from: from, through: to, by: 0.01).map { $0 }
    }

    private static func rise(from: CGFloat, to: CGFloat = 0) -> [CGFloat] {
        stride(from: from, through: to, by: -0.01).map { $0 }
    }

    private static func reps(_ count: Int) -> [CGFloat] {
        (0..<count).flatMap { _ in descend(to: 0.30) + rise(from: 0.30) }
    }
}
