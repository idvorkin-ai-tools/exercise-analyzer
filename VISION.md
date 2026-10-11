# Vision

`exercise-analyzer` exists so that a lifter training alone gets a better watch app to run the session, a lifting coach whenever there is video, and a clear account of what happened afterwards.
It is for one lifter, Igor, at the gym with his phone on a stand, an Apple Watch on his wrist and music playing, and with his iPad afterwards to review the workout.
It turns the video of a set and the watch's heart rate into counted, scored reps, a picture of the whole workout, and reps he can show to others.
It owns exactly one thing: the lifter's record of sets, each rep counted, tied to its video when there is one, and placed in its workout.

## As automatic as it can be

The app gathers every fact it can with as little input from the lifter as possible: the count, the exercise, the bell's weight, the workout.
When it cannot measure something, the lifter types it, and what he types always replaces and overrides what was measured.

## The watch is the interface

At the gym, the watch runs the session: preview, record, pause, done, camera, rest timer and sets typed by hand.
Recording starts and stops on the lifter's tap; it does not guess when a set begins.
A workout can run from the watch alone, with no phone at the gym, and joins the record afterwards.
The phone stays on its stand; controls are few and large, and the HUD sits on the video.
The app never interrupts the lifter's music, and it does not speak over it.
One gym visit is one workout, saved to Apple Health: two workouts started back to back merge into one, and when the watch and the phone lose each other the set, the count and the workout survive the gap.
The watch records its motion during sets, so a watch-only rep count can be tried against the lifter's own labelled sets.

## With video, a lifting coach

During a recording, the phone on its stand shows the count and the frame across the room.
Each rep is counted and given a form score with its reasons by an analyzer written for that exercise, and every rule in it is tested against real recorded pose tracks.
A wrong count is fixed by turning that set's pose track into a failing fixture first, never by tuning on the phone, and a fixture is human-verified only when Igor confirmed the count.
A new rule or model states its prediction, runs on the Mac against fixtures, and ships only when the numbers say so; a rejected idea keeps its numbers in the analysis notes.
An analyzer change bumps the analysis version, so every stored set re-reads itself.
An optional model, like the kettlebell detector, stays off by default until it pays for its cost.
A cloud vision model's form feedback on a clip the lifter chooses is welcome, as a coach's opinion shown beside the tested score, never in place of it.

## Reviewing: see what happened

After the workout, review works on the phone and is best on the iPad, which is never the recording screen.
Replay shows the skeleton, the angles, the phases and the heart rate at the playhead, and puts the same moment of every rep side by side.
The whole workout is one timeline: heart rate, sets, rests and recovery.
A set's reps can be shown to others as clean footage, trimmed to the reps, without the skeleton burned in, and a public link to them can come later.

## Without video: the workout at a glance

Video is optional: a workout-only mode tracks sets and heart rate without the camera.
On the phone, away from a recording, the workouts read at a glance: days, exercises by their drawings, sets, rests and heart rate.
The same record is on every one of the lifter's devices.

## The lifter's video and data stay the lifter's

Recordings go to Photos, in an album of their own, and clips filmed before the app was installed open from Photos or Files; the app points at them rather than hoarding copies.
Trim is lossless and keeps HDR.
Pose analysis runs on the device, and footage leaves it only when the lifter sends it.
Losing a set, a clip or its only copy is the worst class of bug, and deletes, undo and sync say what they remove before they remove it.
Sync between the lifter's devices runs through his own iCloud, the later change winning.

## Built from evidence

The user stories are the spec: a feature exists when its story says so, with a Status line naming its commit and the rung that verified it.
A purely visual change that alters no behaviour ships without a story edit.
A change is verified on the cheapest rung that can see it; a phone-only symptom gets a log event and pulled logs before any fix.
Bug reporting belongs to BugKit, and the architecture moves by small host-tested steps rather than a rewrite.

## Scope

It is for Igor, not for others: it is not headed for the App Store, and other lifters' needs do not shape it.
An exercise gets an analyzer when Igor starts doing it, not before; it is not a general fitness tracker, and until an analyzer holds on real fixtures the exercise is typed by hand.
It is not a cloud service: there is no backend and no account.
It is not a video editor beyond trimming around the reps and saving clean footage.

A change aligns when it keeps the session on the wrist, gathers more with less input from the lifter, makes the coach's count and scores more trustworthy on real fixtures, or shows the lifter more clearly what happened.
A change should be resisted when it sends the lifter back to the phone mid-session or adds a small target or setup step at the gym, overrides what the lifter typed, tunes by feel, sends footage off the device without the lifter choosing to, builds for lifters other than Igor, or risks the only copy of a set.
