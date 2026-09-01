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
                imageSize: viewModel.pose?.imageSize ?? .zero
            )
                .ignoresSafeArea()
            CaptureHUDView(
                stats: viewModel.stats,
                poseStats: viewModel.poseStats,
                pose: viewModel.pose,
                kneeAngle: viewModel.kneeAngleText,
                hasReading: viewModel.kneeAngle != nil,
                weakJoints: viewModel.weakJointsText,
                setup: viewModel.setupText,
                isArmed: viewModel.isArmed,
                measurement: viewModel.measurementText,
                recording: viewModel.recording,
                camera: viewModel.cameraText,
                status: viewModel.statusText
            )
            .padding()
        }
        // top right, never the bottom — the feet live down there and the ankle is the joint most at risk
        .overlay(alignment: .topTrailing) {
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
                Button("flip") {
                    Task { await viewModel.flipCamera() }
                }
                .disabled(!viewModel.canFlipCamera)
                Button(viewModel.showsAllJoints ? "leg" : "all") {
                    viewModel.toggleAllJoints()
                }
                // reachable even when the camera failed, which is the only state the simulator has
                Button("replay") { showsReplay = true }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding()
        }
        .task { await viewModel.start() }
        .fullScreenCover(isPresented: $showsReplay) { ReplayScreen() }
    }
}

#Preview {
    CameraScreen()
}
