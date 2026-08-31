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

    /// The reverse of `label` — a recording header names the orientation it was shot under in words.
    init?(label: String) {
        switch label {
        case "up": self = .up
        case "down": self = .down
        case "left": self = .left
        case "right": self = .right
        case "upMirrored": self = .upMirrored
        case "downMirrored": self = .downMirrored
        case "leftMirrored": self = .leftMirrored
        case "rightMirrored": self = .rightMirrored
        default: return nil
        }
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
