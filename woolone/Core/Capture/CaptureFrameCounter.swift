//
//  CaptureFrameCounter.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import AVFoundation
import Foundation

/// Counts delivered and dropped frames on the capture queue and publishes one CaptureStats per second.
// @unchecked: every stored property is touched only from the serial capture queue the delegate is set on
nonisolated final class CaptureFrameCounter: NSObject, @unchecked Sendable {
    private static let windowNanoseconds: UInt64 = 1_000_000_000

    private let continuation: AsyncStream<CaptureStats>.Continuation
    private var deliveredFrames = 0
    private var droppedFrames = 0
    private var windowFrames = 0
    private var windowStart = DispatchTime.now().uptimeNanoseconds

    init(continuation: AsyncStream<CaptureStats>.Continuation) {
        self.continuation = continuation
    }

    deinit {
        continuation.finish()
    }

    private func publishIfWindowElapsed() {
        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = now &- windowStart
        guard elapsed >= Self.windowNanoseconds else { return }

        let fps = Double(windowFrames) * Double(Self.windowNanoseconds) / Double(elapsed)
        let onMainThread = pthread_main_np() != 0
        windowFrames = 0
        windowStart = now

        continuation.yield(
            CaptureStats(
                framesPerSecond: fps,
                deliveredFrames: deliveredFrames,
                droppedFrames: droppedFrames,
                delegateOnMainThread: onMainThread
            )
        )
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

// nonisolated on the extension too: default MainActor isolation would otherwise pin the callback to main
nonisolated extension CaptureFrameCounter: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        deliveredFrames += 1
        windowFrames += 1
        publishIfWindowElapsed()
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        droppedFrames += 1
    }
}
