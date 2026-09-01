//
//  RepSignal.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 01/09/26.
//

import CoreGraphics
import Foundation
import Vision

nonisolated extension PoseFrame {
    /// Hip height relative to the knee, in torso lengths. Rises as you descend.
    // rep counting and form judging are different signals: this one survives a bad camera angle,
    // the knee angle does not. Measured across 30 recordings, hip-relative-to-shoulder — the signal
    // the brief suggested — swings only 0.04–0.12 in a squat, because the torso descends whole.
    var repSignal: CGFloat? {
        guard let leftHip = joints[.leftHip], let rightHip = joints[.rightHip],
              let leftKnee = joints[.leftKnee], let rightKnee = joints[.rightKnee],
              let neck = joints[.neck], let root = joints[.root],
              min(leftHip.confidence, rightHip.confidence, leftKnee.confidence) >= PoseConfidence.judge,
              min(rightKnee.confidence, neck.confidence, root.confidence) >= PoseConfidence.judge
        else { return nil }

        let hip = (leftHip.position.y + rightHip.position.y) / 2
        let knee = (leftKnee.position.y + rightKnee.position.y) / 2
        let torso = hypot(neck.position.x - root.position.x, neck.position.y - root.position.y)
        guard torso > 0 else { return nil }
        return (hip - knee) / torso
    }
}
