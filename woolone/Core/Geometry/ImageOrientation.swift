//
//  ImageOrientation.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 25/08/26.
//

import ImageIO

nonisolated extension CGImagePropertyOrientation {
    /// A quarter turn means width and height trade places before any coordinate is scaled.
    var swapsAxes: Bool {
        self == .left || self == .leftMirrored || self == .right || self == .rightMirrored
    }

    var label: String {
        switch self {
        case .up: "up"
        case .down: "down"
        case .left: "left"
        case .right: "right"
        case .upMirrored: "upMirrored"
        case .downMirrored: "downMirrored"
        case .leftMirrored: "leftMirrored"
        case .rightMirrored: "rightMirrored"
        @unknown default: "unknown"
        }
    }
}
