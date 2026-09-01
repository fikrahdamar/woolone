//
//  RepCounter.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 01/09/26.
//

import CoreGraphics
import Foundation

/// Two thresholds, counted on the way up. One threshold double-counts the moment the signal jitters.
nonisolated struct RepCounter {
    /// Descend this far below the standing baseline, in torso lengths, to be counted as down.
    // fixed thresholds failed: a shallow rep never reaches them. Relative to the baseline captured
    // during the setup hold, 0.20/0.08 gave a consistent count on 25 of 30 recordings.
    static let drop: CGFloat = 0.20
    /// And return within this of the baseline before the rep counts. The gap is the hysteresis.
    static let back: CGFloat = 0.08

    struct Rep: Equatable, Sendable {
        let index: Int
        /// The smallest knee angle seen while down — depth, for whatever judges it.
        let lowestAngle: CGFloat?
        /// Descent to lockout, in seconds — tempo, free from the same signal.
        let seconds: Double
    }

    private(set) var count = 0
    private(set) var isDown = false
    private(set) var lastRep: Rep?

    private var baseline: CGFloat?
    private var lowestAngle: CGFloat?
    private var enteredAt: Double?

    var isArmed: Bool { baseline != nil }

    /// Called when the setup gate arms — the hold is standing still, which is exactly the baseline.
    mutating func arm(baseline: CGFloat) {
        self.baseline = baseline
        // a fresh setup hold is a fresh set, so the count starts again
        count = 0
        lastRep = nil
        isDown = false
        lowestAngle = nil
        enteredAt = nil
    }

    @discardableResult
    mutating func update(signal: CGFloat?, angle: CGFloat?, at now: Double) -> Rep? {
        guard let baseline, let signal else { return nil }
        let depth = signal - baseline

        if isDown, let angle {
            lowestAngle = min(lowestAngle ?? angle, angle)
        }

        if !isDown, depth > Self.drop {
            isDown = true
            enteredAt = now
            lowestAngle = angle
            return nil
        }

        // counted on the way up: a descent can be abandoned, a lockout cannot
        guard isDown, depth < Self.back else { return nil }
        isDown = false
        count += 1
        let rep = Rep(
            index: count,
            lowestAngle: lowestAngle,
            seconds: now - (enteredAt ?? now)
        )
        lastRep = rep
        lowestAngle = nil
        enteredAt = nil
        return rep
    }

    mutating func reset() {
        count = 0
        isDown = false
        lastRep = nil
        baseline = nil
        lowestAngle = nil
        enteredAt = nil
    }
}
