//
//  Angle.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 27/08/26.
//

import CoreGraphics
import Foundation

/// Interior angle at `vertex`, in degrees. Pixels only — normalized coordinates give a wrong number here.
nonisolated func angle(_ a: CGPoint, _ vertex: CGPoint, _ c: CGPoint) -> CGFloat? {
    let first = CGVector(dx: a.x - vertex.x, dy: a.y - vertex.y)
    let second = CGVector(dx: c.x - vertex.x, dy: c.y - vertex.y)

    let lengths = hypot(first.dx, first.dy) * hypot(second.dx, second.dy)
    // a joint landing exactly on the vertex has no direction, and dividing by it produces NaN
    guard lengths > 0 else { return nil }

    let dot = first.dx * second.dx + first.dy * second.dy
    // float error pushes the ratio past 1.0, acos returns NaN, and NaN never leaves the EMA again
    let cosine = min(1, max(-1, dot / lengths))

    return acos(cosine) * 180 / .pi
}
