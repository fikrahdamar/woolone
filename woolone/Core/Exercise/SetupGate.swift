//
//  SetupGate.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 01/09/26.
//

import CoreGraphics
import Foundation
import Vision

/// Nothing is judged until the camera can honestly see it. Pure — the clock is an argument.
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
        case notSquare(CGFloat)
    }

    enum State: Equatable {
        case waiting(Reason)
        case holding(remaining: Double)
        case armed
    }

    private(set) var state: State = .waiting(.noPerson)
    private var holdStarted: Double?
    private var recent: [CGFloat] = []

    @discardableResult
    mutating func update(_ frame: PoseFrame, at now: Double) -> State {
        guard frame.hasPerson else { return fail(.noPerson) }

        let missing = Self.required.filter { (frame.joints[$0]?.confidence ?? 0) < PoseConfidence.judge }
        guard missing.isEmpty else { return fail(.missingJoints(missing)) }
        guard frame.leg(.left, above: PoseConfidence.judge).count == 3
                || frame.leg(.right, above: PoseConfidence.judge).count == 3 else {
            return fail(.missingJoints([.leftAnkle, .rightAnkle]))
        }

        // once armed, only losing a joint disarms — framing was settled during the hold and the
        // shoulders necessarily open up as the torso bends, which is movement rather than a fault
        if state == .armed { return state }

        guard let knee = frame.straightestKnee, knee >= Self.standingKnee else {
            return fail(.notStanding)
        }
        guard let spread = frame.shoulderSpread else { return fail(.noPerson) }

        recent.append(spread)
        if recent.count > Self.windowFrames { recent.removeFirst() }
        let median = Self.median(recent)
        guard median <= Self.spreadLimit else { return fail(.notSquare(median)) }

        let started = holdStarted ?? now
        holdStarted = started
        let remaining = Self.holdSeconds - (now - started)
        state = remaining <= 0 ? .armed : .holding(remaining: remaining)
        return state
    }

    mutating func reset() {
        state = .waiting(.noPerson)
        holdStarted = nil
        recent.removeAll()
    }

    private mutating func fail(_ reason: Reason) -> State {
        holdStarted = nil
        if case .notSquare = reason {} else { recent.removeAll() }
        state = .waiting(reason)
        return state
    }

    private static func median(_ values: [CGFloat]) -> CGFloat {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return .greatestFiniteMagnitude }
        return sorted[sorted.count / 2]
    }
}
