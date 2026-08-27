//
//  ConfidenceBandTests.swift
//  wooloneTests
//
//  Created by Fikrah Damar Huda on 26/08/26.
//

import Testing
@testable import woolone

struct ConfidenceBandTests {
    @Test func theGatesAreTheBoundaries() {
        #expect(ConfidenceBand(PoseConfidence.draw) == .drawable)
        #expect(ConfidenceBand(PoseConfidence.judge) == .judgeableOnly)
    }

    @Test func justBelowAGateFallsToTheNextBand() {
        #expect(ConfidenceBand(PoseConfidence.draw - 0.01) == .judgeableOnly)
        #expect(ConfidenceBand(PoseConfidence.judge - 0.01) == .unusable)
    }

    @Test func theExtremesLandWhereYouWouldExpect() {
        #expect(ConfidenceBand(1) == .drawable)
        #expect(ConfidenceBand(0) == .unusable)
    }
}
