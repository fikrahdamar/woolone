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

    /// nil when replaying — a recorded session has no preview layer and must not raise a permission prompt.
    let camera: CameraSession?
    private(set) var status: Status = .idle
    private(set) var stats = CaptureStats.idle
    private(set) var poseStats = PoseStats.idle
    private(set) var pose: PoseFrame?
    private(set) var legJoints: [Joint] = []
    private(set) var kneeAngle: CGFloat?
    private(set) var facing: CameraFacing = .back
    private(set) var showsAllJoints = false
    private(set) var recording = RecordingStats.idle
    private(set) var replay = ReplayProgress.idle
    private(set) var setup: SetupGate.State = .waiting(.noPerson)

    private let source: any PoseSource
    private let logger = FrameLogger()
    // typed, so transport control needs no cast — and the live path never sees it
    private let replaySource: ReplaySource?
    private var tasks: [Task<Void, Never>] = []
    private var isSwitchingCamera = false
    private var legSelector = LegSelector()
    private var setupGate = SetupGate()

    init(camera: CameraSession = CameraSession()) {
        self.camera = camera
        replaySource = nil
        source = LiveCameraSource(camera: camera, logger: logger)
    }

    /// The seam, exercised for the first time: everything below this line cannot tell which source it got.
    init(replaying recording: Recording) throws {
        camera = nil
        let replay = try ReplaySource(recording)
        replaySource = replay
        source = replay
    }

    var isReplaying: Bool { replaySource != nil }
    var replayName: String? { replaySource?.recording.name }

    func play() async { await replaySource?.play() }
    func pause() async { await replaySource?.pause() }
    func step(by delta: Int) async { await replaySource?.step(by: delta) }
    func seek(to index: Int) async { await replaySource?.seek(to: index) }

    var statusText: String {
        switch status {
        case .idle: "camera off"
        case .starting: "starting"
        case .running: pose == nil ? "warming up — the first frame compiles the model" : "running"
        case .denied: "camera access denied — enable it in Settings"
        case .failed(let reason): "failed: \(reason)"
        }
    }

    var isArmed: Bool { setup == .armed }

    /// A gate that refuses without naming the reason is a bug report, not guidance.
    var setupText: String {
        switch setup {
        case .armed:
            "ready\(squareSuffix)"
        case .holding(let remaining):
            String(format: "hold still %.1fs", max(0, remaining)) + squareSuffix
        case .waiting(.noPerson):
            "step into frame"
        case .waiting(.missingJoints(let names)):
            "step back — " + names.prefix(3)
                .map(\.label)
                .joined(separator: ", ") + " out of frame"
        case .waiting(.notStanding):
            "stand up to start"
        case .waiting(.notSquare(let spread)):
            String(
                format: "turn square to the phone — %.2f, needs %.2f",
                spread,
                SetupGate.spreadLimit
            )
        }
    }

    // the number is what makes the instruction actionable: without it you cannot tell you are drifting
    private var squareSuffix: String {
        guard let spread = pose?.shoulderSpread else { return "" }
        return String(format: " · square %.2f", spread)
    }

    /// A missing angle says so out loud — a stale number sitting there looking live is the dangerous failure.
    var kneeAngleText: String {
        guard let kneeAngle else { return "knee — no reading" }
        return String(format: "knee %.1f°", kneeAngle)
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

    var overlayChains: [[Joint]] {
        guard showsAllJoints else { return legJoints.isEmpty ? [] : [legJoints] }
        return pose?.chains(above: PoseConfidence.draw) ?? []
    }

    func toggleAllJoints() {
        showsAllJoints.toggle()
    }

    var cameraText: String {
        facing == .front
            ? "camera front · the view is a mirror, so left and right joint names are swapped"
            : "camera back"
    }

    /// The header records the camera once, so a flip mid-recording would transpose half the file silently.
    var canFlipCamera: Bool { camera != nil && status == .running && !recording.isRecording }

    /// Refuses before the first frame: the header needs a real image size and orientation, not a guess.
    func startRecording(_ condition: RecordingCondition) async {
        guard let pose, status == .running, !recording.isRecording else { return }
        do {
            try await logger.start(condition, camera: facing, sample: pose)
        } catch let failure as FrameLogger.Failure {
            status = .failed(failure.description)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func stopRecording() async {
        await logger.stop()
    }

    /// Front camera exists to check the overlay against yourself — judging still means the back camera, side on.
    func flipCamera() async {
        guard canFlipCamera, !isSwitchingCamera else { return }
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
        if camera != nil {
            guard await CameraPermission.request() == .authorized else {
                status = .denied
                return
            }
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
        kneeAngle = nil
        legSelector.reset()
    }

    private func observe() {
        guard tasks.isEmpty else { return }
        // the one main-actor crossing per frame in the whole pipeline
        tasks.append(Task { [weak self, source] in
            for await frame in source.poseFrames {
                guard let self else { return }
                pose = frame
                setup = setupGate.update(frame, at: Self.now())
                legJoints = legSelector.select(from: frame)
                // the angle follows the leg the selector settled on, so the line and the number agree
                kneeAngle = legSelector.side.flatMap { frame.kneeAngle($0) }
            }
        })
        tasks.append(Task { [weak self, source] in
            for await value in source.poseStats {
                self?.poseStats = value
            }
        })
        if let camera {
            tasks.append(Task { [weak self, camera] in
                for await value in camera.stats {
                    self?.stats = value
                }
            })
            tasks.append(Task { [weak self, logger] in
                for await value in logger.stats {
                    self?.recording = value
                }
            })
        }
        if let replaySource {
            tasks.append(Task { [weak self, replaySource] in
                for await value in replaySource.progress {
                    self?.replay = value
                }
            })
        }
    }

    private static func now() -> Double {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
    }

    private static var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
