//
//  CameraFacing.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import ImageIO

/// Which camera, without AVFoundation leaking into the ViewModel or the View.
nonisolated enum CameraFacing: Sendable, Equatable {
    case back
    case front

    // the buffer is never rotated or mirrored, so Vision is told how the sensor sat instead —
    // the front sensor is transposed, not merely turned, and .left costs a vertical flip
    var imageOrientation: CGImagePropertyOrientation { self == .back ? .right : .leftMirrored }

    var flipped: CameraFacing { self == .back ? .front : .back }

    var label: String { self == .back ? "back" : "front" }
}
