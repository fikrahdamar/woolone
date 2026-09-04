//
//  SpeechCoachTests.swift
//  wooloneTests
//
//  Created by Fikrah Damar Huda on 04/09/26.
//

import CoreGraphics
import Foundation
import Testing
import Vision
@testable import woolone

struct SpeechCoachTests {
    /// The whole point of the design: an event is said once, a state nags until it is fixed.
    @Test func aStateCueRepeatsWhileTheProblemLasts() {
        var coach = SpeechCoach()
        #expect(coach.crooked(at: 0) == .squareUp)
        #expect(coach.crooked(at: 1) == nil)
        #expect(coach.crooked(at: 4.9) == nil)
        #expect(coach.crooked(at: 5.0) == .squareUp)
    }

    @Test func anEventCueIsNeverRepeated() {
        var coach = SpeechCoach()
        coach.armAndReady()

        #expect(coach.bottom(at: 10) == .up)
        for step in 1...20 {
            #expect(coach.bottom(at: 10 + Double(step)) == nil, "said up twice")
        }
    }

    /// Standing again is what arms the next rep's cue — an abandoned descent must not silence it.
    @Test func standingUpAgainRearmsTheDepthCue() {
        var coach = SpeechCoach()
        coach.armAndReady()
        #expect(coach.bottom(at: 10) == .up)

        #expect(coach.standing(at: 11) == .down)
        #expect(coach.bottom(at: 12) == .up)
    }

    /// One slot per rep: a good rep is worth its number, a bad one is worth the correction.
    @Test func aGoodRepIsCountedAndABadOneIsCorrected() {
        var coach = SpeechCoach()
        coach.armAndReady()

        #expect(coach.finished(1, depth: 70, at: 10) == .count(1))
        #expect(coach.finished(2, depth: 110, at: 14) == .deeper(2))
        #expect(coach.finished(3, depth: 62, at: 18) == .count(3))
    }

    /// Counting is view-invariant and grading is not — a crooked rep is still counted out loud.
    @Test func aRepTooCrookedToGradeIsStillCounted() {
        var coach = SpeechCoach()
        coach.armAndReady()

        #expect(coach.finishedUngraded(4, at: 10) == .count(4))
    }

    /// The cue the user actually asked for: standing still armed, something says to start.
    @Test func standingStillIsToldToGoDown() {
        var coach = SpeechCoach()
        #expect(coach.standing(at: 0) == .ready)
        #expect(coach.standing(at: 1) == .down)
    }

    /// A descent that never starts nags; one that starts goes quiet on its own.
    @Test func theDescentCueRepeatsUntilTheBodyMoves() {
        var coach = SpeechCoach()
        coach.armAndReady()
        #expect(coach.standing(at: 1) == .down)
        #expect(coach.standing(at: 3) == nil)
        #expect(coach.standing(at: 6.1) == .down)
        #expect(coach.bottom(at: 7) == .up, "descending must not be nagged to descend")
    }

    /// Nothing is said while the camera cannot see the body — the user is out of the room.
    @Test func nobodyInFrameSaysNothing() {
        var coach = SpeechCoach()
        #expect(coach.update(
            state: .waiting(.noPerson), isSquare: false, angle: nil,
            depthLimit: 86, finishedRep: nil, judgement: nil, at: 0
        ) == nil)
    }

    @Test func aLostJointOutranksACrookedBody() {
        var coach = SpeechCoach()
        #expect(coach.update(
            state: .waiting(.missingJoints([.leftAnkle])), isSquare: false, angle: 175,
            depthLimit: 86, finishedRep: nil, judgement: nil, at: 0
        ) == .stepBack)
    }

    /// A crooked camera means the angle is wrong, so telling the user to come up would be a lie.
    @Test func theDepthCueIsSilentWhenTheAngleCannotBeTrusted() {
        var coach = SpeechCoach()
        #expect(coach.crooked(at: 0) == .squareUp)
        #expect(coach.crookedBottom(at: 1) == nil)
    }

    /// The bug behind "down takes forever": the speaker was mid-sentence and dropped the cue, but
    /// the coach had already started its five-second repeat timer on a cue nobody ever heard.
    @Test func aCueTheSpeakerRefusedIsOfferedAgain() {
        var coach = SpeechCoach()
        #expect(coach.standing(at: 0) == .ready)

        #expect(coach.offeredStanding(at: 0.03) == .down)
        #expect(coach.offeredStanding(at: 0.06) == .down, "a cue nobody heard must come back")
        #expect(coach.standing(at: 0.7) == .down)
        #expect(coach.standing(at: 1.0) == nil, "and once heard, it waits its turn")
    }

    @Test func armingAnnouncesItselfOnce() {
        var coach = SpeechCoach()
        #expect(coach.standing(at: 0) == .ready)
        #expect(coach.standing(at: 1) == .down)
        #expect(coach.standing(at: 30) != .ready)
    }
}

private extension SpeechCoach {
    /// Stands in for a speaker that accepts every cue — the coach only starts a timer once told.
    mutating func spoken(_ cue: Cue?, at now: Double) -> Cue? {
        if let cue { spoke(cue, at: now) }
        return cue
    }

    mutating func crooked(at now: Double) -> Cue? {
        spoken(update(state: .armed, isSquare: false, angle: 175, depthLimit: 86,
                      finishedRep: nil, judgement: nil, at: now), at: now)
    }

    mutating func crookedBottom(at now: Double) -> Cue? {
        spoken(update(state: .armed, isSquare: false, angle: 70, depthLimit: 86,
                      finishedRep: nil, judgement: nil, at: now), at: now)
    }

    mutating func standing(at now: Double) -> Cue? {
        spoken(update(state: .armed, isSquare: true, angle: 175, depthLimit: 86,
                      finishedRep: nil, judgement: nil, at: now), at: now)
    }

    mutating func bottom(at now: Double) -> Cue? {
        spoken(update(state: .armed, isSquare: true, angle: 70, depthLimit: 86,
                      finishedRep: nil, judgement: nil, at: now), at: now)
    }

    /// The speaker refused: update was called, nothing was confirmed.
    mutating func offeredStanding(at now: Double) -> Cue? {
        update(state: .armed, isSquare: true, angle: 175, depthLimit: 86,
               finishedRep: nil, judgement: nil, at: now)
    }

    mutating func finished(_ rep: Int, depth: CGFloat, at now: Double) -> Cue? {
        spoken(update(
            state: .armed, isSquare: true, angle: depth, depthLimit: 86,
            finishedRep: rep,
            judgement: FormJudge.Judgement(
                rep: rep, fault: "depth", measured: depth, limit: 86,
                passed: depth <= 86, cue: depth <= 86 ? nil : "go deeper"
            ),
            at: now
        ), at: now)
    }

    /// Off-axis: the rep closes, FormJudge returns nil, and the count still has to be spoken.
    mutating func finishedUngraded(_ rep: Int, at now: Double) -> Cue? {
        spoken(update(state: .armed, isSquare: false, angle: 100, depthLimit: 86,
                      finishedRep: rep, judgement: nil, at: now), at: now)
    }

    mutating func armAndReady() {
        _ = standing(at: 0)
    }
}
