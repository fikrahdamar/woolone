//
//  FrameLine.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 30/08/26.
//

import CoreGraphics
import Foundation
import Vision

/// One decoded frame line: the recording clock, and the pose exactly as Vision returned it.
nonisolated struct RecordedFrame: Sendable {
    let seconds: Double
    let pose: PoseFrame
}

/// The recording contract: what FrameLogger writes and ReplaySource reads, so the round trip is one file.
nonisolated enum FrameLine {
    /// Every joint, ungated — the sub-0.5 confidences are the dataset #22's exit threshold comes from.
    static func encode(_ pose: PoseFrame, at seconds: Double) -> String {
        var line = ""
        line.reserveCapacity(1024)
        line += "{\"kind\":\"frame\",\"t\":" + text(seconds, scale: 1000)
        line += ",\"obs\":" + text(Double(pose.observationConfidence), scale: 1000)
        line += ",\"ms\":" + text(pose.inferenceMilliseconds, scale: 100)
        line += ",\"j\":{"

        var isFirst = true
        // sorted, so the same pose always writes the same bytes — dictionary order is not stable across runs
        for joint in pose.allJoints.sorted(by: { $0.name.rawValue < $1.name.rawValue }) {
            // a NaN would print as `nan` and cost the whole line; a dropped joint is a case the chains already handle
            guard joint.position.x.isFinite, joint.position.y.isFinite, joint.confidence.isFinite else {
                continue
            }
            if !isFirst { line += "," }
            isFirst = false
            line += "\"\(joint.name.rawValue)\":["
            line += text(Double(joint.position.x), scale: 100) + ","
            line += text(Double(joint.position.y), scale: 100) + ","
            line += text(Double(joint.confidence), scale: 1000) + "]"
        }

        line += "}}"
        return line
    }

    /// nil rather than throwing: a half-written last line loses one frame, not the recording.
    static func decode(_ line: String, header: RecordingHeader) -> RecordedFrame? {
        guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
              object["kind"] as? String == "frame",
              let seconds = object["t"] as? Double,
              let raw = object["j"] as? [String: [Double]] else { return nil }

        var joints: [HumanBodyPoseObservation.JointName: Joint] = [:]
        joints.reserveCapacity(raw.count)
        for (name, values) in raw {
            guard values.count == 3,
                  let jointName = HumanBodyPoseObservation.JointName(rawValue: name) else { continue }
            joints[jointName] = Joint(
                name: jointName,
                position: CGPoint(x: values[0], y: values[1]),
                confidence: Float(values[2])
            )
        }

        return RecordedFrame(
            seconds: seconds,
            pose: PoseFrame(
                joints: joints,
                observationConfidence: Float(object["obs"] as? Double ?? 0),
                imageSize: header.imageSize,
                orientation: header.imageOrientation,
                supportedJointCount: header.supportedJointCount,
                inferenceMilliseconds: object["ms"] as? Double ?? 0
            )
        )
    }

    // String(format:) bridges through NSString 60 times a frame; rounding and printing shortest-round-trip does not
    private static func text(_ value: Double, scale: Double) -> String {
        String((value * scale).rounded() / scale)
    }
}
