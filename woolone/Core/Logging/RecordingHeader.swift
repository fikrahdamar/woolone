//
//  RecordingHeader.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 30/08/26.
//

import CoreGraphics
import Foundation
import ImageIO

/// Line one of a recording: the setup the frames were measured under, and the gates in force at the time.
nonisolated struct RecordingHeader: Codable, Sendable, Equatable {
    static let currentVersion = 1

    let kind: String
    let version: Int
    let condition: String
    let startedAt: String
    let camera: String
    let orientation: String
    let imageWidth: Double
    let imageHeight: Double
    let supportedJointCount: Int
    let captureFps: Int
    let gates: Gates

    // recorded, never applied — #17 re-derives against a different draw gate without another afternoon of squats
    struct Gates: Codable, Sendable, Equatable {
        let observation: Float
        let draw: Float
        let judge: Float

        static let current = Gates(
            observation: PoseConfidence.observation,
            draw: PoseConfidence.draw,
            judge: PoseConfidence.judge
        )
    }

    init(
        condition: RecordingCondition,
        camera: CameraFacing,
        startedAt: Date,
        sample: PoseFrame,
        captureFps: Int
    ) {
        kind = "header"
        version = Self.currentVersion
        self.condition = condition.rawValue
        self.startedAt = ISO8601DateFormatter().string(from: startedAt)
        self.camera = camera.label
        orientation = sample.orientation.label
        imageWidth = sample.imageSize.width
        imageHeight = sample.imageSize.height
        supportedJointCount = sample.supportedJointCount
        self.captureFps = captureFps
        gates = .current
    }

    var imageSize: CGSize { CGSize(width: imageWidth, height: imageHeight) }

    /// Falls back to `.up` rather than throwing — a header naming an orientation this build does not know
    /// still describes a readable recording.
    var imageOrientation: CGImagePropertyOrientation {
        CGImagePropertyOrientation(label: orientation) ?? .up
    }

    func line() throws -> String {
        let encoder = JSONEncoder()
        // stable key order, so two headers of the same setup are byte-identical and diffable
        encoder.outputFormatting = .sortedKeys
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }

    static func decode(_ line: String) -> RecordingHeader? {
        try? JSONDecoder().decode(RecordingHeader.self, from: Data(line.utf8))
    }
}
