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

        #expect(coach.standing(at: 11) == nil)
        #expect(coach.bottom(at: 12) == .up)
    }

    @Test func aFinishedRepIsJudgedOutLoud() {
        var coach = SpeechCoach()
        coach.armAndReady()

        #expect(coach.finished(depth: 70, at: 10) == .good)
        #expect(coach.finished(depth: 110, at: 14) == .deeper)
    }

    /// Nothing is said while the camera cannot see the body — the user is out of the room.
    @Test func nobodyInFrameSaysNothing() {
        var coach = SpeechCoach()
        #expect(coach.update(
            state: .waiting(.noPerson), isSquare: false, angle: nil,
            depthLimit: 86, judgement: nil, at: 0
        ) == nil)
    }

    @Test func aLostJointOutranksACrookedBody() {
        var coach = SpeechCoach()
        #expect(coach.update(
            state: .waiting(.missingJoints([.leftAnkle])), isSquare: false, angle: 175,
            depthLimit: 86, judgement: nil, at: 0
        ) == .stepBack)
    }

    /// A crooked camera means the angle is wrong, so telling the user to come up would be a lie.
    @Test func theDepthCueIsSilentWhenTheAngleCannotBeTrusted() {
        var coach = SpeechCoach()
        _ = coach.update(state: .armed, isSquare: false, angle: 175,
                         depthLimit: 86, judgement: nil, at: 0)
        #expect(coach.update(state: .armed, isSquare: false, angle: 70,
                             depthLimit: 86, judgement: nil, at: 1) == nil)
    }

    @Test func armingAnnouncesItselfOnce() {
        var coach = SpeechCoach()
        #expect(coach.standing(at: 0) == .ready)
        #expect(coach.standing(at: 1) == nil)
    }
}

private extension SpeechCoach {
    mutating func crooked(at now: Double) -> Cue? {
        update(state: .armed, isSquare: false, angle: 175, depthLimit: 86, judgement: nil, at: now)
    }

    mutating func standing(at now: Double) -> Cue? {
        update(state: .armed, isSquare: true, angle: 175, depthLimit: 86, judgement: nil, at: now)
    }

    mutating func bottom(at now: Double) -> Cue? {
        update(state: .armed, isSquare: true, angle: 70, depthLimit: 86, judgement: nil, at: now)
    }

    mutating func finished(depth: CGFloat, at now: Double) -> Cue? {
        update(
            state: .armed, isSquare: true, angle: depth, depthLimit: 86,
            judgement: FormJudge.Judgement(
                rep: 1, fault: "depth", measured: depth, limit: 86,
                passed: depth <= 86, cue: depth <= 86 ? nil : "go deeper"
            ),
            at: now
        )
    }

    mutating func armAndReady() {
        _ = standing(at: 0)
    }
}
