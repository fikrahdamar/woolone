//
//  SetupGate.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 01/09/26.
//

import CoreGraphics
import Foundation
import Vision

/// Arms a set once the body is present and still, and says separately whether it may be graded.
// counting and grading are gated differently on purpose: a crooked camera still counts honestly,
// it just cannot be trusted with an angle. Blocking the arm on framing would have silently made a
// bad camera angle destroy the rep count too — the one thing that was supposed to survive it.
nonisolated struct SetupGate {
    /// Above this the knee angle is read through foreshortening: r = 0.71 against measured depth, +15° per 0.1.
    static let spreadLimit: CGFloat = 0.15
    /// Standing measured 173–180° across 1826 frames, so this is generous rather than fussy.
    static let standingKnee: CGFloat = 160
    static let holdSeconds: Double = 3
    /// Half a second of samples: one jittery frame must not restart the countdown.
    static let windowFrames = 15

    /// Everything the framing measurement needs. The leg is checked separately — either side will do.
    static let required: [HumanBodyPoseObservation.JointName] = [
        .neck, .root, .leftShoulder, .rightShoulder, .leftHip, .rightHip
    ]

    enum Reason: Equatable {
        case noPerson
        case missingJoints([HumanBodyPoseObservation.JointName])
        case notStanding
    }

    enum State: Equatable {
        case waiting(Reason)
        case holding(remaining: Double)
        /// A set is running: count its reps. Whether they may be graded is `isSquare`.
        case armed
    }

    private(set) var state: State = .waiting(.noPerson)
    /// Square enough for the knee angle to mean what it says. Grading reads this; counting does not.
    private(set) var isSquare = false
    /// The median the verdict was made on, not the current frame — showing the frame reads as a lie
    /// when the two disagree, and they disagree exactly when the body is moving.
    private(set) var spread: CGFloat?
    /// The rep signal while standing still — the counter measures every descent against this.
    private(set) var baseline: CGFloat?
    /// Dropouts survived since the set began. Above zero means the recording has gaps in it.
    private(set) var lossesSinceArming = 0

    private var holdStarted: Double?
    private var spreads: [CGFloat] = []
    private var signals: [CGFloat] = []
    private var missingFrames = 0

    @discardableResult
    mutating func update(_ frame: PoseFrame, at now: Double) -> State {
        if let reason = Self.loss(in: frame) {
            missingFrames += 1
            if missingFrames == 1, state == .armed { lossesSinceArming += 1 }
            // a knee or ankle blurs below the gate for a frame or two on every fast rep — measured
            // at 17 dropouts in one set, none longer than 0.4s. Disarming on the first of them ended
            // the set, and re-arming needs three still seconds that never come mid-set
            if state == .armed, missingFrames < Self.windowFrames { return state }
            return fail(reason)
        }
        missingFrames = 0

        let isStanding = (frame.straightestKnee ?? 0) >= Self.standingKnee

        // framing is judged only while standing, before the set and at the top of every rep.
        // bending opens the shoulders too, so measuring mid-rep would read movement as a fault —
        // but turning away mid-set is a real fault, and freezing the verdict at arming hid it
        if isStanding, let measured = frame.shoulderSpread {
            spreads.append(measured)
            if spreads.count > Self.windowFrames { spreads.removeFirst() }
            spread = Self.median(spreads)
            isSquare = spread.map { $0 <= Self.spreadLimit } ?? false
        }

        // a set that has started keeps counting: only a lost joint ends it
        if state == .armed { return state }

        guard isStanding else { return fail(.notStanding) }

        if let signal = frame.repSignal { signals.append(signal) }

        let started = holdStarted ?? now
        holdStarted = started
        let remaining = Self.holdSeconds - (now - started)
        guard remaining <= 0 else {
            state = .holding(remaining: remaining)
            return state
        }
        // the median of the whole hold, not the last frame: one jittery sample shifts every rep after it
        baseline = Self.median(signals)
        state = .armed
        return state
    }

    mutating func reset() {
        state = .waiting(.noPerson)
        isSquare = false
        holdStarted = nil
        baseline = nil
        missingFrames = 0
        lossesSinceArming = 0
        spreads.removeAll()
        signals.removeAll()
    }

    private static func loss(in frame: PoseFrame) -> Reason? {
        guard frame.hasPerson else { return .noPerson }
        let missing = required.filter { (frame.joints[$0]?.confidence ?? 0) < PoseConfidence.judge }
        guard missing.isEmpty else { return .missingJoints(missing) }
        guard frame.leg(.left, above: PoseConfidence.judge).count == 3
                || frame.leg(.right, above: PoseConfidence.judge).count == 3 else {
            return .missingJoints([.leftAnkle, .rightAnkle])
        }
        return nil
    }

    private mutating func fail(_ reason: Reason) -> State {
        holdStarted = nil
        spreads.removeAll()
        signals.removeAll()
        state = .waiting(reason)
        return state
    }

    private static func median(_ values: [CGFloat]) -> CGFloat? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}
