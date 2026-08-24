//
//  CameraSession.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import AVFoundation
import Foundation

/// AVCaptureSession wrapper: BGRA frames at 30fps, delivered to a serial queue that is never main.
// @unchecked: AVCaptureSession is not Sendable, so configuration is confined to sessionQueue instead
nonisolated final class CameraSession: @unchecked Sendable {
    static let targetFrameRate: Int32 = 30

    /// Handed to the preview layer by the UI layer; nothing else should touch it.
    let captureSession = AVCaptureSession()
    let stats: AsyncStream<CaptureStats>

    private let position: AVCaptureDevice.Position
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.woolone.capture.session")
    private let frameQueue = DispatchQueue(label: "com.woolone.capture.frames", qos: .userInitiated)
    private let frameCounter: CaptureFrameCounter
    private var isConfigured = false

    init(position: AVCaptureDevice.Position = .back) {
        self.position = position
        let (stream, continuation) = AsyncStream.makeStream(
            of: CaptureStats.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        stats = stream
        frameCounter = CaptureFrameCounter(continuation: continuation)
    }

    // configuration and startRunning() block for hundreds of milliseconds — the dispatch is what keeps them off main
    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async {
                do {
                    try self.configureIfNeeded()
                    if !self.captureSession.isRunning {
                        self.captureSession.startRunning()
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                if self.captureSession.isRunning {
                    self.captureSession.stopRunning()
                }
                continuation.resume()
            }
        }
    }

    // MARK: - Configuration

    private func configureIfNeeded() throws {
        guard !isConfigured else { return }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        captureSession.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position
        ) else {
            throw Failure.noCamera
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard captureSession.canAddInput(input) else { throw Failure.cannotAddInput }
        captureSession.addInput(input)

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        // without this, late frames queue up and the overlay drifts seconds behind the body while every number still looks plausible
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(frameCounter, queue: frameQueue)

        guard captureSession.canAddOutput(videoOutput) else { throw Failure.cannotAddOutput }
        captureSession.addOutput(videoOutput)

        if let connection = videoOutput.connection(with: .video),
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }

        pinFrameRate(on: device)
        isConfigured = true
    }

    // the pipeline is budgeted at 33ms a frame; an unpinned format is free to run at 60 and halve that
    private func pinFrameRate(on device: AVCaptureDevice) {
        let duration = CMTime(value: 1, timescale: Self.targetFrameRate)
        let rate = Double(Self.targetFrameRate)
        guard device.activeFormat.videoSupportedFrameRateRanges.contains(
            where: { $0.minFrameRate <= rate && rate <= $0.maxFrameRate }
        ) else { return }

        do {
            try device.lockForConfiguration()
        } catch {
            return
        }
        defer { device.unlockForConfiguration() }
        device.activeVideoMinFrameDuration = duration
        device.activeVideoMaxFrameDuration = duration
    }

    // MARK: - Failure

    enum Failure: Error, CustomStringConvertible {
        case noCamera
        case cannotAddInput
        case cannotAddOutput

        var description: String {
            switch self {
            case .noCamera: "no wide-angle camera on this device"
            case .cannotAddInput: "capture session refused the camera input"
            case .cannotAddOutput: "capture session refused the video output"
            }
        }
    }
}
