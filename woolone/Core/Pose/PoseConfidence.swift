//
//  PoseConfidence.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import Foundation

/// The two gates every joint passes through; below them Vision returns a plausible wrong point, not an error.
nonisolated enum PoseConfidence {
    static let observation: Float = 0.6
    static let draw: Float = 0.5
    static let judge: Float = 0.3
}
