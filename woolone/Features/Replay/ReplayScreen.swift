//
//  ReplayScreen.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 31/08/26.
//

import SwiftUI

/// The same overlay and HUD as the camera, fed from a file. No AVFoundation, so it runs on the simulator.
struct ReplayScreen: View {
    @State private var recordings = Recording.bundled()
    @State private var viewModel: CameraViewModel?
    @State private var failure: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let viewModel {
                player(viewModel)
            } else {
                picker
            }
        }
    }

    // MARK: - Player

    private func player(_ model: CameraViewModel) -> some View {
        ZStack(alignment: .topLeading) {
            PoseOverlayView(
                joints: model.overlayJoints,
                chains: model.overlayChains,
                imageSize: model.pose?.imageSize ?? .zero
            )
            .ignoresSafeArea()
            CaptureHUDView(
                stats: .idle,
                poseStats: model.poseStats,
                pose: model.pose,
                kneeAngle: model.kneeAngleText,
                hasReading: model.kneeAngle != nil,
                weakJoints: model.weakJointsText,
                setup: model.setupText,
                isArmed: model.isArmed,
                measurement: model.measurementText,
                recording: .idle,
                // the recording names itself, which is the criterion's weaker half
                camera: "replay · \(model.replayName ?? "unnamed")",
                status: model.replay.isPlaying ? "playing" : "paused"
            )
            .padding()
        }
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 8) {
                Button("close") { close() }
                Button(model.showsAllJoints ? "leg" : "all") { model.toggleAllJoints() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding()
        }
        .safeAreaInset(edge: .bottom) { transport(model) }
    }

    private func transport(_ model: CameraViewModel) -> some View {
        VStack(spacing: 10) {
            Slider(
                value: Binding(
                    get: { Double(model.replay.index) },
                    set: { value in Task { await model.seek(to: Int(value.rounded())) } }
                ),
                in: 0...Double(max(1, model.replay.count - 1)),
                step: 1
            )
            HStack(spacing: 24) {
                // stepping one frame is what you reach for when a single number looks wrong
                Button { Task { await model.step(by: -1) } } label: {
                    Image(systemName: "backward.frame.fill")
                }
                Button {
                    Task {
                        if model.replay.isPlaying { await model.pause() } else { await model.play() }
                    }
                } label: {
                    Image(systemName: model.replay.isPlaying ? "pause.fill" : "play.fill")
                }
                Button { Task { await model.step(by: 1) } } label: {
                    Image(systemName: "forward.frame.fill")
                }
                Spacer()
                Text(
                    String(
                        format: "%d/%d · %.2fs",
                        model.replay.index + 1,
                        model.replay.count,
                        model.replay.seconds
                    )
                )
                .font(.system(size: 11, design: .monospaced))
            }
        }
        .padding()
        .background(.thinMaterial)
    }

    // MARK: - Picker

    private var picker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("replay")
                .font(.title2.weight(.semibold))
                .padding(.horizontal)
                .padding(.top)

            if recordings.isEmpty {
                Text("no .ndjson in the bundle — check Resources/Recordings is in Copy Bundle Resources")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.orange)
                    .padding(.horizontal)
            }

            List(recordings) { recording in
                Button { open(recording) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(recording.header.condition)
                            .font(.headline)
                        Text(recording.name)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(headline(recording))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)

            if let failure {
                Text(failure)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
    }

    private func headline(_ recording: Recording) -> String {
        let header = recording.header
        return "\(header.camera) · \(Int(header.imageWidth))x\(Int(header.imageHeight))"
            + " · \(header.captureFps) fps · \(header.orientation)"
    }

    // MARK: - Actions

    private func open(_ recording: Recording) {
        do {
            let model = try CameraViewModel(replaying: recording)
            failure = nil
            viewModel = model
            Task { await model.start() }
        } catch {
            failure = "\(error)"
        }
    }

    private func close() {
        let model = viewModel
        viewModel = nil
        Task { await model?.stop() }
    }
}

#Preview {
    ReplayScreen()
}
