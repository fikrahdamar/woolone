//
//  SpeechCoach.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 04/09/26.
//

import CoreGraphics
import Foundation

/// Decides what should be said, and when. Knows nothing about how to say it.
// two kinds of cue, and they must not behave the same. An event happened once and repeating it
// is confusing — "up" after you have already stood up is noise. A state is something still wrong,
// and saying it once then going quiet leaves the user stuck.
nonisolated struct SpeechCoach {
    /// How long a state cue waits before saying itself again.
    // a preference, not a measurement: nothing in the recordings decides it. Speech takes about a
    // second and a person needs a few more to react and re-check. Tune by using it, not by data.
    static let repeatAfter: Double = 5

    enum Cue: Equatable, Sendable {
        case stepBack
        case standUp
        case squareUp
        case ready
        case up
        case good
        case deeper

        var phrase: String {
            switch self {
            case .stepBack: "step back"
            case .standUp: "stand up"
            case .squareUp: "square up"
            case .ready: "ready"
            case .up: "up"
            case .good: "good"
            case .deeper: "go deeper"
            }
        }

        /// Something still wrong, so it says itself again until it is fixed.
        var isState: Bool {
            switch self {
            case .stepBack, .standUp, .squareUp: true
            case .ready, .up, .good, .deeper: false
            }
        }
    }

    private var spoken: Cue?
    private var spokenAt: Double = 0
    private var saidReady = false
    private var saidUp = false

    /// `judgement` is non-nil only on the frame a rep finishes.
    mutating func update(
        state: SetupGate.State,
        isSquare: Bool,
        angle: CGFloat?,
        depthLimit: CGFloat,
        judgement: FormJudge.Judgement?,
        at now: Double
    ) -> Cue? {
        // a finished rep outranks everything: it is the only cue tied to a moment that just passed
        if let judgement {
            saidUp = false
            return emit(judgement.passed ? .good : .deeper, at: now)
        }

        // back upright — the next descent gets its own "up"
        if let angle, angle >= SetupGate.standingKnee { saidUp = false }

        if let cue = stateCue(state, isSquare: isSquare) {
            if case .armed = state {} else { saidReady = false }
            return emit(cue, at: now)
        }

        guard state == .armed else { return nil }

        if !saidReady {
            saidReady = true
            return emit(.ready, at: now)
        }

        // the one cue that can be acted on the instant it arrives: you are deep enough, come up
        if !saidUp, let angle, angle <= depthLimit, isSquare {
            saidUp = true
            return emit(.up, at: now)
        }
        return nil
    }

    mutating func reset() {
        spoken = nil
        spokenAt = 0
        saidReady = false
        saidUp = false
    }

    // ordered by what blocks the set most: a lost joint stops everything, a crooked body only
    // stops grading
    private func stateCue(_ state: SetupGate.State, isSquare: Bool) -> Cue? {
        switch state {
        case .waiting(.missingJoints): .stepBack
        case .waiting(.notStanding): .standUp
        case .waiting(.noPerson): nil
        case .holding: nil
        case .armed: isSquare ? nil : .squareUp
        }
    }

    // only a state cue is throttled here. An event cue is guarded by its own flag, and a second
    // "up" means a second descent — suppressing it would silence every rep after the first
    private mutating func emit(_ cue: Cue, at now: Double) -> Cue? {
        if cue.isState, cue == spoken, now - spokenAt < Self.repeatAfter { return nil }
        spoken = cue
        spokenAt = now
        return cue
    }
}
