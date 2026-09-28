// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  The workout rows the phone keeps for story 048 (#82): the index round-trips, a day finds its workouts, and
//  a set's time says whether it belongs to a workout.

import XCTest

@testable import ExerciseCore

final class WorkoutTests: XCTestCase {
  private let calendar = Calendar(identifier: .gregorian)

  /// #165: the chart's axis is time into the workout.
  func testTheChartAxisCountsFromTheWorkoutsStart() {
    // A 48-minute workout: ticks every 15 min.
    XCTAssertEqual(ElapsedAxis.ticks(window: 0...2880), [0, 900, 1800, 2700])
    XCTAssertEqual(
      ElapsedAxis.ticks(window: 0...2880).map { ElapsedAxis.label($0, fine: false) }, ["0", "15 min", "30 min", "45 min"])
    // Zoomed to 90 s starting 12 min in: ticks every 30 s, labelled with seconds.
    let zoomed = ElapsedAxis.ticks(window: 720...810)
    XCTAssertEqual(zoomed, [720, 750, 780, 810])
    XCTAssertTrue(ElapsedAxis.isFine(zoomed))
    XCTAssertEqual(zoomed.map { ElapsedAxis.label($0, fine: true) }, ["12:00", "12:30", "13:00", "13:30"])
    // A long workout reads in hours.
    XCTAssertEqual(ElapsedAxis.label(4500, fine: false), "1 h 15 min")
    XCTAssertEqual(ElapsedAxis.label(3600, fine: false), "1 h")
    XCTAssertFalse(ElapsedAxis.isFine(ElapsedAxis.ticks(window: 0...2880)))
  }

  /// #161: the Live Activity takes a new set or rep at once, heart rate only every 30 s, nothing unchanged.
  func testTheGlanceFollowsSetsAtOnceAndHeartRateEveryThirtySeconds() {
    let t0 = Date(timeIntervalSince1970: 1000)
    let shown = WorkoutGlance(heartRate: 120, sets: 6, reps: 47)
    XCTAssertTrue(WorkoutGlance.shouldShow(shown, over: nil, shownAt: t0, now: t0))
    XCTAssertFalse(WorkoutGlance.shouldShow(shown, over: shown, shownAt: t0, now: t0.addingTimeInterval(300)))
    let beat = WorkoutGlance(heartRate: 131, sets: 6, reps: 47)
    XCTAssertFalse(WorkoutGlance.shouldShow(beat, over: shown, shownAt: t0, now: t0.addingTimeInterval(29)))
    XCTAssertTrue(WorkoutGlance.shouldShow(beat, over: shown, shownAt: t0, now: t0.addingTimeInterval(30)))
    let set = WorkoutGlance(heartRate: 131, sets: 7, reps: 55)
    XCTAssertTrue(WorkoutGlance.shouldShow(set, over: shown, shownAt: t0, now: t0.addingTimeInterval(1)))
    XCTAssertEqual(
      WorkoutGlance(WorkoutWire(startedAt: 0, heartRate: 99, sets: 2, reps: 17)),
      WorkoutGlance(heartRate: 99, sets: 2, reps: 17))
  }

  private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
  }

  func testIndexRoundTripsThroughItsFile() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    XCTAssertEqual(WorkoutIndex.load(root: root), WorkoutIndex())  // no file yet reads as empty
    let index = WorkoutIndex(workouts: [
      StoredWorkout(id: "a", start: date(16, 9, 2), end: date(16, 10), heartRateAverage: 128, heartRateMax: 156, sets: 6, reps: 47)
    ])
    try index.save(root: root)
    XCTAssertEqual(WorkoutIndex.load(root: root), index)
  }

  func testADayFindsItsWorkoutsInStartOrder() {
    let index = WorkoutIndex(workouts: [
      StoredWorkout(id: "later", start: date(16, 17), end: date(16, 18)),
      StoredWorkout(id: "morning", start: date(16, 9, 2), end: date(16, 10)),
      StoredWorkout(id: "yesterday", start: date(15, 9), end: date(15, 10)),
    ])
    XCTAssertEqual(index.workouts(on: date(16, 13), calendar: calendar).map(\.id), ["morning", "later"])
    XCTAssertEqual(index.workouts(on: date(14, 13), calendar: calendar), [])
  }

  func testASetBelongsToTheWorkoutThatCoversItsTime() {
    let workout = StoredWorkout(start: date(16, 9, 2), end: date(16, 10))
    XCTAssertTrue(workout.contains(date(16, 9, 18)))
    XCTAssertFalse(workout.contains(date(16, 10, 5)))
    XCTAssertEqual(workout.duration, 58 * 60)
  }

  func testWireDecodesWithoutTheOptionalHeartRate() throws {
    let data = Data(#"{"startedAt":1789000000,"sets":0,"reps":0,"ending":false,"discarded":false}"#.utf8)
    let wire = try JSONDecoder().decode(WorkoutWire.self, from: data)
    XCTAssertNil(wire.heartRate)
    XCTAssertEqual(wire.startDate, Date(timeIntervalSince1970: 1_789_000_000))
  }
}
