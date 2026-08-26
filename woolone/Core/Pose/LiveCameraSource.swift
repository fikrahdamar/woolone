//
//  LiveCameraSource.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import Foundation

/// Pumps camera frames through the detector. The pump runs here, never on the capture queue.
actor LiveCameraSource: PoseSource {
    nonisolated let poseFrames: AsyncStream<PoseFrame>
    nonisolated let poseStats: AsyncStream<PoseStats>

    private let camera: CameraSession
    private let detector = PoseDetector()
    private let frameContinuation: AsyncStream<PoseFrame>.Continuation
    private let statsContinuation: AsyncStream<PoseStats>.Continuation
    private var pumpTask: Task<Void, Never>?
    private var facing: CameraFacing

    init(camera: CameraSession, facing: CameraFacing = .back) {
        self.camera = camera
        self.facing = facing
        let (frames, frameContinuation) = AsyncStream.makeStream(
            of: PoseFrame.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        let (stats, statsContinuation) = AsyncStream.makeStream(
            of: PoseStats.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        poseFrames = frames
        poseStats = stats
        self.frameContinuation = frameContinuation
        self.statsContinuation = statsContinuation
    }

    deinit {
        pumpTask?.cancel()
        frameContinuation.finish()
        statsContinuation.finish()
    }

    func start() async throws {
        try await camera.start()
        await detector.use(facing.imageOrientation)
        startPump()
    }

    func use(_ facing: CameraFacing) async throws {
        try await camera.use(facing)
        await detector.use(facing.imageOrientation)
        self.facing = facing
    }

    func stop() async {
        pumpTask?.cancel()
        pumpTask = nil
        await camera.stop()
    }

    private func startPump() {
        guard pumpTask == nil else { return }
        pumpTask = Task { [camera, detector, frameContinuation, statsContinuation] in
            var window = PoseRateWindow(start: Self.now())
            var failures = 0
            for await frame in camera.frames {
                if Task.isCancelled { return }
                do {
                    let pose = try await detector.detect(frame)
                    frameContinuation.yield(pose)
                    if let stats = window.record(
                        inferenceMilliseconds: pose.inferenceMilliseconds,
                        at: Self.now()
                    ) {
                        statsContinuation.yield(stats)
                    }
                } catch {
                    failures += 1
                    // off the capture queue, so a throttled print is affordable here
                    if failures % 30 == 1 {
                        print("[pose] detect failed (\(failures)): \(error)")
                    }
                }
            }
        }
    }

    private static func now() -> Double {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
    }
}
