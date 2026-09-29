// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  The workout rows the phone keeps for story 048 (#82): the index round-trips, a day finds its workouts, and
//  a set's time says whether it belongs to a workout.

import XCTest

@testable import ExerciseCore

final class WorkoutTests: XCTestCase {
  /// A fixed zone: the dates below are the same instants on every machine.
  private let calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
  }()

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
    // A workout left running for two days still gets about four ticks, on whole hours.
    let long = ElapsedAxis.ticks(window: 0...158_400)
    XCTAssertLessThanOrEqual(long.count, 5)
    XCTAssertTrue(long.allSatisfy { $0.truncatingRemainder(dividingBy: 3600) == 0 })
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

  /// #169: workouts under 30 minutes apart are one session; a longer gap starts a new one.
  func testWorkoutsUnderHalfAnHourApartAreOneSession() {
    let index = WorkoutIndex(workouts: [
      StoredWorkout(id: "b", start: date(16, 7, 48), end: date(16, 7, 50), heartRateAverage: 150, heartRateMax: 170, sets: 1, reps: 8),
      StoredWorkout(id: "a", start: date(16, 7, 0), end: date(16, 7, 30), heartRateAverage: 120, heartRateMax: 150, sets: 4, reps: 30),
      StoredWorkout(id: "c", start: date(16, 7, 51), end: date(16, 7, 54), sets: 1, reps: 5),
      StoredWorkout(id: "evening", start: date(16, 18), end: date(16, 19), sets: 2, reps: 20),
    ])
    let sessions = index.sessions()
    XCTAssertEqual(sessions.map(\.id), ["a", "evening"])
    let morning = sessions[0]
    XCTAssertEqual(morning.start, date(16, 7, 0))
    XCTAssertEqual(morning.end, date(16, 7, 54))
    XCTAssertEqual(morning.sets, 6)
    XCTAssertEqual(morning.reps, 43)
    XCTAssertEqual(morning.heartRateMax, 170)
    // 30 min at 120 and 2 min at 150, weighted by time; c has no heart rate and does not count.
    XCTAssertEqual(morning.heartRateAverage, 122)
    XCTAssertEqual(sessions[1], index.workouts[3])
    // Exactly 30 minutes apart is two sessions.
    let apart = WorkoutIndex(workouts: [
      StoredWorkout(id: "x", start: date(16, 9), end: date(16, 9, 30)), StoredWorkout(id: "y", start: date(16, 10), end: date(16, 10, 5)),
    ])
    XCTAssertEqual(apart.sessions().map(\.id), ["x", "y"])
  }

  /// #169: a page opened on a workout that then merged into a session (the live one saved within 30 minutes of the
  /// last) finds the session.
  func testAPageFindsTheSessionItsWorkoutMergedInto() {
    let session = StoredWorkout(id: "a", start: date(16, 7, 0), end: date(16, 7, 54))
    XCTAssertEqual(WorkoutIdentity(start: date(16, 7, 48)).resolve(live: nil, saved: [session], now: date(16, 8)), session)
    XCTAssertEqual(WorkoutIdentity(start: date(16, 7, 0)).resolve(live: nil, saved: [session], now: date(16, 8)), session)
    XCTAssertNil(WorkoutIdentity(start: date(16, 8, 30)).resolve(live: nil, saved: [session], now: date(16, 9)))
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
