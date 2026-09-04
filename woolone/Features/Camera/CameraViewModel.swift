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
    /// What the screen should say, and how urgently. The View picks the colours, not the meaning.
    struct Headline: Equatable {
        enum Tone: Equatable {
            case waiting
            case ready
            case good
            case bad
        }

        let text: String
        let tone: Tone
    }

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
    private(set) var smoothedAngle: CGFloat?
    private(set) var reps = 0
    private(set) var lastRep: RepCounter.Rep?
    private(set) var judgement: FormJudge.Judgement?
    /// The single line worth reading from three metres away.
    private(set) var headline = Headline(text: "step into frame", tone: .waiting)
    /// Off by default: a demo that starts talking unprompted is worse than one that stays quiet.
    private(set) var isCoachOn = false
    /// Spike only — the 3D reading taken on the same frames as the 2D one.
    private(set) var reading3D = Pose3DProbe.Reading.none

    private let source: any PoseSource
    private let logger = FrameLogger()
    // typed, so transport control needs no cast — and the live path never sees it
    private let replaySource: ReplaySource?
    private var tasks: [Task<Void, Never>] = []
    private var isSwitchingCamera = false
    private var legSelector = LegSelector()
    private var setupGate = SetupGate()
    private let exercise = ExerciseDefinition.squat
    private var verdictShownAt: Double = -.greatestFiniteMagnitude
    private let probe3D = Pose3DProbe()
    private var coach = SpeechCoach()
    private let speaker = Speaker()
    private var angleEMA = EMA()
    // the rep signal is smoothed too: the hysteresis gap is 0.12 and raw jitter eats into it
    private var signalEMA = EMA()
    private var repCounter = RepCounter()

    init(camera: CameraSession = CameraSession()) {
        self.camera = camera
        replaySource = nil
        source = LiveCameraSource(camera: camera, logger: logger, probe3D: probe3D)
    }

    /// The seam, exercised for the first time: everything below this line cannot tell which source it got.
    init(replaying recording: Recording) throws  {
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

    /// Red while the measurement sits outside the fault's range — colour reads across a room, a number does not.
    var isFaulted: Bool {
        guard isArmed, setupGate.isSquare,
              let angle = smoothedAngle,
              let fault = exercise.faults.first else { return false }
        return !fault.validRange.contains(angle)
    }

    /// The cue names the measurement and the range it needed, never a verdict on the person.
    var verdictText: String? {
        if let judgement { return judgement.text }
        guard isArmed, !setupGate.isSquare else { return nil }
        return "not square — reps counted, form not graded"
    }

    var verdictPassed: Bool { judgement?.passed ?? false }

    /// Spike only: both knee angles from the same instant, so turning 45° shows which one moves.
    var comparison3DText: String? {
        if let failure = reading3D.failure {
            return "3D FAILED · \(failure)"
        }
        guard reading3D.jointCount > 0 else { return nil }
        func degrees(_ value: CGFloat?) -> String {
            value.map { String(format: "%.0f°", $0) } ?? "—"
        }
        return "3D L\(degrees(reading3D.leftKnee)) R\(degrees(reading3D.rightKnee))"
            + "  ·  2D \(degrees(kneeAngle))"
            + String(
                format: "  ·  %.0f ms · %d joints · %.2fm %@",
                reading3D.milliseconds,
                reading3D.jointCount,
                reading3D.bodyHeightMetres ?? 0,
                reading3D.isHeightMeasured ? "measured" : "ASSUMED"
            )
    }

    /// The second line: the count, the live angle, and anything that makes the set untrustworthy.
    var summaryText: String {
        var parts = ["\(reps) rep\(reps == 1 ? "" : "s")"]
        parts.append(kneeAngle.map { String(format: "knee %.0f°", $0) } ?? "knee —")
        // a set with gaps had joints leave the frame, and its depths read too deep — feet cut off
        // by the bottom edge misplace the ankle, which bends the angle the wrong way
        if setupGate.lossesSinceArming > 0 {
            parts.append("\(setupGate.lossesSinceArming) GAPS")
        }
        return parts.joined(separator: "  ·  ")
    }

    /// Raw and smoothed side by side — smoothing costs depth at the bottom, so the price stays visible.
    var measurementText: String {
        var parts: [String] = []
        if let smoothedAngle {
            parts.append(String(format: "smooth %.1f°", smoothedAngle))
        }
        if setupGate.lossesSinceArming > 0 {
            parts.append("\(setupGate.lossesSinceArming) GAPS — check feet in frame")
        }
        if let lastRep, let lowest = lastRep.lowestAngle {
            parts.append(String(format: "last %.0f° · %.1fs", lowest, lastRep.seconds))
        }
        if let spread = setupGate.spread {
            parts.append(String(format: "square %.2f", spread))
        }
        return parts.joined(separator: " · ")
    }

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
            // two names, not three: "step back" is the action, the names are only there so the
            // user can tell a framing problem from an occlusion one
            "step back — " + names.prefix(2)
                .map(\.label)
                .joined(separator: ", ") + " out of frame"
        case .waiting(.notStanding):
            "stand up to start"
        }
    }

    // counting survives a crooked camera; grading does not, and the user is told which they are getting
    private var squareSuffix: String {
        guard let spread = setupGate.spread else { return "" }
        guard setupGate.isSquare else {
            return String(
                format: " · NOT SQUARE %.2f, needs %.2f — counting only",
                spread,
                SetupGate.spreadLimit
            )
        }
        return String(format: " · square %.2f", spread)
    }

    /// A missing angle says so out loud — a stale number sitting there looking live is the dangerous failure.
    var kneeAngleText: String {
        // the rep count rides on the big line: it is unreadable anywhere smaller from a phone stand
        let tail = isArmed ? String(format: "  ·  %d rep%@", reps, reps == 1 ? "" : "s") : ""
        guard let kneeAngle else { return "knee — no reading\(tail)" }
        return String(format: "knee %.1f°", kneeAngle) + tail
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

    func toggleCoach() {
        isCoachOn.toggle()
        coach.reset()
        if !isCoachOn { speaker.stop() }
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
                let now = Self.now()
                let wasArmed = setup == .armed
                pose = frame
                setup = setupGate.update(frame, at: now)
                legJoints = legSelector.select(from: frame)
                // the angle follows the leg the selector settled on, so the line and the number agree
                // the exercise names its own triple; nothing here knows it is a knee
                kneeAngle = legSelector.side.flatMap { side in
                    exercise.faults.first.flatMap { frame.measuredAngle(of: $0.joints, on: side) }
                }
                smoothedAngle = angleEMA.update(kneeAngle)

                let signal = signalEMA.update(frame.repSignal)
                // non-nil only on the frame a rep closed, which is what makes the spoken verdict
                // fire once rather than on every frame after it
                var finished: FormJudge.Judgement?
                if setup == .armed {
                    // the hold's own median, not the last frame — one jittery sample shifts every rep after it
                    if !wasArmed, let baseline = setupGate.baseline {
                        repCounter.arm(baseline: baseline)
                    }
                    // judged at the bottom of the rep: the top carries no information
                    if let rep = repCounter.update(signal: signal, angle: smoothedAngle, at: now) {
                        finished = FormJudge(definition: exercise)
                            .judge(rep, isSquare: setupGate.isSquare)
                        judgement = finished ?? judgement
                    }
                    reps = repCounter.count
                    lastRep = repCounter.lastRep
                }

                if finished != nil { verdictShownAt = now }
                headline = Self.headline(
                    setup: setup,
                    setupText: setupText,
                    isSquare: setupGate.isSquare,
                    judgement: judgement,
                    verdictAge: now - verdictShownAt
                )

                if isCoachOn, let cue = coach.update(
                    state: setup,
                    isSquare: setupGate.isSquare,
                    angle: smoothedAngle,
                    depthLimit: exercise.faults.first?.validRange.upperBound ?? 0,
                    judgement: finished,
                    at: now
                ) {
                    speaker.say(cue)
                }
            }
        })
        tasks.append(Task { [weak self, source] in
            for await value in source.poseStats {
                self?.poseStats = value
            }
        })
        if let live = source as? LiveCameraSource {
            tasks.append(Task { [weak self, live] in
                for await value in live.readings3D {
                    self?.reading3D = value
                }
            })
        }
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

    /// A finished rep owns the line for a moment, then it goes back to saying what to do next.
    // three seconds: long enough to read at a glance, short enough that the next rep is not
    // judged against a line describing the previous one. A preference, not a measurement.
    static let verdictSeconds: Double = 3

    private static func headline(
        setup: SetupGate.State,
        setupText: String,
        isSquare: Bool,
        judgement: FormJudge.Judgement?,
        verdictAge: Double
    ) -> Headline {
        if let judgement, verdictAge < verdictSeconds {
            return Headline(text: judgement.text, tone: judgement.passed ? .good : .bad)
        }
        guard setup == .armed else {
            return Headline(text: setupText, tone: .waiting)
        }
        guard isSquare else {
            return Headline(text: "square up — counting only", tone: .waiting)
        }
        return Headline(text: "ready", tone: .ready)
    }

    private static func now() -> Double {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
    }

    private static var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
