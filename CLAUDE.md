# woolone — Project Rules

Real-time body pose form judge. Vision framework, 2D, single person, live camera.
Full technical background: `C4-project-context.md`. Read it before non-trivial work.

## Knowledge base

The Vision invariants below are distilled from `tech/apple-vision-body-pose.md` in my
Obsidian vault (located in `~/.claude/CLAUDE.md`). Do not re-read the vault for those —
consult it for everything else, and for the reasoning behind a rule this file only states.

## Hard constraints

|             |                                                                        |
| ----------- | ---------------------------------------------------------------------- |
| Device      | iPhone 17, iOS 26.5 deployment target                                  |
| Simulator   | **Never works.** Vision needs the Neural Engine. Physical device only. |
| Deliverable | Squat, sagittal plane, side view. One movement done properly.          |
| Timeline    | Act phase Aug 21 – Sep 4 2026. Code freeze Sep 3.                      |

**Out of scope entirely:** CreateML, Watch companion, exercise auto-recognition, workout
history, multi-person. Do not add these. Do not scaffold for them.

## Build & run

```sh
# compile check only — this is what you run
xcodebuild -scheme woolone -destination 'generic/platform=iOS' build
```

Running the app requires a tethered device. If a change needs runtime verification, say so
and hand it back — never claim behaviour is verified from a build that only compiled.

## Tickets — GitHub Issues

Issues on `fikrahdamar/woolone`, driven with `gh`. One issue = one build task.

| Label                 | Meaning                                                                   |
| --------------------- | ------------------------------------------------------------------------- |
| `c4`                  | on every issue in this challenge                                          |
| `cycle-1` … `cycle-5` | which learning cycle it belongs to                                        |
| `invariant`           | a violation of a Vision invariant — highest priority, these fail silently |
| `spike`               | a timeboxed question, output is an answer not code                        |

Rules:

- The issue body is the brief. Work starts by reading it, not by re-explaining the project.
- Every issue needs acceptance criteria concrete enough to check. "Live angle on screen" is
  not one; "console prints 19 joint names with confidences from a static image on device" is.
- Reference the issue in the commit (`... (#7)`) so the diff and the ticket link themselves.
- An issue whose acceptance criteria need a device stays open until it runs on the device.
  A green `xcodebuild` does not close it.

## Workflow

**Branches** — `<type>/<issue#>-<slug>`:

```
feat/7-live-knee-angle          new pipeline capability
fix/12-nan-poisons-ema          something measures wrong
chore/1-swift6-camera-permission  config, no behaviour change
spike/27-vision-3d-leak-ios     timeboxed question
docs/3-cycle1-writeup           learning write-up
```

Create with `gh issue develop <n> --name <branch> --checkout` — that links the branch to the
issue on GitHub, which naming alone does not.

**Base is `dev`.** `main` is release, `staging` cuts TestFlight builds.
Merge forward only: `dev → staging → main`. Never cherry-pick between them.

**Agents do not commit, push, merge, or close issues.** Write the code, run the build and the
suite, report what happened, and stop. Git belongs to the user — this is deliberate, not an
oversight. The same goes for Xcode build settings and any script under `scripts/`.

**Issues labeled `needs-device` are closed by hand**, after the app runs on the phone. A green
build and a passing suite never close one. Use `Refs #N` in those PRs, not `Closes #N`.

## Architecture — MVVM, one-way data flow

```
woolone/
  App/                    wooloneApp.swift
  Core/                   pure Swift. No SwiftUI import. Runs off-device in tests.
    Capture/              CameraSession           AVCaptureSession wrapper
    Pose/                 PoseSource (protocol) → LiveCameraSource | ReplaySource
                          PoseFrame, Joint       Sendable value types
    Geometry/             angle(), clamping
    Signal/               EMA, RepCounter (hysteresis state machine)
    Exercise/             ExerciseDefinition + squat config
    Logging/              FrameLogger (JSON per-frame stream)
  Features/<Feature>/     View + ViewModel, one folder per screen
  UI/                     OverlayView, HUDView — dumb, props in only
```

**Layer rules**

- **View** — zero logic, zero Vision/AVFoundation imports. Renders what the ViewModel hands it.
- **ViewModel** — the only `@MainActor @Observable` type. Owns screen state. Contains no CV
  math, no angle math, no thresholds. Consumes `PoseFrame`, publishes display values.
- **Core** — no UI framework imports, no `@MainActor`. Everything here is unit-testable
  without a camera.

**`PoseSource` is the seam.** Live camera and JSON replay both conform. The ViewModel cannot
tell them apart. This is what makes the replay harness cheap — build it before the state machine.

**`ExerciseDefinition` is config data, not a class hierarchy.** One struct, one value per
movement. No `SquatJudge: ExerciseJudge` subclassing.

## Concurrency — Swift 6 strict

- Capture delegate is `nonisolated`, on its own dispatch queue. **Never the main queue.**
- `PoseFrame`, `Joint`, `ExerciseDefinition` are `Sendable` value types.
- Cross to the main actor exactly once per frame, at the ViewModel boundary.
- `alwaysDiscardsLateVideoFrames = true`, `kCVPixelFormatType_32BGRA`.
- No shared mutable state between frames outside an actor.

## Vision invariants — non-negotiable

<!-- Distilled from vault tech/apple-vision-body-pose.md, synced 2026-08-20.
     Re-check after any apple-vision ingest. If these and the vault disagree,
     surface both and ask — see ~/.claude/CLAUDE.md. -->

Every one of these fails **silently** — wrong number, no error, no low confidence.

1. **New Swift API.** `DetectHumanBodyPoseRequest` + `try await request.perform(on:)`.
   Never `VNDetectHumanBodyPoseRequest`. Reading an old tutorial: drop the `VN`, replace
   callbacks with `await`.
2. **Pixels before any angle math.** Normalized coords are anisotropic — x and y are
   normalized to width and height _separately_. Always
   `location.toImageCoordinates(size, origin: .upperLeft)` first.
3. **All-or-nothing joint arrays.** Filtering confidence after building the array lets a
   3-point array collapse to 2, and the angle function returns a plausible wrong number.
   ```swift
   guard pts.count == joints.count else { return [] }
   ```
4. **Clamp `acos` input to [-1, 1].** The failure mode is NaN, not a weird angle.
5. **Gate confidence at both levels.** Observation ~0.6, joint 0.3 for judging / 0.5 for drawing.
6. **19 joints, not 17.** The WWDC slide omits `neck` and `root`. Trust the enum.
7. **Vision draws nothing.** It returns a dictionary of labeled points. No bones, no edges,
   no skeleton type. `.leftArm` / `.torso` are fetch buckets, not connections. Every stick
   figure is our own drawing code.
8. **Rep counting and form judging are different signals. Never conflate them.**
   Form judging needs the correct view and a true angle — view-sensitive.
   Rep counting needs any monotone signal (wrist height relative to shoulder, normalized by
   shoulder→hip distance) — view-invariant. A bad camera angle must still count reps honestly
   while refusing to grade them.

## Measurement rules

- Smoothing is EMA: `smoothed = smoothed * 0.7 + raw * 0.3`. Raw jumps ±5° frame to frame.
- Rep counting uses two thresholds (hysteresis). Count on the way **up**. A single threshold
  double-counts on jitter.
- Judge at the bottom of the rep. The top carries no information.
- **Thresholds come from our own logged waveform, never from theory or a tutorial.** A literal
  `160`/`100` in a diff without a log to justify it is a bug.
- Normalize by the body (torso/limb length), not the frame.

## Debug output is a feature, not scaffolding

Vision renders nothing — all output is ours. In order of value:

1. **JSON/CSV frame log to file** — needed to pick thresholds at all.
2. **On-screen HUD** — mandatory, not a debug toggle. fps, `17/19` joints above threshold,
   live angle, state, rep count. Can't read the console while squatting. Also the demo safety net.
3. **Skeleton overlay** — joints colored by confidence. Full 19-joint skeleton stays behind a
   debug toggle.
4. **Console prints throttled** — `if frameCount % 30 == 0`. 30fps × 19 joints floods Xcode.

**Ship less than you draw.** Product overlay is three dots, two lines, one number:
`hip ── knee ── ankle` + the angle, line turns red out of range.

## Testing

Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest.

Test `Core/` only — pure functions, no camera, runs on the simulator. That the layering
already forbids SwiftUI and `@MainActor` in `Core/` is what makes this possible; keep it that way.

Two things earn a test because the alternative is worse:

- **`angle()`** — the NaN case is invisible on device. Float error pushes the ratio past 1.0,
  `acos` returns NaN, NaN enters the EMA, and the smoothed value never recovers. On screen that
  looks like a frozen HUD, and you will hunt it in the camera layer.
- **`RepCounter`** — verifying hysteresis by hand costs ten squats per threshold change.
  A synthetic jittery waveform costs nothing.

Once recorded sessions exist, they are the fixtures: replay all 20 through the counter and
compare against the hand labels. Real data beats invented waveforms.

Do not mock the camera or Vision. Untestable is untestable — verify those on device.

Cycles 1-2 explore, cycles 3-5 test first. You cannot spec an API you have not seen return.

```sh
xcodebuild test -scheme woolone -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Swift style

- `@Observable`, not `ObservableObject`/`@Published`.
- `async`/`await` and `Task`. No Combine, no completion handlers in new code.
- Apple naming conventions. Types `UpperCamelCase`, everything else `lowerCamelCase`.
  No Hungarian prefixes, no `m_`.
- Small files, one type per file. A file growing past ~200 lines is a signal it does too much.
- `#Preview` for every View. Views must preview without a camera.
- Value types by default. Reference types only for genuine shared identity (capture session).
- No force unwrap outside `#Preview` and test fixtures.
- `Info.plist` needs `NSCameraUsageDescription`.

**Comments — one line, or none.**

- At most **one** `///` line above a type or a non-obvious function. No multi-line doc blocks,
  no `- Parameters:` / `- Returns:` ceremony. A three-line function does not need a five-line
  header.
- `//` explains **why**, never what. `// convert to pixels` above a conversion is noise;
  `// normalized coords are anisotropic — angles on them are wrong` is the reason someone
  needs six weeks from now.
- Never stack `//` lines into a paragraph. If one clear line cannot carry it, the code needs
  a better name or the explanation belongs in this file.
- `// MARK:` is fine — it is navigation, not prose.
- No commented-out code. Git remembers it.

## Standing principles

- Rep counting and form judging are different signals.
- Convert to pixels before any angle math.
- All-or-nothing on joint arrays. A collapsed array lies silently.
- Judge at the bottom of the rep.
- Derive thresholds from logged waveforms, not from theory.
- Camera placement is part of the product, not a workaround.
- One movement done properly beats four done badly.
- If it can't be explained to the user, it's the wrong architecture.
