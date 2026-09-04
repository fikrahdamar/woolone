//
//  CameraScreen.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import SwiftUI

struct CameraScreen: View {
    @State private var viewModel = CameraViewModel()
    @State private var showsReplay = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let camera = viewModel.camera {
                CameraPreviewView(camera: camera)
                    .ignoresSafeArea()
            }
            PoseOverlayView(
                joints: viewModel.overlayJoints,
                chains: viewModel.overlayChains,
                imageSize: viewModel.pose?.imageSize ?? .zero,
                isFaulted: viewModel.isFaulted
            )
                .ignoresSafeArea()
            // one row, so the layout keeps the panel and the controls apart rather than a magic
            // inset doing it — the panel grew wide enough to sit under the buttons otherwise
            HStack(alignment: .top, spacing: 12) {
                CaptureHUDView(
                    headline: viewModel.headline,
                    summary: viewModel.summaryText,
                    isRecording: viewModel.recording.isRecording,
                    stats: viewModel.stats,
                    poseStats: viewModel.poseStats,
                    pose: viewModel.pose,
                    weakJoints: viewModel.weakJointsText,
                    measurement: viewModel.measurementText,
                    recording: viewModel.recording,
                    camera: viewModel.cameraText,
                    status: viewModel.statusText
                )
                Spacer(minLength: 0)
                // top right, never the bottom — the feet live down there and the ankle is the
                // joint most at risk. fixedSize so a long headline never squeezes the controls
                controls.fixedSize()
            }
            .padding()
        }
        .task { await viewModel.start() }
        .fullScreenCover(isPresented: $showsReplay) { ReplayScreen() }
    }

    private var controls: some View {
        // two groups, weighted differently: the two you use during a set are prominent,
        // the three you use standing at the phone are not
        VStack(alignment: .trailing, spacing: 14) {
            VStack(alignment: .trailing, spacing: 8) {
                if viewModel.recording.isRecording {
                    Button("stop", role: .destructive) {
                        Task { await viewModel.stopRecording() }
                    }
                } else {
                    // a menu, not a text field — no keyboard between you and the set
                    Menu("rec") {
                        ForEach(RecordingCondition.allCases, id: \.self) { condition in
                            Button(condition.label) {
                                Task { await viewModel.startRecording(condition) }
                            }
                        }
                    }
                }
                Button {
                    viewModel.toggleCoach()
                } label: {
                    Label("coach", systemImage: viewModel.isCoachOn ? "speaker.wave.2.fill" : "speaker.slash")
                        .labelStyle(.iconOnly)
                }
                .tint(viewModel.isCoachOn ? .green : .secondary)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            VStack(alignment: .trailing, spacing: 6) {
                Button("flip") {
                    Task { await viewModel.flipCamera() }
                }
                .disabled(!viewModel.canFlipCamera)
                Button(viewModel.showsAllJoints ? "leg" : "all") {
                    viewModel.toggleAllJoints()
                }
                // reachable even when the camera failed, the only state the simulator has
                Button("replay") { showsReplay = true }
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .tint(.secondary)
        }
    }
}

#Preview {
    CameraScreen()
}
