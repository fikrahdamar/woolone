//
//  CapturedFrame.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import CoreMedia
import CoreVideo
import Foundation

/// One camera frame leaving the capture queue, with the size Vision must be normalized against.
// @unchecked: CVPixelBuffer is not Sendable, and nothing here writes to it — the capture queue
// hands the buffer over and never touches it again, the detector only reads
nonisolated struct CapturedFrame: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
    // buffer dimensions, not the session preset — the connection rotation has already been applied
    let size: CGSize
    let presentationTime: CMTime

    init(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        self.pixelBuffer = pixelBuffer
        self.size = CGSize(
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        )
        self.presentationTime = presentationTime
    }
}
