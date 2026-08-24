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
            CaptureHUDView(stats: viewModel.stats, status: viewModel.statusText)
                .padding()
        }
        .task { await viewModel.start() }
    }
}

#Preview {
    CameraScreen()
}
