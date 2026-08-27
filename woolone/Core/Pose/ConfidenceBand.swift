//
//  ConfidenceBand.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 26/08/26.
//

import Foundation

/// Which side of the existing gates a joint falls on — a colour ramp, not a new threshold.
nonisolated enum ConfidenceBand: Sendable, Equatable {
    case drawable
    case judgeableOnly
    case unusable

    init(_ confidence: Float) {
        if confidence >= PoseConfidence.draw {
            self = .drawable
        } else if confidence >= PoseConfidence.judge {
            self = .judgeableOnly
        } else {
            self = .unusable
        }
    }
}
