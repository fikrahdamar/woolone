//
//  ReplayProgress.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 31/08/26.
//

import Foundation

/// Where a replay is up to — the scrubber's state, and the only thing the camera has no equivalent of.
nonisolated struct ReplayProgress: Sendable, Equatable {
    let index: Int
    let count: Int
    let seconds: Double
    let isPlaying: Bool

    static let idle = ReplayProgress(index: 0, count: 0, seconds: 0, isPlaying: false)
}
