//
//  LegSelector.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 25/08/26.
//

import Foundation

/// Sticks to one leg until the other is clearly better — picking per frame makes the dots flip on ±0.01 of noise.
nonisolated struct LegSelector {
    static let switchMargin: Float = 0.1

    enum Side: Sendable, Equatable {
        case left
        case right
    }

    private(set) var side: Side?

    mutating func select(from frame: PoseFrame) -> [Joint] {
        let left = frame.leftLeg
        let right = frame.rightLeg

        guard !left.isEmpty else {
            if !right.isEmpty { side = .right }
            return right
        }
        guard !right.isEmpty else {
            side = .left
            return left
        }

        let leftScore = weakest(left)
        let rightScore = weakest(right)

        switch side {
        case .left:
            guard rightScore > leftScore + Self.switchMargin else { return left }
            side = .right
            return right
        case .right:
            guard leftScore > rightScore + Self.switchMargin else { return right }
            side = .left
            return left
        case nil:
            side = leftScore >= rightScore ? .left : .right
            return side == .left ? left : right
        }
    }

    mutating func reset() {
        side = nil
    }

    // the leg is only as trustworthy as its worst joint
    private func weakest(_ joints: [Joint]) -> Float {
        joints.map(\.confidence).min() ?? 0
    }
}
