# Kettlebell swing

Code: `ExerciseCore/Sources/ExerciseCore/KettlebellSwingAnalyzer.swift` (ported from swing-analyzer's
`KettlebellSwingFormAnalyzer.ts`).

## Phases

TOP → CONNECT → BOTTOM → RELEASE → TOP (rep complete). Each phase stores one position: the best extreme for TOP and
BOTTOM, the first qualifying frame for CONNECT and RELEASE.

| Phase | Meaning | Condition (degrees, `SwingThresholds`) |
|---|---|---|
| TOP | lockout: arms at peak height, standing tall | spine < 25 (`topSpineMax`), hip > 160 (`topHipMin`), arm > 40 (`topArmMin`), or > 32 within 0.4 s of the release (`ballisticTopArmMin`, `ballisticReleaseMax`), or, within that same 0.4 s, > 20 with the wrists no more than 0.4 torso lengths below the shoulders (`wristTopArmMin`, `wristTopRiseMin`, #139); confirmed by the smoothed wrist height peaking at least 80 px under the shoulder line or higher, or, failing a peak, by `minFramesInPhase` + 2 frames spent in RELEASE (fast swings miss the exact peak); a top over 1 s after the deepest BOTTOM frame (`upswingMaxDuration`) counts only when a hinge follows within 2.5 s (`slowTopConfirmGap`, #149) |
| CONNECT | arms vertical against the body before the hinge | arm < 25 (`connectArmMax`), spine < 25 (`connectSpineMax`) |
| BOTTOM | deepest hinge, arms behind the body | arm < 75 + 15 (`bottomArmMax`, anything short of horizontal), spine > 35 (`bottomSpineMin`), hip < 140 (`bottomHipMax`) |
| RELEASE | arms leaving the body after the hip snap | arm < 25 (`releaseArmMax`), spine < 25 (`releaseSpineMax`) |

## Rules that reject non-swings

- **An upswing over 1 s is not a swing** (`releaseMaxDuration`, #4). The upswing is ballistic: the arms reach the
  top 0.15–0.3 s after crossing vertical. Standing up after parking the bell, or after picking it up, looks like a
  release but the arms rise seconds later, if at all.
- **The first swing counts; the setup before it does not** (`maxRepDuration` 4 s, #15; `hikeReleaseMax` 0.4 s,
  #148). Top to top takes about 1.2 s. A rep still standing or hinging 4 s after its top began with the walk-in,
  the pick-up or the setup: it becomes a *hike*. Its top, connect and metrics are dropped and it is timed again
  from there (again every 4 s while the hinge lasts), so its pictures and the trim start at the hike, not the
  walk-in. A recording that opens with the lifter over the bell, before any top is seen, starts a hike at the
  first hinge. A hike counts only if the arms reach the top within 0.4 s of crossing vertical (the added
  reps: 0.10–0.30 s); standing up with the bell or after parking it is slower or never reaches a top. Its Top picture
  is the lockout it reaches, and it has no Connect.
- **A slow top needs a hinge after it** (`upswingMaxDuration` 1.0 s, `slowTopConfirmGap` 2.5 s, #149). A swing's
  top comes within a second of the deepest frame of its hinge (the hip snap; max 0.93 s). A slower top is a hike
  (the lifter waited over the bell; 1.1–3.9 s) or standing up after setting the bell down (1.5–2.7 s). The hike
  is followed by the next hinge within 1.0–1.3 s, the set-down by none, or not for 6 s: so a slow top waits for
  a CONNECT → BOTTOM within 2.5 s, counts then (numbered before the rep that hinge starts), and is dropped
  otherwise, also when the clip ends first. A fast top never waits, so a clip cut on a real top keeps it. Live,
  the first swing of a set shows about a second late.
- **Unmeasured frames do not drive transitions** (0° joints are skipped); reps longer than 4 s were once produced by
  such frames.
- **A hole in the track ends the rep in progress** (`maxFrameGap` 0.5 s, #94). Half a second is a whole bottom, so
  the phases either side of a hole are not one swing. Nothing is counted again until the lifter is seen at a real
  top (upright, hips open, arms raised); the hole costs the swings inside it and no more.
- **Arm thresholds are wide on purpose** (#16): a low, close camera reads arms behind the body at up to 85° and arms
  in front at 40–55°; the spine and hip conditions separate top from bottom, so the arm only has to exclude
  hanging arms.
- **A low top counts only on a fast upswing** (`ballisticTopArmMin` 32 within `ballisticReleaseMax` 0.4 s, #97).
  One-arm swings with the upper arm on the ribs peak at 37–49°; a lifter who parked the bell and stands up with
  the arms a little forward reads 33–37° too, but gets there 0.57–0.9 s after the arms cross vertical, a swing in
  0.10–0.27 s.
- **The top is a lockout** (`topHipMin` 160, #97): real tops read hip ≥ 171°; standing up from the bell park and
  walking off reads 151–156°.

## Quality

Scored per rep from running maxima over the rep's frames (spine lean, arm height, knee flexion), not from the
stored positions; mirrored clips must score the same
(`RepCountTests.testSwingCountsMatchWhenMirrored`).

## Fixtures

| Fixture | Reps | Verified | Why it exists |
|---|---|---|---|
| swing-4reps | 4 | yes | baseline |
| swing-1h-9reps | 10 | no (9 was, top to top) | one-hand swing: the working arm is the raised one; opens over the bell, first top 2.85 s (#148) |
| swing-phone-13reps | 14 | no (13 was, top to top) | phone recording; the first swing off the floor tops at 9.75 s (#148) |
| swing-pickup-10reps | 10 | yes | #4: the bend to pick the bell up (first second) and the park at the end once counted; 9 until the first swing counted (#148) |
| swing-walkin-9reps | 10 | no (the walk-in is Igor's) | #15 (IMG_4337): the walk-in and pick-up (0.5–6.6 s) counted as rep 1; the hike into the 6.64 s top counts since #148 |
| swing-lowcam-10reps | 10 | no | #16 (IMG_4340): low, close camera; counted 0 before the arm thresholds were relaxed; 11 from #148 to #149 (the bell set down at the end, 29.22 s) |
| swing-hole-7reps | 8 | no | #94: a live set whose recording lost 12.68–14.88 s; 10 swings, 2 cut by the hole |
| swing-onearm-10reps | 10 | no | #97: ten one-arm swings with the upper arm on the ribs, arm peaks 37–49° at the top; counted 5, then 8; the first two since #148; the bell park at the end must not be a rep |
| swing-farcam-10reps | 10 | no (Muse: 10) | #139 (9283D45A): far camera behind the lifter, arms foreshortened, the float reads 30–38°; counted 1. The bell park (24.95 s) counted from #139 to #149 |
| swing-farcam-5tops | 5 | no (Muse) | #140 (CDC08BF2): same camera; the auto-trim (#141) cut the clip on the fifth top; counted 1 |

Reports: `TuningReports.testSwingTopArmSweep` (every swing fixture's and archived swing track's count per
`ballisticTopArmMin`; `SWING_TOP_HIP`, `SWING_BALLISTIC`, `SWING_MAX_REP` rerun it under other thresholds),
`TuningReports.testSwingWristRiseSweep` (the same rows per `wristTopRiseMin`, off first; `SWING_WRIST_ARM`
overrides `wristTopArmMin`), `TuningReports.testSwingHikeSweep` (the same rows per `hikeReleaseMax`, off first,
then every rep the default adds: where it sits and its angles), `TuningReports.testSwingUpswingReport` (the same
rows with the #149 rule off, as a post-filter, and in the analyzer, then every slow top: deepest→top,
release→top, arm, next hinge; `SWING_UPSWING`, `SWING_NEXT_HINGE`), `TuningReports.testSwingRepTraces`, `SwingThresholdSweep.testSwingThresholdSweep`, and
`TuningReports.testSwingSignals` (every frame's angles and phase for one archived track, `SWING_TRACK=<name>
SWING_FROM=12 SWING_TO=17`; a fixture name works too).

## Experiments

- **2026-09-12, swing-pickup-10reps (#4)**: an upswing that takes over a second is the lifter standing up from the
  bell, not a swing; `releaseMaxDuration` = 1.0 s. Reps over 4 s (walk-in, setup) discarded; unmeasured frames
  excluded from transitions (commits 6b74a93, 4344155).
- **2026-09-12, swing-lowcam-10reps (#16)**: arms read 80° behind the body and 45° in front from a low camera;
  `topArmMin` 40, `bottomArmMax` 75 (+15 margin). Count went 0 → 10, not yet confirmed by Igor (commit f3e7955).
- **2026-09-18, swing-hole-7reps (#94)**: a 22 s live set counted 6; tops at 4.97, 6.5, 8.0, 9.5, 11.0, 12.5,
  [14.0], 15.55, 17.1, 18.65 make 9 swings. The track has no frames from 12.68 to 14.88 s (the main thread hung
  2.65 s, the queued frames held the camera's buffers and the capture stopped delivering: 599 frames delivered,
  586 analyzed, in the recording as well as live). After the hole the machine was still in TOP from 12.5 s, took
  the upswing at 15.14 for CONNECT, and finished that rep at 16.81: 4.6 s from its top, discarded by
  `maxRepDuration`. With `maxFrameGap` the rep in progress is dropped at the hole and the next one starts at the
  top at 15.54: 6 → 7, spans 1.10–1.43 s, the other swing fixtures unchanged. The two swings in the hole have no
  poses and stay uncounted; the capture now logs `capture_gap` so the hole itself can be fixed from evidence
  (commit 7beca0c).
- **2026-09-12, detector**: swings with many arm cycles and slightly uneven legs (walk-in, diagonal camera) fell to
  "ambiguous"; see [detector.md](detector.md) (commit 8bc27b5).
- **2026-09-18, swing-onearm-10reps (#97)**: a 24 s one-arm set counted 5; the video has ten tops (5.1, 6.6, 8.1,
  9.7, 11.3, 12.8, 14.3, 15.9, 17.5, 19.1 s), bell at chest to head height. The upper arm stays on the ribs and the
  forearm lifts the bell, so shoulder→elbow peaks at only 37–49° at the top, and on both sides alike: the model
  puts the working wrist on the guard hand, so the two arms read the same. With `topArmMin` 40 the tops at 11.3 and
  19.1 (peaks 39° and 37°) never left RELEASE, and the machine then ran one phase late (the hinge labelled TOP,
  the real top labelled CONNECT), merging two swings into one 2.3 s rep. Lowering `topArmMin` alone
  (40/38/36/34/32/30/28: this set 5/7/9/9/9/9/9, the seven other fixtures unchanged) looked clean on the
  fixtures and was not: over the 28 archived swing tracks, 32 added a false last rep to three sets (F853A918
  10 → 11, 96FEBD60 9 → 10, FD1FCA37 17 → 18) and one to this set. All four are Igor parking the bell, standing
  up and walking to the phone with the arms a little forward, 33–37°, which overlaps the real tops (37–49°). Two
  things tell them apart. Speed: a real upswing passes the cut-off 0.10–0.27 s after RELEASE, the three parks
  0.57–0.9 s after, so the low cut-off applies only to a ballistic upswing (`ballisticTopArmMin` 32 within
  `ballisticReleaseMax` 0.4 s; `topArmMin` stays 40). `testSwingTopArmSweep`, window 0.3/0.4/0.5/0.6 s at 32°:
  this set 8/8/8/8, 73014BDE 6/8/8/8 (two real swings, 1.55 s rhythm), F853A918 10/10/10/11; at 28° F853A918 is
  11 at every window. Hip: this set's park stands up fast (0.14 s) but with hip 151–156°, real tops read ≥ 171°;
  `SWING_TOP_HIP` 150/160/166: this set 9/8/8, nothing else moves up to 166 (at 170 swing-lowcam loses a rep).
  `topHipMin` 150 → 160. Result: this set 5 → 8 (spans 1.17–1.47 s), 73014BDE 6 → 8, the other 7 fixtures and
  26 tracks unchanged. Also rejected: `maxRepDuration` 3 s (removes the parks, costs a first rep in eight sets).
  The two swings still missing: the first comes off the floor after 4.7 s of setup and is dropped by
  `maxRepDuration`, as in swing-pickup-10reps; the second goes with it, because standing up with the bell reads
  as CONNECT and the first top (5.1 s) is never a TOP, so no rep starts there. Rejected: abandoning a rep whose
  BOTTOM lasts over 1–2.5 s (removes the park, but swing-pickup 9 → 8 at every value and swing-lowcam 10 → 8–9:
  a held hike is a long bottom too); CONNECT → TOP when the pose is a top (recovers the second swing, 9 real
  reps, but swing-lowcam 10 → 3 and swing-pickup 9 → 10: foreshortened arms bounce across the cut-off). A
  shoulder→wrist angle would separate a top from hanging arms better, but the wrist here is mislabelled, so it
  was not tried. Not yet confirmed by Igor.
- **2026-09-26, swing-farcam-10reps / swing-farcam-5tops (#139, #140)**: two sets from the 09-25 session counted
  1 each. Frames show real swings (bell at chest height, arms straight out); Muse counts 10 and 5 tops (the second
  clip was cut by the auto-trim, #141). The camera is far (the lifter fills 22 % of the frame height) and behind
  him to one side, so the arms point away from it: standing-tall arm p90 33–34° against 41–47° for the sets of the
  same session that counted 9–10. The wrist, though, rises to 15–30 px below the shoulders in both. Lowering
  `ballisticTopArmMin` does not fix it (`testSwingTopArmSweep`: 30° gives 4 and 2, 28° gives 6 and 2, and
  F853A918 gains its park at both). New measure `BodySkeleton.wristRise`: wrist height over the torso length,
  scale-free (about -1 hanging, near 0 at chest height). First as an extra top rule at any speed
  (`testSwingWristRiseSweep`, arm > 20°, rise ≥ -0.7/-0.6/-0.5/-0.4/-0.3): the target sets recover (9283D45A
  1 → 10 at -0.7…-0.4, 8 at -0.3) but eight other tracks gain a rep at -0.5, among them the three known parks
  (F853A918, 96FEBD60, FD1FCA37). Limited to a ballistic upswing (within `ballisticReleaseMax`, like the #97
  rule), -0.4 moves nothing but the three far-camera sets: 9283D45A 1 → 10, CDC08BF2 1 → 4, 3BEF7CEF 0 → 2
  (a 9 s trimmed fragment starting mid-set, 4 tops by Muse); at -0.5 F853A918's park and two 09-16 sets
  (73014BDE, B69762F7) gain one. `wristTopRiseMin` -0.4, `wristTopArmMin` 20. Not yet confirmed by Igor.
- **2026-09-26, the first swing counts (#148)**: Igor's decision: the hike off the floor into the first top is a
  rep. Until now the first rep was timed from whatever top the machine began in (the walk-in, or no top at all:
  the machine starts in TOP), so after 4 s of setup it was discarded, and when the recording opened over the bell
  the hike's hip snap read as CONNECT and the first top was merged into the second swing (the #97 loss). Two
  rules make a *hike*: a rep in CONNECT or BOTTOM over `maxRepDuration` drops its setup positions and is timed
  again from there, and before any top is seen a hinge in TOP goes straight to BOTTOM. A hike counts when the
  arms reach the top within `hikeReleaseMax` of RELEASE. `testSwingHikeSweep` (off / 0.3 / 0.4 / 0.6 / 1.0 s):
  the ten fixtures read 4 / 9 / 13 / 9 / 9 / 10 / 7 / 8 / 10 / 4 off and 4 / 10 / 14 / 10 / 10 / 11 / 8 / 10 /
  11 / 5 at every value; of the 48 archived swing tracks, 5 do not move, 31 gain one, 11 gain two and FD1FCA37
  three. Every added rep was checked in the report: each is the first rep of its set (or the second, where the
  set opened over the bell), bottom hinged 48–79° with the hip at 47–109°, release hip 143–177°, top 0.10–0.30 s
  after the release, and the wrists float to within 0.32 torso lengths of the shoulders (-0.32…+0.11; hanging
  arms read about -1). The mid-recording ones are second sets: F677269B's rep 12 (the walk between its halves,
  then a hike from 31.5 s to a 57° top at 32.5 s) and FD1FCA37's rep 11 (hinged over the parked bell 31.6–37.9 s,
  hike, 63° top at 39.2 s). No set gains a rep at its end. The frames agree for swing-1h-9reps (over the bell
  on the floor to 1.75 s, bell at chest height at 2.75–3.0 s) and swing-phone-13reps (hand on the bell on the
  floor to 8.75 s, bell at chest height at 9.5–9.75 s): their humanVerified 9 and 13 were top-to-top, now 10
  and 14. First version: a far-camera fragment (3BEF7CEF) whose standing tops never read `topArmMin` gained a
  park at its end (hinge 6.3–8.2 s, a 0.33 s stand-up to 34°), because it had "never seen a top"; a completed
  rep now counts as a seen top, and it gains only its first swing (2 → 3). The window hardly matters (0.3–1.0 s
  give the same counts now); 0.4, the `ballisticReleaseMax` of #97, keeps the margin against a slow park.
  Pre-existing, not changed: swing-farcam-10reps' last rep (bottom 22.6–24.2 s, 0.73 s up to a 41° arm at
  24.95 s) is the bell park, counted since #139, so that fixture reads 11 for 10 swings. Not yet confirmed by
  Igor beyond swing-pickup-10reps (10).
- **2026-09-26, the bell set down is not a rep (#149)**: Igor's idea: "my back is up straight after a fast hip
  snap". Measured as the time from the deepest BOTTOM frame to the accepted top (Fable's study of eleven
  mechanisms, lab note `~/tmp/agent/notes/2026-09-26-offangle-top-brainstorm.md`, a Python port matched
  frame-for-frame on the 10 fixtures and 48 tracks): swings p50 0.43, p99 0.80, max 0.93 s (swing-lowcam rep 2);
  the stand-ups after setting the bell down 1.50–2.67 s; the hikes (#148) 1.14–3.90 s, because the lifter waits
  over the bell. Hike and set-down differ in what follows: the next hinge 0.83–1.07 s after a hike, none after a
  set-down (or 6.3–9.9 s: F677269B, FD1FCA37 mid-track rests). A plain 0.6 s gate on every top cost 73014BDE
  three swings (0.53–0.70 s); 0.8–1.2 s dropped the 13 set-downs and also ~17 hikes. Rhythm alone (a hinge must
  follow every top) drops the last rep of every clip that ends on a top (swing-4reps, swing-hole-7reps,
  swing-farcam-5tops). Rejected too: hip-snap velocity ≥ 230 °/s (the same idea, 15 % margin, a noisy
  derivative), release→upright time (0.00 s for F853A918's park), wrist speed, head height, an adaptive arm
  cut-off, a foreshortening-corrected arm, the bell clock, a camera-angle tell. Rule: `upswingMaxDuration` 1.0 s,
  `slowTopConfirmGap` 2.5 s; a slow top waits for CONNECT → BOTTOM and is dropped without one.
  `testSwingUpswingReport` (off / post-filter / in the analyzer, gap 2.0, 2.5 and 3.0 s alike, the analyzer equal
  to the post-filter on every set): 13 sets lose their last rep and nothing else moves: swing-lowcam-10reps
  11 → 10 and its archived copies 66FAD1F2, 9F8F947D (29.22 s, deepest→top 2.40 s, release→top 0.90 s, arm 40°)
  and 71AD553F (22.79 s), swing-farcam-10reps and 9283D45A 11 → 10 (24.95 s, 2.17, 0.70, 41°), 2AFB645A 11 → 10
  (23.29 s, 2.67, 0.97, 44°), F677269B 22 → 21 (49.57 s, 2.20, 0.67, 47°), 3C84C789 11 → 10 (22.12 s, 1.50, 0.47,
  54°), 3E4637F5 12 → 11 (24.09 s, 2.30, 0.47, 41°), 81A34E3F 11 → 10 (22.12 s, 1.93, 0.27, 34°), 5CB9B81F
  12 → 11 (23.83 s, 2.13, 0.33, 36°), E3FA2336 11 → 10 (22.59 s, 2.07, 0.10, 46°). All 17 hikes are kept (the
  first rep of 15 sets and the second-set hikes of F677269B and FD1FCA37); swing-4reps 4, swing-hole-7reps 8 and
  swing-farcam-5tops 5 keep their last rep. Muse looked at the video of 8 of the dropped tops (5CB9B81F, 71AD553F,
  3E4637F5, 81A34E3F, 3C84C789, E3FA2336, 9283D45A, 2AFB645A): all set-downs, high confidence
  (`~/tmp/agent/image/2026-09-26-parks/`); the lowcam source (66FAD1F2/9F8F947D) and F677269B have no local clip.
  Live, a slow top is counted at the next hinge, about a second after it: in practice the first swing of a set.
  Not yet confirmed by Igor.
- **2026-09-28, review (no fixture; [#171](https://github.com/idvorkin/exercise-analyzer/issues/171))**: the knee is
  not part of `measured`, so one frame with an unmeasured knee (0°) in a rep set `maxKneeFlexion` to 175 and the
  score said "Hinge, don't squat" (−15); `testSwingRepTraces` shows kneeFlex ≤ 72 on every fixture rep, so it had
  not fired there. 0 is now ignored. Counts unchanged. AnalysisVersion 2026-09-28.1.
