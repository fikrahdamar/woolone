//
//  CaptureStats.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import Foundation

/// One second of frame-pump health, measured on the capture queue and read by the HUD.
nonisolated struct CaptureStats: Sendable, Equatable {
    let framesPerSecond: Double
    let deliveredFrames: Int
    let droppedFrames: Int
    // proof for the eye, not the compiler: nonisolated alone does not guarantee off-main under approachable concurrency
    let delegateOnMainThread: Bool

    static let idle = CaptureStats(
        framesPerSecond: 0,
        deliveredFrames: 0,
        droppedFrames: 0,
        delegateOnMainThread: false
    )
}
