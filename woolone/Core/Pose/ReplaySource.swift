//
//  ReplaySource.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 31/08/26.
//

import Foundation

/// A recorded session behind the same seam as the camera — the ViewModel cannot tell the two apart.
actor ReplaySource: PoseSource {
    nonisolated let poseFrames: AsyncStream<PoseFrame>
    nonisolated let poseStats: AsyncStream<PoseStats>
    nonisolated let progress: AsyncStream<ReplayProgress>
    nonisolated let recording: Recording

    // decoded up front: scrubbing and stepping are array indices, which streaming decode cannot give
    private nonisolated let frames: [RecordedFrame]
    private let frameContinuation: AsyncStream<PoseFrame>.Continuation
    private let statsContinuation: AsyncStream<PoseStats>.Continuation
    private let progressContinuation: AsyncStream<ReplayProgress>.Continuation
    private var window: PoseRateWindow
    private var playTask: Task<Void, Never>?
    private var cursor = 0

    init(_ recording: Recording) throws {
        self.recording = recording
        frames = try recording.frames()
        window = PoseRateWindow(start: frames.first?.seconds ?? 0)

        let (frameStream, frameContinuation) = AsyncStream.makeStream(
            of: PoseFrame.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        let (statsStream, statsContinuation) = AsyncStream.makeStream(
            of: PoseStats.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        let (progressStream, progressContinuation) = AsyncStream.makeStream(
            of: ReplayProgress.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        poseFrames = frameStream
        poseStats = statsStream
        progress = progressStream
        self.frameContinuation = frameContinuation
        self.statsContinuation = statsContinuation
        self.progressContinuation = progressContinuation
    }

    deinit {
        playTask?.cancel()
        frameContinuation.finish()
        statsContinuation.finish()
        progressContinuation.finish()
    }

    nonisolated var frameCount: Int { frames.count }

    var index: Int { cursor }
    var isPlaying: Bool { playTask != nil }
    var current: PoseFrame? { frames.indices.contains(cursor) ? frames[cursor].pose : nil }

    // MARK: - PoseSource

    func start() async throws {
        emit()
    }

    func stop() async {
        pause()
    }

    // MARK: - Transport

    func play() {
        guard playTask == nil, cursor < frames.count - 1 else { return }
        playTask = Task { [weak self] in await self?.advance() }
        emitProgress()
    }

    func pause() {
        playTask?.cancel()
        playTask = nil
        emitProgress()
    }

    func seek(to index: Int) {
        pause()
        cursor = min(max(0, index), max(0, frames.count - 1))
        // the window measures from the recording's own clock, so a jump backwards has to reset it
        window = PoseRateWindow(start: frames.indices.contains(cursor) ? frames[cursor].seconds : 0)
        emit()
    }

    func step(by delta: Int) {
        seek(to: cursor + delta)
    }

    /// Lets a test wait for playback rather than guess at a sleep.
    func waitForPlayback() async {
        await playTask?.value
    }

    // MARK: - Playback

    // paced by the recording's own timestamps, so a 30fps recording replays at 30fps and the HUD agrees
    private func advance() async {
        while cursor < frames.count - 1 {
            let delay = frames[cursor + 1].seconds - frames[cursor].seconds
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            if Task.isCancelled { break }
            cursor += 1
            emit()
        }
        playTask = nil
        emitProgress()
    }

    private func emit() {
        guard frames.indices.contains(cursor) else { return }
        let frame = frames[cursor]
        frameContinuation.yield(frame.pose)
        if let stats = window.record(
            inferenceMilliseconds: frame.pose.inferenceMilliseconds,
            at: frame.seconds
        ) {
            statsContinuation.yield(stats)
        }
        emitProgress()
    }

    private func emitProgress() {
        progressContinuation.yield(
            ReplayProgress(
                index: cursor,
                count: frames.count,
                seconds: frames.indices.contains(cursor) ? frames[cursor].seconds : 0,
                isPlaying: playTask != nil
            )
        )
    }
}
