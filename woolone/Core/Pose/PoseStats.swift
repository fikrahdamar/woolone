//
//  PoseStats.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import Foundation

/// One second of detection health — the 720p per-frame cost the 30ms still-image number does not predict.
nonisolated struct PoseStats: Sendable, Equatable {
    let framesPerSecond: Double
    let meanInferenceMilliseconds: Double
    let peakInferenceMilliseconds: Double

    static let idle = PoseStats(
        framesPerSecond: 0,
        meanInferenceMilliseconds: 0,
        peakInferenceMilliseconds: 0
    )
}
