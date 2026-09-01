//
//  PoseFrame+Spread.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 01/09/26.
//

import CoreGraphics
import Foundation
import Vision

nonisolated extension PoseFrame {
    /// Shoulder separation in torso lengths — near zero side-on, because the far shoulder hides behind the near one.
    // named for what it measures, not for what it is used to decide: the threshold lives in SetupGate
    var shoulderSpread: CGFloat? {
        guard let left = joints[.leftShoulder],
              let right = joints[.rightShoulder],
              let neck = joints[.neck],
              let root = joints[.root],
              min(left.confidence, right.confidence, neck.confidence, root.confidence) >= PoseConfidence.judge
        else { return nil }

        // divided by the body, not the frame — the same turn must read the same at 2m and at 4m
        let torso = hypot(neck.position.x - root.position.x, neck.position.y - root.position.y)
        guard torso > 0 else { return nil }
        return abs(left.position.x - right.position.x) / torso
    }

    /// The larger of the two knee angles — a body is standing when its straighter leg is straight.
    var straightestKnee: CGFloat? {
        [kneeAngle(.left), kneeAngle(.right)].compactMap { $0 }.max()
    }
}
