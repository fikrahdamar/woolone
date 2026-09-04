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
        case down
        case up
        case good
        case deeper(Int)
        case count(Int)

        var phrase: String {
            switch self {
            case .stepBack: "step back"
            case .standUp: "stand up"
            case .squareUp: "square up"
            case .ready: "ready"
            case .down: "down"
            case .up: "up"
            case .good: "good"
            // the number rides along on the correction too, or the spoken count silently skips
            // every rep the user got wrong and stops matching the HUD
            case .deeper(let rep): "\(rep), go deeper"
            case .count(let rep): "\(rep)"
            }
        }

        /// Worth cutting off whatever is still being said — this cue exists for one frame only.
        var interrupts: Bool {
            switch self {
            case .count, .deeper: true
            default: false
            }
        }

        /// Something still wrong, so it says itself again until it is fixed.
        var isState: Bool {
            switch self {
            // standing still is a state, and nagging is the point — a descent that never starts
            // is the case the user hit
            case .stepBack, .standUp, .squareUp, .down: true
            case .ready, .up, .good, .deeper, .count: false
            }
        }
    }

    private var spoken: Cue?
    private var spokenAt: Double = 0
    private var saidReady = false
    private var saidUp = false

    /// `finishedRep` and `judgement` are non-nil only on the frame a rep closes; a rep off-axis
    /// finishes without a judgement, and is still counted out loud.
    mutating func update(
        state: SetupGate.State,
        isSquare: Bool,
        angle: CGFloat?,
        depthLimit: CGFloat,
        finishedRep: Int?,
        judgement: FormJudge.Judgement?,
        at now: Double
    ) -> Cue? {
        // a finished rep outranks everything: it is the only cue tied to a moment that just passed.
        // Both branches carry the number, so the spoken count never diverges from the HUD
        if let finishedRep {
            saidUp = false
            if let judgement, !judgement.passed { return offer(.deeper(finishedRep), at: now) }
            return offer(.count(finishedRep), at: now)
        }

        // back upright — the next descent gets its own "up"
        if let angle, angle >= SetupGate.standingKnee { saidUp = false }

        // grouped with the other event cues, ahead of the state ones: an event is tied to a moment
        // and a state is not
        if !saidUp, state == .armed, isSquare, let angle, angle <= depthLimit {
            return offer(.up, at: now)
        }

        if let cue = stateCue(state, isSquare: isSquare) {
            if case .armed = state {} else { saidReady = false }
            return offer(cue, at: now)
        }

        guard state == .armed else { return nil }

        if !saidReady {
            return offer(.ready, at: now)
        }

        // said while standing still, where there is all the time in the world — the descent cue
        // cannot be spoken during the descent, which lasts less than a second
        if let angle, angle >= SetupGate.standingKnee {
            return offer(.down, at: now)
        }
        return nil
    }

    /// Called only once the cue was actually spoken. A cue the speaker refused is offered again
    /// next frame — the old code started the repeat timer on cues nobody ever heard.
    mutating func spoke(_ cue: Cue, at now: Double) {
        spoken = cue
        spokenAt = now
        if cue == .ready { saidReady = true }
        if cue == .up { saidUp = true }
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
    private func offer(_ cue: Cue, at now: Double) -> Cue? {
        if cue.isState, cue == spoken, now - spokenAt < Self.repeatAfter { return nil }
        return cue
    }
}
