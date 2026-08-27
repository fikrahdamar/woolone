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

    let camera: CameraSession
    private(set) var status: Status = .idle
    private(set) var stats = CaptureStats.idle
    private(set) var poseStats = PoseStats.idle
    private(set) var pose: PoseFrame?
    private(set) var legJoints: [Joint] = []
    private(set) var facing: CameraFacing = .back
    private(set) var showsAllJoints = false

    private let source: any PoseSource
    private var tasks: [Task<Void, Never>] = []
    private var isSwitchingCamera = false
    private var legSelector = LegSelector()

    init(camera: CameraSession = CameraSession()) {
        self.camera = camera
        source = LiveCameraSource(camera: camera)
    }

    var statusText: String {
        switch status {
        case .idle: "camera off"
        case .starting: "starting"
        case .running: pose == nil ? "warming up — the first frame compiles the model" : "running"
        case .denied: "camera access denied — enable it in Settings"
        case .failed(let reason): "failed: \(reason)"
        }
    }

    /// Names the joints that fell below the draw gate — a colour says which band, not which joint.
    var weakJointsText: String? {
        guard let pose, pose.hasPerson else { return nil }
        let weak = pose.weakJoints
        guard !weak.isEmpty else { return nil }

        // hip, knee and ankle always show — hiding one inside "+3" hides the reason the angle vanished
        let measuring = weak.filter(\.measuresKneeAngle)
        let others = weak.filter { !$0.measuresKneeAngle }
        let shown = measuring + others.prefix(max(0, 3 - measuring.count))

        let text = shown
            .map { "\($0.label) \(String(format: "%.2f", $0.confidence))" }
            .joined(separator: " · ")
        let rest = weak.count - shown.count
        return text + (rest > 0 ? " +\(rest)" : "")
    }

    /// The product overlay is the leg; the full set is the debug view that shows what drops out.
    var overlayJoints: [Joint] {
        showsAllJoints ? (pose?.allJoints ?? []) : legJoints
    }

    func toggleAllJoints() {
        showsAllJoints.toggle()
    }

    var cameraText: String {
        facing == .front
            ? "camera front · the view is a mirror, so left and right joint names are swapped"
            : "camera back"
    }

    /// Front camera exists to check the overlay against yourself — judging still means the back camera, side on.
    func flipCamera() async {
        guard status == .running, !isSwitchingCamera else { return }
        isSwitchingCamera = true
        defer { isSwitchingCamera = false }

        let target = facing.flipped
        do {
            try await source.use(target)
            facing = target
            legSelector.reset()
        } catch let failure as CameraSession.Failure {
            status = .failed(failure.description)
        } catch {
            status = .failed(error.localizedDescription)
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

        observe()
        do {
            try await source.start()
            status = .running
        } catch let failure as CameraSession.Failure {
            status = .failed(failure.description)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func stop() async {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        await source.stop()
        status = .idle
        pose = nil
        legJoints = []
        legSelector.reset()
    }

    private func observe() {
        guard tasks.isEmpty else { return }
        // the one main-actor crossing per frame in the whole pipeline
        tasks.append(Task { [weak self, source] in
            for await frame in source.poseFrames {
                guard let self else { return }
                pose = frame
                legJoints = legSelector.select(from: frame)
            }
        })
        tasks.append(Task { [weak self, source] in
            for await value in source.poseStats {
                self?.poseStats = value
            }
        })
        tasks.append(Task { [weak self, camera] in
            for await value in camera.stats {
                self?.stats = value
            }
        })
    }

    private static var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
