//
//  AngleTests.swift
//  wooloneTests
//
//  Created by Fikrah Damar Huda on 27/08/26.
//

import CoreGraphics
import Testing
@testable import woolone

struct AngleTests {
    @Test func aRightAngleReadsNinety() throws {
        let value = try #require(angle(
            CGPoint(x: 0, y: 100),
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0)
        ))
        #expect(abs(value - 90) < 0.001)
    }

    @Test func aStraightLineReadsOneEighty() throws {
        let value = try #require(angle(
            CGPoint(x: -50, y: 0),
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 0)
        ))
        #expect(abs(value - 180) < 0.001)
    }

    /// Both arms in the same direction — the standing knee, near enough
    @Test func armsPointingTheSameWayReadZero() throws {
        let value = try #require(angle(
            CGPoint(x: 0, y: 10),
            CGPoint(x: 0, y: 0),
            CGPoint(x: 0, y: 40)
        ))
        #expect(abs(value) < 0.001)
    }

    @Test func aJointOnTheVertexHasNoAngle() {
        #expect(angle(.zero, .zero, CGPoint(x: 10, y: 10)) == nil)
        #expect(angle(CGPoint(x: 10, y: 10), .zero, .zero) == nil)
    }

    /// Collinear arms whose ratio rounds to 1.0000000000000004 — acos of that is NaN, not 0.
    // found by search, not invented: these exact values overflow, most collinear pairs do not
    @Test func aRatioPastOneIsClampedRatherThanReturningNaN() throws {
        let value = try #require(angle(
            CGPoint(x: -719.8731822441885, y: -95.53225868893048),
            .zero,
            CGPoint(x: -1732.6695949343807, y: -229.93750017147823)
        ))
        #expect(!value.isNaN)
        #expect(abs(value) < 0.001)
    }

    @Test func aRealisticSquatBottomIsAcute() throws {
        // hip above and behind, ankle below — knee at the vertex, roughly parallel depth
        let value = try #require(angle(
            CGPoint(x: 320, y: 700),
            CGPoint(x: 360, y: 900),
            CGPoint(x: 350, y: 1120)
        ))
        #expect(value > 100)
        #expect(value < 180)
    }
}
