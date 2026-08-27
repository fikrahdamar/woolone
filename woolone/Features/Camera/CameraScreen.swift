//
//  CameraScreen.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import SwiftUI

struct CameraScreen: View {
    @State private var viewModel = CameraViewModel()

    var body: some View {
        ZStack(alignment: .topLeading) {
            CameraPreviewView(camera: viewModel.camera)
                .ignoresSafeArea()
            PoseOverlayView(
                joints: viewModel.overlayJoints,
                imageSize: viewModel.pose?.imageSize ?? .zero
            )
                .ignoresSafeArea()
            CaptureHUDView(
                stats: viewModel.stats,
                poseStats: viewModel.poseStats,
                pose: viewModel.pose,
                weakJoints: viewModel.weakJointsText,
                camera: viewModel.cameraText,
                status: viewModel.statusText
            )
            .padding()
        }
        // top right, never the bottom — the feet live down there and the ankle is the joint most at risk
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 8) {
                Button("flip") {
                    Task { await viewModel.flipCamera() }
                }
                Button(viewModel.showsAllJoints ? "leg" : "all") {
                    viewModel.toggleAllJoints()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding()
        }
        .task { await viewModel.start() }
    }
}

#Preview {
    CameraScreen()
}
