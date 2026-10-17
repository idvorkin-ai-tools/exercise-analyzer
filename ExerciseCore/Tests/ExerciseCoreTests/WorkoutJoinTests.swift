// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  #238, story 048: a workout started under 30 minutes after one ended is part of that session while it runs,
//  as it is once it ends (#169): the phone shows one workout from the first start, not a second one.

import XCTest

@testable import ExerciseCore

final class WorkoutJoinTests: XCTestCase {
  private func date(_ t: Double) -> Date { Date(timeIntervalSince1970: t) }

  /// Oct 8: End at 16:04:35 after 24 min, 11 sets, 102 reps; Start again 64 s later.
  private let first = StoredWorkout(
    id: "first", start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 1440),
    heartRateAverage: 130, heartRateMax: 160, sets: 11, reps: 102)

  func testARunningWorkoutUnderHalfAnHourAfterAnEndJoinsThatSession() {
    let index = WorkoutIndex(workouts: [first])
    let live = WorkoutWire(startedAt: 1504, heartRate: 120, heartRateAverage: 110, heartRateMax: 150, sets: 2, reps: 4)
    let joined = index.joining(live, now: date(1504 + 480))
    XCTAssertEqual(joined.sessions, [], "the ended session is the running one now")
    let shown = joined.live
    XCTAssertEqual(shown?.startDate, first.start)
    XCTAssertEqual(shown?.sets, 13)
    XCTAssertEqual(shown?.reps, 106)
    XCTAssertEqual(shown?.heartRate, 120)
    XCTAssertEqual(shown?.heartRateMax, 160)
    // 1440 s at 130 and 480 s at 110, by time.
    XCTAssertEqual(shown?.heartRateAverage, 125)
  }

  /// Once it ends, the saved pair is the same session the running one was: the page keeps its identity.
  func testTheJoinedStartIsTheStartOfTheSessionItBecomes() {
    let live = WorkoutWire(startedAt: 1504, sets: 2, reps: 4)
    let shownStart = WorkoutIndex(workouts: [first]).joining(live, now: date(2000)).live?.startDate
    let saved = WorkoutIndex(workouts: [
      first, StoredWorkout(id: "second", start: date(1504), end: date(1984), sets: 2, reps: 4),
    ])
    XCTAssertEqual(saved.sessions().map(\.start), [shownStart])
  }

  func testNoJoinAfterHalfAnHourOrWithNothingRunning() {
    let index = WorkoutIndex(workouts: [first])
    let late = WorkoutWire(startedAt: 1440 + 1800, sets: 1, reps: 5)
    let apart = index.joining(late, now: date(4000))
    XCTAssertEqual(apart.live, late)
    XCTAssertEqual(apart.sessions, [first])
    let idle = index.joining(nil, now: date(4000))
    XCTAssertNil(idle.live)
    XCTAssertEqual(idle.sessions, [first])
  }
}
