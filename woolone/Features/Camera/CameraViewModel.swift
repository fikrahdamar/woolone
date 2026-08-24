//
//  CameraViewModel.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class CameraViewModel {
    enum Status: Equatable {
        case idle
        case starting
        case running
        case denied
        case failed(String)
    }

    let camera = CameraSession()
    private(set) var status: Status = .idle
    private(set) var stats = CaptureStats.idle

    private var statsTask: Task<Void, Never>?

    var statusText: String {
        switch status {
        case .idle: "camera off"
        case .starting: "starting"
        case .running: "running"
        case .denied: "camera access denied — enable it in Settings"
        case .failed(let reason): "failed: \(reason)"
        }
    }

    func start() async {
        guard status != .starting, status != .running else { return }
        // a SwiftUI preview has no camera and must not raise a permission prompt
        guard !Self.isRunningInPreview else { return }

        status = .starting
        guard await CameraPermission.request() == .authorized else {
            status = .denied
            return
        }

        observeStats()
        do {
            try await camera.start()
            status = .running
        } catch let failure as CameraSession.Failure {
            status = .failed(failure.description)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func stop() async {
        statsTask?.cancel()
        statsTask = nil
        await camera.stop()
        status = .idle
    }

    private func observeStats() {
        guard statsTask == nil else { return }
        // the one main-actor crossing in the pipeline, and it happens once a second, not once a frame
        statsTask = Task { [weak self, camera] in
            for await value in camera.stats {
                self?.stats = value
            }
        }
    }

    private static var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
