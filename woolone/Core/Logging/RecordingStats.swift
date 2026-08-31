//
//  RecordingStats.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 30/08/26.
//

import Foundation

/// What recording is costing the pump, on the HUD — you cannot read the console while squatting.
nonisolated struct RecordingStats: Sendable, Equatable {
    let isRecording: Bool
    let condition: String?
    let framesWritten: Int
    let seconds: Double
    let meanCostMilliseconds: Double
    let writeFailures: Int

    static let idle = RecordingStats(
        isRecording: false,
        condition: nil,
        framesWritten: 0,
        seconds: 0,
        meanCostMilliseconds: 0,
        writeFailures: 0
    )
}
