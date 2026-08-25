//
//  PoseRateWindow.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import Foundation

/// Accumulates detections and emits one PoseStats per elapsed second. Pure — the clock is an argument.
nonisolated struct PoseRateWindow {
    static let windowSeconds = 1.0

    private var frames = 0
    private var totalMilliseconds = 0.0
    private var peakMilliseconds = 0.0
    private var windowStart: Double

    init(start: Double) {
        windowStart = start
    }

    mutating func record(inferenceMilliseconds: Double, at now: Double) -> PoseStats? {
        frames += 1
        totalMilliseconds += inferenceMilliseconds
        peakMilliseconds = max(peakMilliseconds, inferenceMilliseconds)

        let elapsed = now - windowStart
        guard elapsed >= Self.windowSeconds else { return nil }

        let stats = PoseStats(
            framesPerSecond: Double(frames) / elapsed,
            meanInferenceMilliseconds: totalMilliseconds / Double(frames),
            peakInferenceMilliseconds: peakMilliseconds
        )
        frames = 0
        totalMilliseconds = 0
        peakMilliseconds = 0
        windowStart = now
        return stats
    }
}
