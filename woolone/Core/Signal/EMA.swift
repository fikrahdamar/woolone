//
//  EMA.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 01/09/26.
//

import CoreGraphics
import Foundation

/// Exponential moving average that a bad frame cannot poison — non-finite input is refused, not absorbed.
nonisolated struct EMA {
    /// Measured on the recordings: 0.3 costs 2.4° of depth at the bottom of a fast rep, 0.4 costs 1.4°,
    /// and the jitter it removes is only 18% either way because standing sway is too slow to filter.
    static let defaultWeight: CGFloat = 0.4

    let weight: CGFloat
    private(set) var value: CGFloat?

    init(weight: CGFloat = EMA.defaultWeight) {
        self.weight = weight
    }

    /// nil leaves the average untouched: a frame with no reading is missing data, not a reading of zero.
    @discardableResult
    mutating func update(_ raw: CGFloat?) -> CGFloat? {
        guard let raw, raw.isFinite else { return value }
        guard let current = value else {
            value = raw
            return value
        }
        value = current * (1 - weight) + raw * weight
        return value
    }

    mutating func reset() {
        value = nil
    }
}
