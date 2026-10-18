// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  #83, story 049: a set done in two halves (ten one side, a walk, ten the other) trims to each run of reps, the
//  gap between them cut. The numbers are Igor's 2026-09-16 set: reps 1–10 at 5.4–19.9 s, reps 11–20 at
//  32.6–48.9 s, 51 s of clip.

import CoreGraphics
import XCTest

@testable import ExerciseCore

final class TrimRunsTests: XCTestCase {
  private let pose = Pose(
    xyn: [PosePoint](repeating: PosePoint(x: 0.5, y: 0.5), count: 17), conf: [Float](repeating: 0.9, count: 17),
    imageSize: CGSize(width: 1080, height: 1920))

  private func rep(_ number: Int, _ start: Double, _ end: Double) -> RepRecord {
    RepRecord(
      number: number,
      positions: [
        "start": RepPosition(phase: "start", time: start, pose: pose, metrics: [:], score: 0, image: nil),
        "end": RepPosition(phase: "end", time: end, pose: pose, metrics: [:], score: 0, image: nil),
      ],
      quality: RepQuality(score: 0, metrics: [:], feedback: []))
  }

  /// Reps of 1.45 s from `start`, back to back: `count` of them, numbered from `first`.
  private func run(from start: Double, count: Int, first: Int) -> [RepRecord] {
    (0..<count).map { i in rep(first + i, start + Double(i) * 1.45, start + Double(i + 1) * 1.45) }
  }

  private func pipeline(_ reps: [RepRecord], seconds: Double = 51) -> AnalysisPipeline {
    let frames = (0..<Int(seconds * 10)).map { i in
      FrameRecord(
        time: Double(i) / 10, imageSize: CGSize(width: 1080, height: 1920), pose: nil, box: nil, analysis: nil)
    }
    return AnalysisPipeline.restored(frames: frames, reps: reps, exercise: .kettlebellSwing)
  }

  private var twoHalves: AnalysisPipeline {
    pipeline(run(from: 5.4, count: 10, first: 1) + run(from: 32.6, count: 10, first: 11))
  }

  /// The clip's ends keep today's 5 s; each side of the cut keeps 1 s, so 10.7 of the 12.7 s walk goes.
  func testTwoHalvesTrimToTwoRuns() {
    let runs = twoHalves.repRuns(padding: 5, joinPadding: 1, gap: 6, duration: 51)
    XCTAssertEqual(runs.count, 2)
    XCTAssertEqual(runs[0].start, 0.4, accuracy: 0.001)
    XCTAssertEqual(runs[0].end, 20.9, accuracy: 0.001)
    XCTAssertEqual(runs[1].start, 31.6, accuracy: 0.001)
    XCTAssertEqual(runs[1].end, 51, accuracy: 0.001)  // 47.1 + 5, clipped to the clip
  }

  /// No gap past the threshold: the one span today's trim keeps.
  func testOneRunIsTodaysTrim() {
    let set = pipeline(run(from: 5.4, count: 20, first: 1))
    let runs = set.repRuns(padding: 5, joinPadding: 1, gap: 6, duration: 51)
    XCTAssertEqual(runs.count, 1)
    let span = set.repSpan(padding: 5, duration: 51)
    XCTAssertEqual(runs[0].start, span?.start)
    XCTAssertEqual(runs[0].end, span?.end)
  }

  /// A rest under the threshold is part of the set: 4 s between two runs keeps one span.
  func testAShortRestStaysOneRun() {
    let set = pipeline(run(from: 5, count: 5, first: 1) + run(from: 16.25, count: 5, first: 6))
    XCTAssertEqual(set.repRuns(padding: 5, joinPadding: 1, gap: 6, duration: 51).count, 1)
  }

  func testNoRepsNoRuns() {
    XCTAssertTrue(pipeline([]).repRuns(padding: 5, joinPadding: 1, gap: 6, duration: 51).isEmpty)
  }

  /// The joined clip plays the runs back to back: the second run's frames and reps follow the first's end, the
  /// walk between is gone, and the rep numbers run on across the join.
  func testJoiningRetimesTheSecondRunOntoTheFirstsEnd() {
    let joined = twoHalves.joined(spans: [(start: 3.4, end: 21.9), (start: 30.6, end: 49.1)])
    XCTAssertEqual(joined.reps.map(\.number), Array(1...20))
    XCTAssertEqual(joined.reps[0].startTime, 2.0, accuracy: 0.001)
    // Rep 11 started at 32.6 s, 2 s into the second run, which begins where the first ends (18.5 s in).
    XCTAssertEqual(joined.reps[10].startTime, 18.5 + 2.0, accuracy: 0.001)
    let times = joined.track.frames.map(\.time)
    XCTAssertEqual(times, times.sorted())
    XCTAssertLessThanOrEqual(times.last ?? 0, 37.0 + 0.001)
    XCTAssertFalse(joined.track.frames.isEmpty)
  }

  /// One span is today's shift.
  func testJoiningOneSpanIsShifting() {
    let set = twoHalves
    let joined = set.joined(spans: [(start: 3.4, end: 49.1)])
    let shifted = set.shifted(toStartAt: 3.4, end: 49.1)
    XCTAssertEqual(joined.reps.map(\.startTime), shifted.reps.map(\.startTime))
    XCTAssertEqual(joined.track.frames.map(\.time), shifted.track.frames.map(\.time))
  }
}
