//
//  CameraPreviewView.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import AVFoundation
import SwiftUI

/// SwiftUI wrapper for AVCaptureVideoPreviewLayer; nil camera renders black so previews need no hardware.
struct CameraPreviewView: UIViewRepresentable {
    let camera: CameraSession?

    func makeUIView(context: Context) -> PreviewLayerView {
        let view = PreviewLayerView()
        view.backgroundColor = .black
        view.attach(camera?.captureSession)
        return view
    }

    func updateUIView(_ uiView: PreviewLayerView, context: Context) {
        uiView.attach(camera?.captureSession)
    }

    final class PreviewLayerView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        func attach(_ session: AVCaptureSession?) {
            guard let previewLayer = layer as? AVCaptureVideoPreviewLayer,
                  previewLayer.session !== session else { return }
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
            // the preview connection does not follow the device on its own; portrait is 90
            if let connection = previewLayer.connection,
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
    }
}

#Preview {
    CameraPreviewView(camera: nil)
}
