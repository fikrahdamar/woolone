//
//  CaptureHUDView.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import SwiftUI

struct CaptureHUDView: View {
    let stats: CaptureStats
    let poseStats: PoseStats
    let pose: PoseFrame?
    let kneeAngle: String
    let hasReading: Bool
    let weakJoints: String?
    let setup: String
    let isArmed: Bool
    let recording: RecordingStats
    let camera: String
    let status: String

    // small enough to film past; tap collapses it to one line
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(kneeAngle)
                .font(.system(size: 22, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(hasReading ? Color.primary : Color.orange)
            // above the rate line and never collapsed: this is the one thing you act on before a set
            Text(setup)
                .foregroundStyle(isArmed ? Color.green : Color.orange)
            Text(rateLine)
            // stays visible collapsed: a set recorded to a file nobody knew was open is 20 sets, not 19
            if let recordingLine {
                Text(recordingLine)
                    .foregroundStyle(recordingColour)
            }
            if isExpanded {
                Text(inferenceLine)
                Text(jointLine)
                    .foregroundStyle(pose?.hasPerson == true ? .green : .orange)
                if let weakJoints {
                    Text(weakJoints)
                        .foregroundStyle(.yellow)
                }
                Text(bufferLine)
                    .foregroundStyle(isBufferLandscape ? .red : .primary)
                Text("frames \(stats.deliveredFrames) · dropped \(stats.droppedFrames)")
                if stats.delegateOnMainThread {
                    Text("delegate ON MAIN QUEUE")
                        .foregroundStyle(.red)
                }
                Text(camera)
                    .foregroundStyle(.secondary)
                Text(status)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(8)
        .background(.thinMaterial, in: .rect(cornerRadius: 8))
        .opacity(0.9)
        .contentShape(.rect)
        .onTapGesture { isExpanded.toggle() }
    }

    private var rateLine: String {
        String(
            format: "%.0f cap · %.0f pose fps · %.1f ms",
            stats.framesPerSecond,
            poseStats.framesPerSecond,
            poseStats.meanInferenceMilliseconds
        )
    }

    private var recordingLine: String? {
        guard recording.isRecording || recording.framesWritten > 0 else { return nil }
        let line = (recording.isRecording ? "rec " : "saved ")
            + (recording.condition ?? "recording")
            + String(
                format: " · %d frames · %.1fs · %.2f ms",
                recording.framesWritten,
                recording.seconds,
                recording.meanCostMilliseconds
            )
        guard recording.writeFailures > 0 else { return line }
        return line + " · \(recording.writeFailures) WRITES FAILED"
    }

    private var recordingColour: Color {
        recording.isRecording || recording.writeFailures > 0 ? .red : .secondary
    }

    private var inferenceLine: String {
        String(
            format: "inference %.1f mean · %.1f peak ms",
            poseStats.meanInferenceMilliseconds,
            poseStats.peakInferenceMilliseconds
        )
    }

    private var jointLine: String {
        guard let pose else { return "no pose yet" }
        return "\(pose.drawableJointCount)/\(pose.supportedJointCount) joints"
            + String(format: " · observation %.2f", pose.observationConfidence)
    }

    // a landscape buffer under a portrait preview transposes every joint, and nothing else says so
    private var bufferLine: String {
        guard let pose, pose.imageSize != .zero else { return "buffer —" }
        let size = "image \(Int(pose.imageSize.width))x\(Int(pose.imageSize.height))"
            + " · \(pose.orientation.label)"
        return isBufferLandscape ? "\(size) LANDSCAPE — orientation wrong" : size
    }

    private var isBufferLandscape: Bool {
        guard let pose else { return false }
        return pose.imageSize.width > pose.imageSize.height
    }
}

#Preview {
    CaptureHUDView(
        stats: CaptureStats(
            framesPerSecond: 29.9,
            deliveredFrames: 897,
            droppedFrames: 41,
            delegateOnMainThread: false
        ),
        poseStats: PoseStats(
            framesPerSecond: 24.2,
            meanInferenceMilliseconds: 31.4,
            peakInferenceMilliseconds: 48.9
        ),
        pose: nil,
        kneeAngle: "knee 118.4°",
        hasReading: true,
        weakJoints: "left ankle 0.41 · right knee 0.28",
        setup: "turn square to the phone — 0.28, needs 0.15",
        isArmed: false,
        recording: RecordingStats(
            isRecording: true,
            condition: "off axis",
            framesWritten: 412,
            seconds: 13.7,
            meanCostMilliseconds: 0.31,
            writeFailures: 0
        ),
        camera: "camera back",
        status: "running"
    )
}
