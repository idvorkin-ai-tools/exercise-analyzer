# Pistol squat

Code: `ExerciseCore/Sources/ExerciseCore/PistolSquatAnalyzer.swift` (ported from swing-analyzer's
`PistolSquatFormAnalyzer.ts`).

## Phases

STANDING → DESCENDING → BOTTOM → ASCENDING → STANDING (rep complete).

- **Working leg**: the more bent knee (knee asymmetry), chosen once in the first descent and kept for the whole
  set (`SingleLegTracker`); a set that alternates legs is not supported.
- **Bottom**: the lowest head position (`earY`), confirmed once the head has risen again for a few frames.
- **Descending / ascending checkpoints**: the frames nearest 50 % of the head travel on the way down and up.

| Threshold | Value | Meaning |
|---|---|---|
| `standingKneeMin` | 150° | working knee nearly straight |
| `standingSpineMax` | 25° | relatively upright |
| `descendingKneeThreshold` | 140° | descent starts when the working knee drops below this |
| `ascendingKneeThreshold` | 90° | ascent starts when the working knee rises back above this |
| `maxValidSpineAngle` | 60° | frames where the person is basically horizontal are rejected |

## Fixtures

| Fixture | Reps | Verified |
|---|---|---|
| pistol-6reps | 5 | no (read from the video's frames 2026-09-28, not yet Igor's count; the name is the old baseline) |

## Experiments

- **2026-09-12, detector**: pistols with moderate asymmetry fell to "ambiguous"; the detector now takes the 95th
  percentile of knee asymmetry over 80° with the feet level as a pistol (commit 8bc27b5).
- No human-verified pistol set yet. Next: one phone set, `just pull-logs`, cut a fixture, have Igor confirm the count.
- **2026-09-28, pistol-6reps ([#171](https://github.com/idvorkin/exercise-analyzer/issues/171))**: an unmeasured
  working knee reads 0° and passed `workingKnee < 140`, so a hidden knee started a phantom descent; a missing head
  read as `earY` 0 (the top of the screen), so three headless frames counted as "risen" and confirmed a bottom.
  Both now keep the phase (`PistolSquatAnalyzerTests`); a 0° knee no longer counts as depth or a bent extended leg
  in the score. The fixture went 6 → 5, and 5 is right: `TuningReports.testPistolHeadlessFrames` shows no head and
  no knee at all for 0–2.1 s and straight knees (164–180°) to 4.4 s, and the frames show Igor walking away from the
  camera past the lens (0.5–2.0 s, torso only) and standing (3.0 s). Main's rep 1 (bottom 3.10 s at a 173° knee)
  was the walk-in, made a rep by exactly these two bugs. The five dips: bottoms near 6.5, 11.0, 15.0, 20.0,
  27.5 s (ear 456–479 px, knee 77–96°); the clip ends standing. The Haiku frame helper said 7 at a steady 3.5 s,
  with a squat at 3.0 s; the frames contradict it. AnalysisVersion 2026-09-28.1.
