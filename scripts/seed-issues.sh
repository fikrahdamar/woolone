#!/usr/bin/env bash
# Seeds the C4 label set and the full build backlog (cycles 1-5 + spikes).
# Run once, after `gh auth login`.
#
# Labels are idempotent (--force). ISSUES ARE NOT — re-running duplicates every issue.
set -euo pipefail

REPO="fikrahdamar/woolone"

new_issue() {   # new_issue <title> <labels>   — body on stdin
  gh issue create --repo "$REPO" --title "$1" --label "$2" --body "$(cat)"
}

echo "==> labels"
# type
gh label create c4            --repo "$REPO" --color 0E8A16 --description "C4 challenge"                                  --force
gh label create learning      --repo "$REPO" --color C2E0C6 --description "Output is understanding, not code"             --force
gh label create spike         --repo "$REPO" --color FBCA04 --description "Timeboxed question, output is an answer"       --force
gh label create invariant     --repo "$REPO" --color B60205 --description "Violates a Vision invariant — fails silently"  --force
gh label create needs-device  --repo "$REPO" --color D93F0B --description "Cannot be closed from a green build alone"     --force
# cycle
gh label create cycle-1       --repo "$REPO" --color 1D76DB --description "First contact"                                 --force
gh label create cycle-2       --repo "$REPO" --color 1D76DB --description "Live pipeline"                                 --force
gh label create cycle-3       --repo "$REPO" --color 1D76DB --description "Measurement + replay harness"                  --force
gh label create cycle-4       --repo "$REPO" --color 1D76DB --description "Trust"                                         --force
gh label create cycle-5       --repo "$REPO" --color 1D76DB --description "Judgement + demo"                              --force
# area
gh label create area:config   --repo "$REPO" --color BFD4F2 --description "Project + build configuration"                 --force
gh label create area:capture  --repo "$REPO" --color BFD4F2 --description "AVCaptureSession, frames"                      --force
gh label create area:vision   --repo "$REPO" --color BFD4F2 --description "Vision requests, joints, confidence"           --force
gh label create area:core     --repo "$REPO" --color BFD4F2 --description "Geometry, signal, exercise config"             --force
gh label create area:ui       --repo "$REPO" --color BFD4F2 --description "Views, overlay, HUD"                           --force
gh label create area:debug    --repo "$REPO" --color BFD4F2 --description "Logging, replay, instrumentation"              --force

# ---------------------------------------------------------------- cycle 1
echo "==> cycle 1 — Aug 21 — First contact"

new_issue "Project setup: Swift 6 mode, camera permission, folder skeleton" "c4,cycle-1,area:config" <<'BODY'
**Why**

Everything downstream assumes Swift 6 strict concurrency — `nonisolated` capture delegate,
`Sendable` frame types, one main-actor hop per frame. Turning it on after the pipeline exists
means fixing isolation errors in code that already works, which is the expensive order.

**Do**

- Flip `SWIFT_VERSION` 5.0 → 6.0 in Build Settings.
- Add `NSCameraUsageDescription` with a real sentence — this string is shown to the user.
- Create the group structure from CLAUDE.md: `App/`, `Core/{Capture,Pose,Geometry,Signal,Exercise,Logging}/`, `Features/`, `UI/`.

**Acceptance criteria**

- [ ] `SWIFT_VERSION = 6.0`, project builds with no concurrency errors
- [ ] `NSCameraUsageDescription` present and human-readable
- [ ] Folder structure matches CLAUDE.md exactly
- [ ] App launches on the physical device — a blank screen is a pass

**Watch for**

`SWIFT_APPROACHABLE_CONCURRENCY = YES` is already set. If Swift 6 produces a wall of errors in
the template code, fix the template rather than reverting the language mode.

Refs: CLAUDE.md § Concurrency · § Architecture
BODY

new_issue "Static image to 19 joints printed on device" "c4,cycle-1,area:vision,needs-device" <<'BODY'
**Why**

The first real proof. Every planning document in this repo is theory until a console prints
19 joints. ~10 lines of code, and it settles what the API actually hands back.

**Do**

- Bundle one photo of a person, full body, clean lighting.
- Run a single pose request over it.
- Print every joint name with its location and confidence.

Use the new Swift API — `DetectHumanBodyPoseRequest` + `try await request.perform(on:)`.
Not `VNDetectHumanBodyPoseRequest`. Most tutorials online are the old style: drop the `VN`,
replace the completion handler with `await`.

**Acceptance criteria**

- [ ] Console prints joint name + location + confidence, one line each
- [ ] Count is **19**, with `neck` and `root` present
- [ ] No `VN`-prefixed type anywhere in the diff
- [ ] Ran on the physical device

**Watch for**

The WWDC20 slide says 17 landmarks — it omits `neck` and `root` from its count. Trust the enum.
Simulator has no Neural Engine; a simulator run proves nothing.

**Learning target**

What a pose observation *is*: a dictionary of ~19 labeled points plus confidence, a few hundred
bytes, normalized to a lower-left origin. No image, no skeleton, no bones.

Refs: CLAUDE.md § Vision invariants 1, 6 · [[apple-vision-body-pose]] § 1, § 2
BODY

new_issue "Write up cycle 1: what Vision returns, and what it does not" "c4,cycle-1,learning" <<'BODY'
**Why**

Learning evidence for the C4 Learning Review. Written the day it is understood, not
reconstructed on Sep 7 from a git log.

**Do**

Daily log at `c4/log/2026-08-21.md` in the vault (learning-scribe handles the mechanics).
Answer, from the console output rather than from the docs:

- What are the 19 joint names, and which are surprising?
- What coordinate space are the locations in, and where is the origin?
- What does confidence look like on a clean photo — the range, and which joints run low?
- What are `.leftArm` and `.torso` actually for?

**Acceptance criteria**

- [ ] `c4/log/2026-08-21.md` exists with the standard sections
- [ ] The Numbers section quotes real confidence values from the run
- [ ] `c4/index.md` has the day's line appended
- [ ] The Learned section says something that was not already in the planning docs

**Watch for**

"Built X" is not a learning. If the day produced no new understanding, write that — an honest
empty section is better evidence than padding.

Refs: `.claude/agents/learning-scribe.md`
BODY

# ---------------------------------------------------------------- cycle 2
echo "==> cycle 2 — Aug 24, 26 — Live pipeline"

new_issue "Live camera capture off the main queue" "c4,cycle-2,area:capture,needs-device" <<'BODY'
**Why**

The frame pump. No Vision yet — isolate the capture layer so that when pose detection starts
dropping frames, it is obvious which half is at fault.

**Do**

Wrap `AVCaptureSession` in `Core/Capture/CameraSession.swift`.

- `kCVPixelFormatType_32BGRA`
- `alwaysDiscardsLateVideoFrames = true`
- Sample buffer delegate on its own dispatch queue

**Acceptance criteria**

- [ ] Live preview visible on device
- [ ] Delegate is `nonisolated` and never runs on the main queue
- [ ] On-screen frame counter shows a steady ~30fps
- [ ] `Core/` still imports no SwiftUI

**Watch for**

Without `alwaysDiscardsLateVideoFrames`, frames queue up under load and the overlay drifts
seconds behind the body while every number still looks plausible.

Refs: CLAUDE.md § Concurrency · [[apple-vision-body-pose]] § 6
BODY

new_issue "Run pose detection on live frames" "c4,cycle-2,area:vision,needs-device" <<'BODY'
**Why**

Same request as the static image, now at 30fps against a `CMSampleBuffer`. This is where the
coordinate and confidence rules stop being theory.

**Do**

- Per frame: `CMSampleBufferGetImageBuffer` → pose request → joints.
- Gate the observation (~0.6) before trusting any joint.
- Convert every joint with `toImageCoordinates(size, origin: .upperLeft)` **immediately**, and
  never let a normalized value escape the conversion boundary.
- Publish a `PoseFrame` value to the ViewModel in exactly one main-actor hop.

**Acceptance criteria**

- [ ] Joints converted to pixels before anything else consumes them
- [ ] Both confidence levels gated: observation ~0.6, joint 0.5 for drawing
- [ ] `PoseFrame` and `Joint` are `Sendable` value types
- [ ] Exactly one main-actor hop per frame
- [ ] No frame drop visible at 30fps on device

**Watch for**

Normalized coordinates are anisotropic — x and y are normalized to width and height
*separately*. Any math on raw normalized values is wrong, silently.

Refs: CLAUDE.md § Vision invariants 2, 5 · [[apple-vision-body-pose]] § 4
BODY

new_issue "Skeleton overlay — our own drawing code" "c4,cycle-2,area:ui,needs-device" <<'BODY'
**Why**

Vision renders nothing. Every stick figure in every demo is somebody's drawing code, and this
is ours. Its real job is making occlusion and bad framing *visible* — which joints drop out,
and where.

**Do**

- Ordered polylines, not edge pairs: `[.leftHip, .leftKnee, .leftAnkle]` draws as a chain
  **and** feeds `angle()` later with the vertex in the middle.
- Colour each joint by confidence.
- Full 19-joint skeleton behind a debug toggle.

**Acceptance criteria**

- [ ] Overlay tracks the body with no visible lag
- [ ] Joint colour changes visibly as confidence drops (test by turning sideways)
- [ ] Debug toggle switches full skeleton on and off
- [ ] The View imports no Vision and no AVFoundation

**Watch for**

Do not build the point array with `compactMap` and filter confidence afterwards. A 3-point
array silently becomes 2, and the polyline draws shoulder straight to wrist. All-or-nothing:
`guard pts.count == joints.count else { return [] }`. This fires exactly at the bottom of a squat.

Refs: CLAUDE.md § Vision invariants 3, 7 · [[apple-vision-body-pose]] § 3
BODY

new_issue "HUD: fps, joints above threshold, state" "c4,cycle-2,area:debug,needs-device" <<'BODY'
**Why**

Not optional and not a debug toggle. You cannot read the Xcode console while squatting. It is
also the demo safety net — if the live demo misbehaves at the Gallery, switching to the HUD
turns a failure into an explanation.

**Do**

Persistent on-screen readout: measured fps, `n/19` joints above threshold, live angle (once it
exists), state machine state, rep count.

**Acceptance criteria**

- [ ] Readable at arm's length, standing, mid-set
- [ ] fps is measured, not assumed
- [ ] Joint count updates live and visibly drops when you turn sideways
- [ ] Does not disappear in release builds

Refs: CLAUDE.md § Debug output · [[apple-vision-body-pose]] § 9
BODY

new_issue "PoseSource protocol: live camera and replay interchangeable" "c4,cycle-2,area:core" <<'BODY'
**Why**

The seam that makes every later threshold cheap. Built now, deriving hysteresis numbers is an
edit-run loop; built later, it is another 10 squats per tweak. ~50 lines, pays back the same day.

**Do**

- `PoseSource` protocol emitting `PoseFrame` values.
- `LiveCameraSource` conforms.
- `ReplaySource` conforms, reading a JSON frame stream from disk.
- The ViewModel holds a `PoseSource` and cannot tell which it has.

**Acceptance criteria**

- [ ] Both sources conform to one protocol
- [ ] Swapping the source requires no ViewModel change
- [ ] `ReplaySource` respects frame timing rather than replaying as fast as it can read
- [ ] The whole app runs on replay with no camera, in the simulator

**Watch for**

Anything that only works with a live camera breaks the replay harness, and every threshold
derived from it. Treat "does this still work on replay?" as a build check.

Refs: CLAUDE.md § Architecture · [[apple-vision-body-pose]] § 9
BODY

new_issue "Write up cycle 2: coordinate spaces and why pixels" "c4,cycle-2,learning" <<'BODY'
**Why**

The anisotropic-normalization trap is the single most-cited Vision bug and the easiest to
re-introduce. Writing it down in your own words is what makes it stick.

**Do**

Answer with a number from your own run, not from the note:

- What does an angle computed on raw normalized coordinates read, versus the same angle in
  pixels? Measure both on one frame.
- Why does the error depend on the aspect ratio?
- What did the confidence colouring reveal about framing that you had not expected?

**Acceptance criteria**

- [ ] Daily logs exist for Aug 24 and Aug 26
- [ ] The normalized-vs-pixel comparison quotes both actual numbers
- [ ] `c4/index.md` updated

Refs: [[apple-vision-body-pose]] § 4
BODY

# ---------------------------------------------------------------- cycle 3
echo "==> cycle 3 — Aug 27, 28 — Measurement + replay harness"

new_issue "angle() with NaN guard, unit tested" "c4,cycle-3,area:core" <<'BODY'
**Why**

The measurement primitive. Everything the app claims rests on this function being right, and
it is small enough to test properly off-device.

**Do**

```swift
func angle(_ a: CGPoint, _ vertex: CGPoint, _ c: CGPoint) -> CGFloat
```

Two vectors out from the vertex, `acos` of the normalized dot product, degrees out.
`atan2` stays available for signed, direction-aware angles (torso lean against vertical).

**Acceptance criteria**

- [ ] Input to `acos` clamped to [-1, 1]
- [ ] Zero-magnitude vectors handled without dividing by zero
- [ ] Tests cover: 90°, 180°, collinear points, identical points, and a case that overflows
      the ratio past 1.0 without the clamp
- [ ] Tests run on the simulator — this file must not need a device
- [ ] Pure Swift, no SwiftUI import

**Watch for**

The real `acos` failure is **NaN**, not a weird angle. Float error pushes the ratio past 1.0,
`acos` returns NaN, and NaN then poisons the EMA permanently — one bad frame and the smoothed
value never recovers.

**Learning target**

Dot product for unsigned interior angles, `atan2` for signed ones. Why `atan2` is also
numerically safer near 0° and 180°.

Refs: CLAUDE.md § Vision invariants 4 · [[apple-vision-body-pose]] § 5
BODY

new_issue "Live knee angle on screen" "c4,cycle-3,area:vision,needs-device" <<'BODY'
**Why**

First real measurement. Also the first chance to see how much Vision jitters, which decides
everything in cycle 4.

**Do**

Pull hip / knee / ankle, all-or-nothing, judging gate at 0.3. Feed `angle()`. Show it on the HUD
to one decimal.

**Acceptance criteria**

- [ ] Angle responds correctly and immediately to a real squat
- [ ] Reads ~180° standing, drops toward ~90° at depth
- [ ] Missing any of the three joints shows a clear "no reading" state, never a stale number
- [ ] Ran on device

**Watch for**

Stale values are the dangerous failure. If a joint drops out, the last good number must not
keep sitting on the HUD looking live.

**Checkpoint — Aug 26 in the plan.** If the angle is not responding correctly, stop adding
features and debug. Everything after this depends on this number being real.

Refs: CLAUDE.md § Vision invariants 3, 5
BODY

new_issue "FrameLogger: per-frame JSON to disk" "c4,cycle-3,area:debug,needs-device" <<'BODY'
**Why**

The most important debug output of the four. Hysteresis thresholds cannot be picked without
the actual angle waveform of a real squat — guessing 160/100 from theory does not survive a
real body.

**Do**

Write per frame: timestamp, all joint positions + confidences, computed angle, state.
Newline-delimited JSON is fine. Include a way to get the file off the device.

**Acceptance criteria**

- [ ] One line per frame, parseable by `ReplaySource`
- [ ] Logging does not drop frames at 30fps
- [ ] Start/stop recording from the HUD without a rebuild
- [ ] File retrievable from device (Files app or Xcode container download)
- [ ] A recorded set of 10 squats replays identically to the live run

**Watch for**

Round-trip is the acceptance test. A log the replay source cannot read is a log that taught
you nothing.

Refs: CLAUDE.md § Debug output · [[apple-vision-body-pose]] § 9
BODY

new_issue "Replay mode: run the whole app from a JSON file" "c4,cycle-3,area:debug" <<'BODY'
**Why**

Turns every threshold tweak into a normal edit-run loop instead of another 10 squats. The
reason cycle 4 is affordable at all.

**Do**

Debug entry point selecting a recorded session instead of the camera. Same ViewModel, same
overlay, same HUD.

**Acceptance criteria**

- [ ] Runs in the simulator with no camera
- [ ] Overlay and HUD behave identically to live
- [ ] Scrub or step frame-by-frame
- [ ] Recorded video plays alongside, or is at least referenced, so a number can be checked
      against what the body was doing

Refs: CLAUDE.md § Architecture · [[apple-vision-body-pose]] § 9
BODY

new_issue "Record the reference set: 20 squats, varied conditions" "c4,cycle-3,area:debug,needs-device" <<'BODY'
**Why**

The dataset every later decision is argued from. Recorded once, replayed all cycle 4.

**Do**

Record video **and** JSON simultaneously. Deliberately vary:

- clean side view, correct distance — the baseline
- too close, too far
- camera rotated off the sagittal plane (this is the one that makes 2D lie)
- fast reps, slow reps, a paused rep at the bottom
- one deliberately bad set: shallow depth, knees caving

**Acceptance criteria**

- [ ] ≥20 sets recorded, each with paired video + JSON
- [ ] Every condition above covered at least once
- [ ] Each file named for its condition
- [ ] All of them replay without crashing

**Learning target**

Watch the angle lie on the off-axis recordings. This is projective geometry arriving as an
observation instead of a chapter — foreshortening produces a wrong number with full confidence
and no error.

Refs: [[apple-vision-body-pose]] § 7, § 11
BODY

new_issue "Write up cycle 3: vector geometry, and the first look at jitter" "c4,cycle-3,learning" <<'BODY'
**Why**

Cycle 3 is where the numbers start being real. This is the write-up that has actual data behind it.

**Do**

- Plot one rep's raw angle waveform from the log. Attach the plot.
- How much does the raw angle jump frame to frame? Give the real range.
- What does the waveform look like on the off-axis recording versus the clean one?
- `acos` versus `atan2` — which did you use where, and why?

**Acceptance criteria**

- [ ] Daily logs for Aug 27 and Aug 28
- [ ] A real waveform plot, from real logged data
- [ ] Frame-to-frame jitter quantified with a number, not "quite noisy"
- [ ] `c4/index.md` updated

Refs: [[apple-vision-body-pose]] § 5, § 11
BODY

# ---------------------------------------------------------------- cycle 4
echo "==> cycle 4 — Aug 31, Sep 1 — Trust"

new_issue "EMA smoothing, raw and smoothed both visible" "c4,cycle-4,area:core" <<'BODY'
**Why**

Raw jumps ±5° frame to frame, which double-counts reps on any single threshold. Smoothing is
the fix and it costs latency — you need to see both numbers to judge the trade.

**Do**

`smoothed = smoothed * 0.7 + raw * 0.3`, tuned against the recorded set. Show raw and smoothed
side by side on the HUD.

**Acceptance criteria**

- [ ] Both values on the HUD simultaneously
- [ ] Coefficient chosen by replaying the recorded set, and the reasoning is in the issue comment
- [ ] Smoothed value visibly lags on fast reps — you can state by roughly how much
- [ ] A NaN frame cannot permanently poison the smoothed value
- [ ] Tuned entirely on replay, zero squats performed

**Learning target**

EMA versus one-euro filter. The latency/stability trade-off, felt rather than read: more
smoothing buys a calmer number and costs responsiveness at the bottom of the rep, which is
exactly where the judgement happens.

Refs: CLAUDE.md § Measurement rules · [[apple-vision-body-pose]] § 6
BODY

new_issue "Derive hysteresis thresholds from the logged waveform" "c4,cycle-4,learning,area:core" <<'BODY'
**Why**

This is the issue the whole replay harness was built for, and the one that separates a real
project from a tutorial. Two thresholds with a gap between them; the gap is the hysteresis.

**Do**

Analyse the recorded set — not theory, not a tutorial, not a strength textbook:

- What is the actual angle at the top of a rep? At the bottom? Across all 20 sets?
- How much does the top vary between reps as fatigue sets in?
- How wide must the gap be to survive the jitter measured in cycle 3?
- Where do these numbers fail — the fast reps, the paused rep, the off-axis recording?

**Acceptance criteria**

- [ ] Two threshold constants, each with a comment naming the recording it came from
- [ ] The analysis is written down, with the distribution, not just the final pair of numbers
- [ ] The chosen gap is justified against the measured jitter
- [ ] Numbers hold across every recording in the reference set, or the exceptions are named

**Watch for**

A bare `160` or `100` in the diff with no log behind it is a bug, not a threshold. If the data
does not support a number, say so instead of guessing one.

Refs: CLAUDE.md § Measurement rules · [[apple-vision-body-pose]] § 6
BODY

new_issue "RepCounter: two-threshold state machine" "c4,cycle-4,area:core" <<'BODY'
**Why**

Reps are the one thing here that is cheaply validatable against ground truth, so they should be
right.

**Do**

Hysteresis state machine over the rep signal. Count on the way **up**. The same signal yields
ROM (minimum angle) and tempo (frames between state changes) for free — capture both.

Rep signal and form signal are different signals: rep counting uses wrist/hip height relative
to shoulder, normalized by shoulder→hip distance — scale-free and view-invariant. Form judging
uses the true angle and is view-sensitive.

**Acceptance criteria**

- [ ] Two thresholds, from the previous issue
- [ ] Counts on the ascent
- [ ] ROM and tempo recorded per rep
- [ ] Rep counting still works on the off-axis recording where the angle is wrong
- [ ] Unit tested against synthetic waveforms, including a jittery one that would double-count
      under a single threshold

**Watch for**

Never share a threshold constant between rep counting and form judging. Conflating them means
a bad camera angle silently breaks the rep count too — the one thing that should have survived.

Refs: CLAUDE.md § Vision invariants 7 · [[apple-vision-body-pose]] § 8
BODY

new_issue "Validate rep counting against 20 hand-labeled videos" "c4,cycle-4,learning" <<'BODY'
**Why**

"No ground truth so I calibrated" is honest for form judging and a dodge for rep counting.
Rep count is hand-labelable in an afternoon, so not doing it is a choice, not a constraint.

**Do**

- Watch each recording, count reps by eye, write the number down **before** running the counter.
- Run the counter over all 20.
- Build the confusion table: agreement, over-counts, under-counts.
- For every disagreement, find the frame and name the cause.

**Acceptance criteria**

- [ ] Hand labels recorded before running the counter, in a committed file
- [ ] Accuracy stated as a number over the whole set
- [ ] Every disagreement diagnosed to a specific frame and cause
- [ ] Failure modes written up — which conditions break it and why

**Checkpoint — Sep 1.** This result decides what cycle 5 can honestly claim. If rep counting is
not stable here, cycle 5 shrinks rather than the standard dropping.

Refs: [[apple-vision-body-pose]] § 11 · C4-project-context.md § Ground truth
BODY

new_issue "Write up cycle 4: signal processing and where thresholds come from" "c4,cycle-4,learning" <<'BODY'
**Why**

The strongest learning evidence in the project. Everything here is a number you produced,
defended against your own data.

**Do**

- How much does Vision actually jitter, and where is it worst?
- Which joints drop confidence, at which point in the movement?
- Where did each threshold come from, and what would move it?
- What does the validation table say, and what does it *not* cover?

**Acceptance criteria**

- [ ] Daily logs for Aug 31 and Sep 1
- [ ] Threshold provenance written down well enough that someone else could re-derive them
- [ ] Validation results included, failures and all
- [ ] `c4/index.md` updated

Refs: [[apple-vision-body-pose]] § 11
BODY

# ---------------------------------------------------------------- cycle 5
echo "==> cycle 5 — Sep 2, 3, 4 — Judgement + demo"

new_issue "ExerciseDefinition + squat config" "c4,cycle-5,area:core" <<'BODY'
**Why**

The structure that keeps a second movement cheap without inviting a class hierarchy that is
never justified by one exercise.

**Do**

```
ExerciseDefinition
  name, plane, cameraView          // sagittal/frontal, side/front
  requiredJoints: [...]            → framing check
  setupPose: [angle conditions]    → hold 3s to arm judging
  repSignal:  view-invariant
  formSignal: angle + thresholds   → view-sensitive
  faults: [ name, jointTriple, validRange, cue ]
  judgeAt: .phase(.bottom) | .continuous(every: 0.5s)
```

**Acceptance criteria**

- [ ] One value type, config only — no `SquatJudge: ExerciseJudge` subclassing
- [ ] Squat expressed entirely as data, with thresholds from cycle 4
- [ ] The judging engine has no knowledge of squats specifically
- [ ] A second movement would be a new value, not a new type

Refs: CLAUDE.md § Architecture · C4-project-context.md § ExerciseDefinition
BODY

new_issue "Framing check + 3s setup hold" "c4,cycle-5,area:ui,needs-device" <<'BODY'
**Why**

Kills a whole class of false positives. Without it the app grades you while you are walking
back from the phone.

**Do**

```
framing check (required joints visible above threshold?)
  → setup hold (3s in a valid start position)
  → judging armed
```

Camera placement is part of the product, not a workaround — every commercial form app ships
exactly this constraint. Say where to put the phone.

**Acceptance criteria**

- [ ] Judging cannot start until every required joint is visible
- [ ] Clear on-screen guidance when framing fails, naming what is missing
- [ ] 3s hold in a valid start position arms judging
- [ ] Walking out of frame mid-set disarms rather than producing garbage
- [ ] Tested on device from a real phone stand at real distance

Refs: C4-project-context.md § The app
BODY

new_issue "One fault, one cue" "c4,cycle-5,area:core,needs-device" <<'BODY'
**Why**

Explaining the error is the entire purpose of the app. A classifier saying "82% likely bad rep"
cannot produce a coaching cue; a measured angle can.

**Do**

Pick the single fault the camera can most honestly see — depth is the obvious candidate.
Judge at the bottom of the rep; the top carries no information. Say what was wrong and why.

**Acceptance criteria**

- [ ] Exactly one fault, judged at the bottom phase
- [ ] The cue names the measurement — the angle, and the range it needed to be in
- [ ] The threshold traces back to a cycle 4 recording
- [ ] Verified on the deliberately-bad recording in the reference set
- [ ] Faults not honestly detectable from one camera are documented as out of scope, not faked

**Watch for**

Do not add a second fault because there is time. One fault explained correctly is the
deliverable; two guessed at is worse than one.

Refs: CLAUDE.md § Measurement rules · C4-project-context.md § Standing principles
BODY

new_issue "Ship the minimal overlay: three dots, two lines, one number" "c4,cycle-5,area:ui" <<'BODY'
**Why**

The 19-joint stick figure is demo aesthetic and noise for a form judge. The user should
instantly see what is being measured and why a rep failed.

**Do**

```
hip ──── knee ──── ankle   + the angle at the knee, line turns red out of range
```

Full skeleton stays, behind the debug toggle.

**Acceptance criteria**

- [ ] Default view shows three joints, two segments, one number
- [ ] The segment colour changes at the fault threshold, visibly, at a glance
- [ ] Full skeleton still reachable in debug
- [ ] Legible on video recorded from across a room — this is what the Gallery sees

Refs: CLAUDE.md § Debug output · [[apple-vision-body-pose]] § 10
BODY

new_issue "Freeze, record the backup demo, prepare the Gallery story" "c4,cycle-5,needs-device" <<'BODY'
**Why**

**Sep 3 is the freeze. Sep 4 is no new code.** A live demo on someone else's schedule, in
someone else's lighting, is not a plan by itself.

**Do**

- Record a clean run of the full flow: framing → setup hold → set → summary.
- Record a second video of a deliberately bad set, so the fault cue is visible on camera.
- Prepare the HUD explanation as the fallback: if the live demo misbehaves, switching to the
  HUD turns a failure into an explanation of how the measurement works.
- Have the waveform plot and the validation table ready to show.

**Acceptance criteria**

- [ ] Backup video recorded regardless of how well the live demo works
- [ ] Bad-set video shows the cue firing
- [ ] Waveform plot and validation numbers to hand
- [ ] Everything committed and pushed before the freeze

Refs: C4-project-context.md § Checkpoints
BODY

new_issue "Write up cycle 5: what one camera can honestly see" "c4,cycle-5,learning" <<'BODY'
**Why**

The closing argument for the Learning Review, and the most defensible thing in the project:
knowing precisely where the measurement stops being trustworthy.

**Do**

- Which squat faults are visible from a single side view, and which are not — with the reason,
  not the guess.
- Where does the projected angle stop being usable? Quote the off-axis recording.
- What would 3D have changed, and what would it not have?
- Which of the four open questions in [[apple-vision-body-pose]] got answered, and how?

**Acceptance criteria**

- [ ] Daily logs for Sep 2, 3, 4
- [ ] Feasibility argued per fault, with evidence
- [ ] Open questions in the tech note patched — answered ones closed with their evidence,
      unanswered ones left honestly open
- [ ] `c4/index.md` complete for the whole Act phase

Refs: [[apple-vision-body-pose]] § 7, § 8
BODY

# ---------------------------------------------------------------- spikes
echo "==> spikes — open questions, unscheduled"

new_issue "Spike: does the Vision 3D memory leak reproduce on iOS?" "c4,spike,area:vision,needs-device" <<'BODY'
**Timebox: ~1 hour.** Output is an answer, not code. Anything built here is throwaway.

**Question**

Vision 3D body pose leaks ~1GB/min at 30fps per-frame. Reproduced on **Mac Catalyst** with
async `perform(on:)` inside a per-frame `Task`. Does it reproduce on **iOS** with the
synchronous handler path?

https://developer.apple.com/forums/thread/790825

**Why it matters**

3D gives true, view-invariant angles — genuinely better for form judging. The reason to avoid
it is runtime maturity, not capability. If the leak does not reproduce on iOS, the escalation
path opens up.

**Do**

Minimal per-frame 3D request on device, Instruments Allocations, ~5 minutes of runtime.

**Acceptance criteria**

- [ ] Memory growth measured over 5 minutes, with the number
- [ ] Sync handler path and async `Task` path compared
- [ ] Answer recorded in the open questions of [[apple-vision-body-pose]]
- [ ] Throwaway code deleted or clearly labelled

Refs: [[apple-vision-body-pose]] § 7
BODY

new_issue "Spike: is ARKit body tracking (FB15128723) fixed on current iOS?" "c4,spike,needs-device" <<'BODY'
**Timebox: ~30 minutes.** Output is an answer, not code.

**Question**

FB15128723 — `ARBodyAnchor` never fires on iOS 26.0/26.1 on LiDAR devices. 0 of ~89 joints,
reproduces in Apple's own "Capturing Body Motion in 3D" sample. Filed Oct 2025, no reply
through Dec 2025. Still broken?

https://developer.apple.com/forums/thread/804899

**Why it matters**

Either hands over the best available option or eliminates it permanently. Rear-camera-only is
a non-issue here — a phone propped against a wall filming you *is* the rear camera.

**Do**

Download Apple's sample, run on device, count joints.

**Acceptance criteria**

- [ ] Sample run on the physical device
- [ ] Joint count observed and recorded — 0 or ~89
- [ ] iOS version noted exactly
- [ ] Answer recorded in the open questions of [[apple-vision-body-pose]]

Refs: [[apple-vision-body-pose]] § 7
BODY

echo
echo "done."
echo "gh issue list --repo $REPO --label c4"
