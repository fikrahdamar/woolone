//
//  CaptureHUDView.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import SwiftUI

/// Two lines you can read from a phone stand, and everything else behind a tap.
struct CaptureHUDView: View {
    let headline: CameraViewModel.Headline
    let summary: String
    let isRecording: Bool
    /// Spike only — both knee angles side by side. Delete with the branch.
    var comparison3D: String? = nil

    let stats: CaptureStats
    let poseStats: PoseStats
    let pose: PoseFrame?
    let weakJoints: String?
    let measurement: String
    let recording: RecordingStats
    let camera: String
    let status: String

    // collapsed by default: the diagnostics are for standing at the phone, not for squatting
    @State private var showsDiagnostics = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // one line, and it is whatever matters most right now — guidance, or the last verdict
            Text(headline.text)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(colour(headline.tone))
                .contentTransition(.opacity)

            HStack(spacing: 10) {
                if isRecording {
                    Circle().fill(.red).frame(width: 9, height: 9)
                }
                Text(summary)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
            }

            if let comparison3D {
                Text(comparison3D)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(comparison3D.hasPrefix("3D FAILED") ? .red : .cyan)
            }

            if showsDiagnostics {
                diagnostics
                    .font(.system(size: 11, design: .monospaced))
                    .padding(.top, 6)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: .rect(cornerRadius: 14))
        .contentShape(.rect)
        .onTapGesture { showsDiagnostics.toggle() }
        .animation(.easeInOut(duration: 0.15), value: showsDiagnostics)
    }

    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rateLine)
            Text(inferenceLine)
            Text(measurement)
            Text(jointLine)
                .foregroundStyle(pose?.hasPerson == true ? .green : .orange)
            if let weakJoints {
                Text(weakJoints).foregroundStyle(.yellow)
            }
            if let recordingLine {
                Text(recordingLine).foregroundStyle(recording.writeFailures > 0 ? .red : .secondary)
            }
            Text(bufferLine)
                .foregroundStyle(isBufferLandscape ? .red : .primary)
            Text("frames \(stats.deliveredFrames) · dropped \(stats.droppedFrames)")
            if stats.delegateOnMainThread {
                Text("delegate ON MAIN QUEUE").foregroundStyle(.red)
            }
            Text(camera).foregroundStyle(.secondary)
            Text(status).foregroundStyle(.secondary)
        }
    }

    // the tone comes from the ViewModel; the View only decides what each tone looks like
    private func colour(_ tone: CameraViewModel.Headline.Tone) -> Color {
        switch tone {
        case .waiting: .orange
        case .ready: .green
        case .good: .green
        case .bad: .red
        }
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
    VStack(alignment: .leading, spacing: 20) {
        ForEach(
            [
                CameraViewModel.Headline(text: "square up — counting only", tone: .waiting),
                CameraViewModel.Headline(text: "ready", tone: .ready),
                CameraViewModel.Headline(text: "depth 118° · needs under 86° — go deeper", tone: .bad)
            ],
            id: \.text
        ) { headline in
            CaptureHUDView(
                headline: headline,
                summary: "3 reps  ·  knee 118°",
                isRecording: headline.tone == .bad,
                stats: CaptureStats(
                    framesPerSecond: 29.9,
                    deliveredFrames: 897,
                    droppedFrames: 0,
                    delegateOnMainThread: false
                ),
                poseStats: PoseStats(
                    framesPerSecond: 30,
                    meanInferenceMilliseconds: 22.4,
                    peakInferenceMilliseconds: 28.9
                ),
                pose: nil,
                weakJoints: "left ankle 0.41",
                measurement: "smooth 116.9° · last 84° · 2.1s · square 0.12",
                recording: .idle,
                camera: "camera front",
                status: "running"
            )
        }
    }
    .padding()
    .background(.black)
}
