//
//  EMATests.swift
//  wooloneTests
//
//  Created by Fikrah Damar Huda on 01/09/26.
//

import CoreGraphics
import Foundation
import Testing
@testable import woolone

struct EMATests {
    @Test func theFirstReadingSeedsItRatherThanBeingAveragedAgainstZero() {
        var ema = EMA(weight: 0.4)
        #expect(ema.update(170) == 170)
    }

    @Test func itMovesTowardsTheInputWithoutOvershooting() throws {
        var ema = EMA(weight: 0.4)
        ema.update(100)
        let updated = ema.update(200)
        let next = try #require(updated)
        #expect(next > 100 && next < 200)
        #expect(abs(next - 140) < 0.001)
    }

    /// The failure this exists to prevent: NaN enters the average and the HUD freezes forever.
    @Test func aNonFiniteReadingCannotPoisonIt() throws {
        var ema = EMA(weight: 0.4)
        ema.update(120)
        ema.update(.nan)
        ema.update(.infinity)

        let value = try #require(ema.value)
        #expect(value == 120)
        let updated = ema.update(130)
        let next = try #require(updated)
        #expect(next.isFinite)
    }

    /// A frame with no angle is missing data, not a reading of zero.
    @Test func aMissingReadingLeavesTheAverageWhereItWas() {
        var ema = EMA(weight: 0.4)
        ema.update(150)
        #expect(ema.update(nil) == 150)
        #expect(ema.value == 150)
    }

    @Test func resetForgetsEverything() {
        var ema = EMA(weight: 0.4)
        ema.update(150)
        ema.reset()
        #expect(ema.value == nil)
        #expect(ema.update(90) == 90)
    }
}
