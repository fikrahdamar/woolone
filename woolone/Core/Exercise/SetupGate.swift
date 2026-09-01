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
    private(set) var spread: CGFloat?
    /// The rep signal while standing still — the counter measures every descent against this.
    private(set) var baseline: CGFloat?

    private var holdStarted: Double?
    private var spreads: [CGFloat] = []
    private var signals: [CGFloat] = []

    @discardableResult
    mutating func update(_ frame: PoseFrame, at now: Double) -> State {
        spread = frame.shoulderSpread

        guard frame.hasPerson else { return fail(.noPerson) }
        let missing = Self.required.filter { (frame.joints[$0]?.confidence ?? 0) < PoseConfidence.judge }
        guard missing.isEmpty else { return fail(.missingJoints(missing)) }
        guard frame.leg(.left, above: PoseConfidence.judge).count == 3
                || frame.leg(.right, above: PoseConfidence.judge).count == 3 else {
            return fail(.missingJoints([.leftAnkle, .rightAnkle]))
        }

        // once armed, only losing a joint disarms — the shoulders necessarily open as the torso bends,
        // which is movement rather than a fault, and a live check would end the set during rep one
        if state == .armed { return state }

        guard let knee = frame.straightestKnee, knee >= Self.standingKnee else {
            return fail(.notStanding)
        }

        if let spread { spreads.append(spread) }
        if spreads.count > Self.windowFrames { spreads.removeFirst() }
        isSquare = Self.median(spreads).map { $0 <= Self.spreadLimit } ?? false

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
        spreads.removeAll()
        signals.removeAll()
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
