# Rep labels — hand-counted, written before the counter ran

The recordings themselves are not committed: 38 MB, regenerable, and gitignored. These labels are
neither, and #17 asks for them in a committed file.

Analysis and the numbers derived from them: `c4/thresholds.md` in the Obsidian vault.

## 2026-09-02 — pre-registered validation

Counts written in Notes **before** the first recording: **8 · 10 · 12 · 8 shallow · 10**.

The first session (`data-almost/`) was recorded with the feet clipped by the bottom of the frame —
the room was too small. Discovered mid-session, so three of the sets were re-recorded with the
feet fully inside the frame (`data-almost-some-fix/`). Both sessions are kept: the first is the
evidence for what clipping does to the measurement.

| file | condition | written | performed | counted |
|---|---|---|---|---|
| `data-almost/clean-side-20260902-143006` | clean | 8 | 8 | 8 |
| `data-almost/clean-side-20260902-143050` | clean | 10 | 10 | 10 |
| `data-almost/clean-side-20260902-143139` | clean | 12 | 12 | 12 |
| `data-almost/bad-set-20260902-143248` | shallow | 8 | **7** | 7 |
| `data-almost/clean-side-20260902-143320` | clean | 10 | 10 | 10 |
| `data-almost-some-fix/clean-side-20260902-144531` | clean | 10 | 10 | 10 |
| `data-almost-some-fix/clean-side-20260902-144613` | clean | 12 | **13** | 13 |
| `data-almost-some-fix/bad-set-20260902-144706` | shallow | 8 | 8 | 8 |

**78 reps, 78 agreements, 0 disagreements.**

### Two labels the athlete corrected

- `143248` — stopped at seven rather than eight, having noticed the recording was wrong.
- `144613` — one extra rep by accident.

In both the counter matched what was **performed**, not what was written. Recorded here because a
counter that tracks reality when the label drifts is stronger evidence than one that matches a
label exactly.

### Caveats

- One person, one session, one room. This is an accuracy figure for this athlete, not for users.
- The first five sets originally counted 4, 1, 1, 2, 7. `SetupGate` disarmed on the first frame any
  joint dropped below the judge gate, and re-arming needs three still seconds that never occur
  mid-set. Fixed with a 15-frame hysteresis before the counts above were taken.
- That fix was made **after** the failure was seen, so it was checked for circularity: sweeping the
  window from 15 to 60 frames changes no count in any file. See `c4/thresholds.md`.

## 2026-09-01 — earlier device run, also pre-registered

Intent declared before the set: five good reps, then three deliberately shallow.

| | written | counted |
|---|---|---|
| `clean-side-20260901-214336` | 5 good + 3 shallow | 8 reps, 5 passed, 3 failed |

Failures at 100.3°, 105.2° and 105.6° against a 96° threshold. Independently recomputed from the
raw joints in the same recording: same 8, same 5, same 3.

## Not labelled

The 30 recordings of 2026-08-31 in `datasets/` were counted **after** the counter had run, so they
are a consistency result rather than an accuracy one. They are not listed here, and no accuracy
claim is made from them.
