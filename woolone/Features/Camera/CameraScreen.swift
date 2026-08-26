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
                joints: viewModel.legJoints,
                imageSize: viewModel.pose?.imageSize ?? .zero
            )
                .ignoresSafeArea()
            CaptureHUDView(
                stats: viewModel.stats,
                poseStats: viewModel.poseStats,
                pose: viewModel.pose,
                camera: viewModel.cameraText,
                status: viewModel.statusText
            )
            .padding()
        }
        .overlay(alignment: .bottom) {
            Button("flip camera") {
                Task { await viewModel.flipCamera() }
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 32)
        }
        .task { await viewModel.start() }
    }
}

#Preview {
    CameraScreen()
}
