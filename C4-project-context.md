---
challenge: C4
big_idea: Growth
framework: Vision
device: iPhone 17 / iOS 26
act_phase: 2026-08-21 → 2026-09-04
tags: [challenge-4, vision, pose-detection, ios]
research: "[[apple-vision-body-pose]]"
---

# C4 — Project Context

Planning + decisions. Technical detail lives in [[apple-vision-body-pose]] — this doc points at it rather than duplicating it.

---

## Direction

| | |
|---|---|
| **Big Idea** | Growth |
| **Essential Question** | How can I learn to detect and interpret real-time body pose using the Vision framework? |
| **Challenge Statement** | Learn Vision body pose detection! |

**Learning statement**

> Learn Apple Vision framework by producing **a real-time body pose app for one movement — live camera, minimal overlay, and a HUD showing raw vs smoothed joint angle with per-joint confidence** as my learning evidence, so that I am able to **read what Vision actually returns, turn a jittery pose signal into a measurement I can trust, and explain where my thresholds came from and which form faults a single camera can honestly see** by the end of the 10-day Act phase.

---

## The app

Pick a movement, prop the phone up, do the set. App counts reps, judges form, says what was wrong and why.

```
choose movement
  → framing check (are the required joints visible above threshold?)
  → setup hold (3s in valid start position)
  → judge + count reps
  → set complete → summary
```

Framing check and setup hold kill a whole class of false positives. Without them the app grades you while you're walking back from the phone.

---

## Scope

**10 Act days.** Aug 21, 24, 26, 27, 28, 31, Sep 1, 2, 3, 4.
(Aug 25 Maulid Nabi. Sep 7 Learning Review, Sep 8 Gallery.)
Weekends Aug 22–23, 29–30 unassigned — slack, not build days.

### Movement priority

Ordered by **plane of movement**, not by "difficulty" — see [[apple-vision-body-pose#8 Camera view per exercise]]. Rule: film perpendicular to the plane of movement.

| # | Movement | Plane / view | Why this one |
|---|---|---|---|
| 1 | **Squat** | sagittal / side | Both legs align in the sagittal plane, so one side view sees everything. 2D is genuinely fine. #1 in my program. |
| 2 | **Lateral raise** | frontal / front | Frontal-plane movement, front view, 2D handles it well. Cheap second once the pipeline exists. |
| 3 | **Bent-over row** | sagittal / side | Torso creeps up *across* the set as I fatigue — a cross-rep fault, not a per-rep one. Different judging pattern. (Arms are bilateral so judge one side only.) |
| 4 | **Plank** | sagittal / side | Static hold. No reps — breaks the state machine, judging becomes time-based. |

**Realistic:** movement 1 is the deliverable. 2–4 are stretch, in order.

**Later, not v1**
- Push-up — sagittal/side, so geometrically fine. Deferred only because the pipeline should be proven standing first.
- Deadlift / RDL — view is fine, but the fault worth catching (spinal rounding) is finer than the measurement error. Could do hip-vs-shoulder rise timing instead.
- Bicep curl — **worst case: neither single view is clean.** Side hides the far arm, front foreshortens the forearm. This is exactly the gap 3D fills. Good example to *cite*, bad one to build.
- Floor press / bench press — lying flat is where pose models degrade most.
- Split squat, calf raise — occlusion / amplitude below error margin.

**Out entirely:** CreateML, Watch companion, exercise auto-recognition, workout history.

---

## Architecture

Full technical detail in [[apple-vision-body-pose]]. Decisions only here.

| Layer | Using | Notes |
|---|---|---|
| Capture | `AVCaptureSession`, `kCVPixelFormatType_32BGRA`, `alwaysDiscardsLateVideoFrames = true`, delegate on its own queue | Never main queue |
| Pose | `DetectHumanBodyPoseRequest` — **new Swift API**, iOS 18+ | Not `VNDetect*`. Most tutorials are old-style: drop the `VN`, replace callbacks with `await` |
| Coordinates | `toImageCoordinates(size, origin: .upperLeft)` → **pixels before any angle math** | Non-negotiable, see below |
| Gating | Observation-level ~0.6, joint-level 0.3 for judging / 0.5 for drawing | Two levels, gate both |
| Angle | `acos` on the dot product, clamped | `atan2` only for signed/direction-aware (torso lean vs vertical) |
| Smoothing | EMA — `smoothed = smoothed*0.7 + raw*0.3` | Raw jumps ±5° frame to frame |
| Rep counting | Two-threshold state machine (hysteresis), count on the way **up** | Single threshold double-counts on jitter |
| Feedback | Minimal overlay + HUD | Three dots, two lines, one number |

### Three things that will bite

**1. Normalized coordinates are anisotropic.** x and y are normalized to width and height *separately*, so angle math on raw normalized coords is **wrong**. Convert to pixels first, always.

**2. The compactMap collapse.** Filtering confidence *after* building the joint array lets a 3-point array silently become 2 points — the polyline draws shoulder→wrist and the angle function returns a plausible wrong number, no error. Fires exactly at the bottom of a squat. Fix is all-or-nothing:

```swift
guard pts.count == joints.count else { return [] }
```

**3. `acos` returns NaN, not a weird angle.** Float error pushes the ratio past 1.0. Clamp to [-1, 1].

### Vision draws nothing

Returns a dictionary of ~19 labeled points + confidence. A few hundred bytes per frame. No bones, no edges, no skeleton type — every stick figure in every demo is somebody's own drawing code. The `.leftArm` / `.torso` groups are fetch buckets, not connections.

**Joint count:** WWDC20 slide says 17, the enum has 19 (slide omits `neck` and `root`). Trust the enum.

### ExerciseDefinition — config, not classes

```
ExerciseDefinition
  name, plane, cameraView          // sagittal/frontal, side/front
  requiredJoints: [...]            → framing check
  setupPose: [angle conditions]    → hold 3s to arm judging
  repSignal:  view-invariant       → see below
  formSignal: angle + thresholds   → view-sensitive
  faults: [ name, jointTriple, validRange, cue ]
  judgeAt: .phase(.bottom) | .continuous(every: 0.5s)
```

**The key split: rep counting and form judging need different signals.**

- **Form judging** → correct view + true angle. View-sensitive.
- **Rep counting** → any monotone up/down signal. Wrist height relative to shoulder, normalized by shoulder→hip distance. Works from any view, survives foreshortening, scale-free.

So from a bad camera angle you can still count reps honestly — you just can't grade them. That's a feature to expose, not a failure to hide.

---

## Decision log

### 2D vs 3D — and why the usual reasoning is wrong

The axis that matters is **scale-invariant vs view-invariant**.

Angles are already scale-invariant, so 3D's headline features (`bodyHeight`, real-world meters, `cameraOriginMatrix`) are worth **nothing** here. Don't pick 3D for those.

Angles are *not* view-invariant. 2D gives **projected** angles — correct only when the movement plane is parallel to the image plane. Off-axis camera produces a silently wrong number: no error, no low confidence. 3D gives true angles from any camera position, and its API is native to it (`localPosition`, `calculateLocalAngleToParent()`).

**So 3D is genuinely better for form judging.** The reason to avoid it is *runtime maturity, not capability.*

| Blocker | |
|---|---|
| **Vision 3D** | Memory leak ~1GB/min at 30fps per-frame. Filed, no Apple reply, no workaround. Reproduced on Mac Catalyst with async `perform(on:)` in a per-frame `Task` — may not reproduce on iOS with the sync handler path. **Untested, ~1hr with Instruments.** Also: single-frame API, not built for live; zero published streaming perf numbers. |
| **ARKit** | FB15128723 — `ARBodyAnchor` never fires on iOS 26.0/26.1 on LiDAR devices. 0 of ~89 joints, reproduces in Apple's own sample. Filed Oct 2025, no reply through Dec 2025. Status unknown. **Rear-camera-only is a non-issue** — phone propped against a wall filming me *is* rear camera. |

**Decision: start 2D, and make camera placement part of the product.** "Place your phone here, step back until you see the outline" is what every commercial form app ships. Not a workaround — the same constraint they live with.

**Escalation path if projected angles prove insufficient:**
1. Test the ARKit sample on device (~30 min) — either hands me the best option or eliminates it
2. Test the Vision 3D leak on iOS (~1 hr)
3. Hybrid: 2D every frame for reps/tempo, 3D at 5–10Hz as a view-correction layer (low rate also sidesteps the leak)

### Why rules, not ML

- *"Which exercise is this"* → classification. ML fits.
- *"Is this rep correct"* → measurement. Wrong shape for ML — it's a number I can compute.

Also: a classifier outputs "82% likely bad rep" and can't say *why*, so it can't produce a coaching cue. Explaining the error is the entire purpose of the app.

**Nothing is wasted either way.** Create ML's Action Classifier consumes **Vision pose output** — it sits on top of this pipeline, never replaces it. When the time comes, the binding constraint is **subject diversity, not clip count** (500 clips of one person < 100 clips of 30 people). That's the precise name for what went wrong in C3.

### Why Vision doesn't know it's a squat

19 points with x, y, confidence. No verb, no label. Each frame judged fresh.

The user selects the movement; the app *verifies* against a config rather than *recognising*. Recognition is a different feature from correction, and correction doesn't need it.

### Ground truth — partly available, and I should use it

| | Available? | Cost |
|---|---|---|
| Joint positions | needs marker mocap | inaccessible — skip |
| **Rep count** | **hand-label 20 recorded videos** | **an afternoon — do this** |
| Form correctness | needs a coach, and coaches disagree | expensive + genuinely subjective |

Rep counting *is* cheaply validatable. "No ground truth so I calibrated" is honest for form, a dodge for reps.

**Calibration is what replaces ground truth in production:**
- **Normalize by the body, not the frame** — divide distances by torso/limb length. Kills camera-distance dependence.
- **Per-user calibration** — record one good rep, set thresholds relative to *that person's* ROM. A fixed 90° fails half of users. Demo vs product.

---

## Learning plan — 5 cycles

| Cycle | Days | Milestone |
|---|---|---|
| **1 — First contact** | Aug 21 (1d) | **Know:** what a pose request returns — 19 joints, normalized lower-left space, confidence. **Have:** static image → 19 joints printed to console. ~10 lines. Physical device (Neural Engine, no simulator). |
| **2 — Live pipeline** | Aug 24, 26 (2d) | **Know:** running Vision on `CMSampleBuffer` off the main queue; pixel conversion. **Have:** live camera + minimal overlay + HUD (fps, `17/19` joints above threshold). |
| **3 — Measurement + replay harness** | Aug 27, 28 (2d) | **Know:** three points → an angle; why pixels not normalized coords. **Have:** live knee angle, **and JSON/CSV logging + a replay mode**. |
| **4 — Trust** | Aug 31, Sep 1 (2d) | **Know:** how much Vision jitters, where confidence drops, where thresholds come from. **Have:** EMA smoothing, hysteresis thresholds derived from my own logged waveform, rep counting. Hand-label 20 videos to validate. |
| **5 — Judgement + demo** | Sep 2, 3, 4 (3d) | **Know:** which faults a single camera can honestly see. **Have:** one fault + cue, freeze, backup video. |

### Build the replay harness before the state machine

Capture video + per-frame joint stream to JSON, then a debug mode that replays the JSON instead of the live camera. ~50 lines, pays back the same day. Every threshold tweak becomes a normal edit-run loop instead of another 10 squats.

This is why cycle 3 includes it and cycle 4 depends on it — deriving hysteresis numbers by guessing "160/100" from theory doesn't survive a real body.

### Checkpoints

- **Aug 26** — live angle responding correctly. If not: stop adding, debug.
- **Sep 1** — rep counting stable and validated against hand-labeled video. Decides cycle 5 content.
- **Sep 3** — freeze. Record backup demo video regardless.

Sep 4: no new code.

---

## Debugging output

Vision renders nothing — all output is mine. Four layers, in order of value:

1. **CSV/JSON log to file** — *most important.* Need the real angle waveform over a real rep to pick thresholds.
2. **On-screen HUD** — not optional. Can't read the console while squatting. Show fps, joints-above-threshold, live angle, state, rep count.
3. **Skeleton overlay** — color joints by confidence. Makes occlusion and framing problems visible. Full skeleton behind a debug toggle.
4. **Console print, throttled** (`if frameCount % 30 == 0`). 30fps × 19 joints floods Xcode.

The HUD is also the demo safety net — if the live demo misbehaves at the Gallery, switching to it turns a failure into an explanation.

### Ship less than you draw

The 19-joint stick figure is demo aesthetic, noise for a form judge.

```
hip ──── knee ──── ankle   + angle at the knee, line turns red out of range
```

Three dots, two lines, one number. The user instantly sees what's measured and why a rep failed.

---

## Learning layers

**Learn while building, not before.** Each lands 10× harder after hitting the problem.

| Build stage | Learn alongside |
|---|---|
| Static image → print joints → draw skeleton | nothing |
| Live camera → one angle on screen | vector geometry — dot product, `acos` vs `atan2` |
| See the jitter | signal processing — EMA vs one-euro, latency/stability tradeoff, hysteresis |
| Try a bad camera angle, watch the number lie | **projective geometry** — foreshortening, perspective, pinhole model |
| Set thresholds | squat biomechanics — strength/physio literature, not Apple docs |

**Projective geometry is the most fundamental layer.** It determines camera placement rules, exercise feasibility, and the entire 2D-vs-3D decision. Signal processing tells you how to trust a noisy number; projection tells you whether the number means what you think it means.

---

## Open questions

- Does the Vision 3D leak reproduce on iOS with the sync handler path? (~1 hr, Instruments)
- Is FB15128723 (ARKit body tracking) fixed on current iOS? (~30 min, Apple's sample)
- What angle waveform does a real squat actually produce? → decides the hysteresis numbers
- Apple's current guidance on Action Classifier dataset size (unverified)

---

## Setup

- New Xcode project. Nothing carries over from C1–C3.
- `NSCameraUsageDescription` in Info.plist.
- **Physical device only** — Neural Engine required, no simulator.
- Phone stand before writing code.
- Reading old tutorials: drop the `VN`, replace callbacks with `await`.

**Next step:** static image → print joints. ~10 lines. Everything above is theory until that console prints 19 joints.

---

## Standing principles

- Rep counting and form judging are **different signals**. Don't conflate them.
- Convert to pixels before any angle math.
- All-or-nothing on joint arrays. A collapsed array lies silently.
- Judge at the bottom of the rep. The top carries no information.
- Derive thresholds from my own logged waveform, not from theory or tutorials.
- Camera placement is part of the product, not a workaround.
- One movement done properly beats four done badly.
- If it can't be explained to the user, it's the wrong architecture.
