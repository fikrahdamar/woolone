//
//  RecordingCondition.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 30/08/26.
//

import Foundation

/// A fixed list, not free text — thresholds come from clean-side alone, and a typo silently splits a group.
nonisolated enum RecordingCondition: String, CaseIterable, Sendable {
    case cleanSide = "clean-side"
    case tooClose = "too-close"
    case tooFar = "too-far"
    case offAxis = "off-axis"
    case fastReps = "fast-reps"
    case slowReps = "slow-reps"
    case pausedBottom = "paused-bottom"
    case badSet = "bad-set"

    var label: String { rawValue.replacingOccurrences(of: "-", with: " ") }
}
