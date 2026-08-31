//
//  FrameLogger.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 30/08/26.
//

import Foundation

/// One NDJSON line per frame, buffered — an actor, so a file write never lands on the capture queue.
actor FrameLogger {
    /// One second of frames: the pump pays for a write at the cadence the HUD already updates at.
    static let flushEvery = 30

    nonisolated let stats: AsyncStream<RecordingStats>

    private let statsContinuation: AsyncStream<RecordingStats>.Continuation
    private var handle: FileHandle?
    private var url: URL?
    private var condition: RecordingCondition?
    private var buffer = Data()
    private var startedAt: Double = 0
    private var framesWritten = 0
    private var costSeconds: Double = 0
    private var writeFailures = 0

    init() {
        let (stream, continuation) = AsyncStream.makeStream(
            of: RecordingStats.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        stats = stream
        statsContinuation = continuation
    }

    deinit {
        try? handle?.close()
        statsContinuation.finish()
    }

    var isRecording: Bool { handle != nil }

    /// Needs a real frame: image size and orientation are recorded once in the header, never per line.
    @discardableResult
    func start(_ condition: RecordingCondition, camera: CameraFacing, sample: PoseFrame) throws -> URL {
        guard handle == nil else { throw Failure.alreadyRecording }

        let destination = Self.documents.appendingPathComponent(Self.filename(condition))
        let header = try RecordingHeader(
            condition: condition,
            camera: camera,
            startedAt: Date(),
            sample: sample,
            captureFps: Int(CameraSession.targetFrameRate)
        ).line()

        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
            throw Failure.cannotCreateFile(destination.lastPathComponent)
        }
        let opened = try FileHandle(forWritingTo: destination)
        try opened.write(contentsOf: Data((header + "\n").utf8))

        handle = opened
        url = destination
        self.condition = condition
        buffer = Data()
        buffer.reserveCapacity(Self.flushEvery * 1024)
        startedAt = Self.now()
        framesWritten = 0
        costSeconds = 0
        writeFailures = 0
        emit()
        return destination
    }

    func record(_ pose: PoseFrame) {
        guard handle != nil else { return }
        let began = Self.now()

        buffer.append(Data((FrameLine.encode(pose, at: began - startedAt) + "\n").utf8))
        framesWritten += 1
        let isFlushFrame = framesWritten % Self.flushEvery == 0
        if isFlushFrame { flush() }

        // the flush sits inside the measurement: what the pump pays is the encode plus, once a second, the write
        costSeconds += Self.now() - began
        if isFlushFrame { emit() }
    }

    @discardableResult
    func stop() -> URL? {
        guard let handle else { return nil }
        flush()
        try? handle.close()
        self.handle = nil

        // condition and count survive the stop so the HUD can still say what was written
        let finished = url
        url = nil
        emit()
        return finished
    }

    // MARK: - Writing

    private func flush() {
        guard let handle, !buffer.isEmpty else { return }
        do {
            try handle.write(contentsOf: buffer)
            buffer.removeAll(keepingCapacity: true)
        } catch {
            // a swallowed write error is a recording that looks fine and is short; the HUD says so instead
            writeFailures += 1
        }
    }

    private func emit() {
        statsContinuation.yield(
            RecordingStats(
                isRecording: handle != nil,
                condition: condition?.label,
                framesWritten: framesWritten,
                seconds: framesWritten == 0 ? 0 : Self.now() - startedAt,
                meanCostMilliseconds: framesWritten == 0
                    ? 0
                    : costSeconds / Double(framesWritten) * 1000,
                writeFailures: writeFailures
            )
        )
    }

    // MARK: - Files

    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static func filename(_ condition: RecordingCondition) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "\(condition.rawValue)-\(formatter.string(from: Date())).ndjson"
    }

    private static func now() -> Double {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
    }

    // MARK: - Failure

    enum Failure: Error, CustomStringConvertible {
        case alreadyRecording
        case cannotCreateFile(String)

        var description: String {
            switch self {
            case .alreadyRecording: "already recording"
            case .cannotCreateFile(let name): "could not create \(name) in Documents"
            }
        }
    }
}
