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
    /// Newest frame wins: a detector slower than 30fps drops frames instead of falling behind the body.
    let frames: AsyncStream<CapturedFrame>

    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.woolone.capture.session")
    private let frameQueue = DispatchQueue(label: "com.woolone.capture.frames", qos: .userInitiated)
    private let frameCounter: CaptureFrameCounter
    // every one of these is touched on sessionQueue only
    private var facing: CameraFacing
    private var deviceInput: AVCaptureDeviceInput?
    private var isConfigured = false

    init(facing: CameraFacing = .back) {
        self.facing = facing
        let (statsStream, statsContinuation) = AsyncStream.makeStream(
            of: CaptureStats.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        let (frameStream, frameContinuation) = AsyncStream.makeStream(
            of: CapturedFrame.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        stats = statsStream
        frames = frameStream
        frameCounter = CaptureFrameCounter(
            stats: statsContinuation,
            frames: frameContinuation
        )
    }

    // configuration and startRunning() block for hundreds of milliseconds — the dispatch is what keeps them off main
    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async {
                do {
                    try self.configureIfNeeded()
                    self.configureOutputConnection()
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

    /// Swaps the camera in place — the frame and pose streams keep running across it.
    func use(_ facing: CameraFacing) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async {
                do {
                    try self.reconfigure(for: facing)
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

        let device = try camera(for: facing)
        let input = try AVCaptureDeviceInput(device: device)
        guard captureSession.canAddInput(input) else { throw Failure.cannotAddInput }
        captureSession.addInput(input)
        deviceInput = input

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        // without this, late frames queue up and the overlay drifts seconds behind the body while every number still looks plausible
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(frameCounter, queue: frameQueue)

        guard captureSession.canAddOutput(videoOutput) else { throw Failure.cannotAddOutput }
        captureSession.addOutput(videoOutput)

        pinFrameRate(on: device)
        isConfigured = true
    }

    private func reconfigure(for facing: CameraFacing) throws {
        guard isConfigured else {
            self.facing = facing
            return
        }
        guard facing != self.facing else { return }

        let device = try camera(for: facing)
        let input = try AVCaptureDeviceInput(device: device)

        captureSession.beginConfiguration()
        if let deviceInput {
            captureSession.removeInput(deviceInput)
        }
        guard captureSession.canAddInput(input) else {
            // put the working camera back rather than leaving the session with no input at all
            if let deviceInput {
                captureSession.addInput(deviceInput)
            }
            captureSession.commitConfiguration()
            throw Failure.cannotAddInput
        }
        captureSession.addInput(input)
        deviceInput = input
        self.facing = facing
        captureSession.commitConfiguration()

        // after the commit, never before: swapping the input rebuilds the connection and discards
        // anything set on the old one — that is what left the front camera landscape
        configureOutputConnection()
        pinFrameRate(on: device)
    }

    private func camera(for facing: CameraFacing) throws -> AVCaptureDevice {
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: facing == .back ? .back : .front
        ) else {
            throw Failure.noCamera
        }
        return device
    }

    // the buffer is left exactly as the sensor produced it — the front camera refuses a rotated
    // connection after an input swap, so orientation is Vision's problem, not AVFoundation's
    private func configureOutputConnection() {
        guard let connection = videoOutput.connection(with: .video),
              connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = false
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
