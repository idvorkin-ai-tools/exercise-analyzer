// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  #238, story 048: Start within 10 minutes of an End asks to continue that workout; Continue shows the wrist
//  the earlier clock and sets on top of the new session's own.

import XCTest

@testable import ExerciseCore

final class WorkoutCarryTests: XCTestCase {
  private func date(_ t: Double) -> Date { Date(timeIntervalSince1970: t) }

  private var ended: WorkoutCarry {
    WorkoutCarry(
      start: date(0), end: date(1440), sets: 11, reps: 102,
      exerciseSets: [.kettlebellSwing: 9, .pistolSquat: 2], exerciseOrder: [.kettlebellSwing, .pistolSquat])
  }

  /// Asked only within 10 minutes of the End.
  func testTheAskIsOfferedForTenMinutesAfterTheEnd() {
    XCTAssertTrue(ended.offered(at: date(1440 + 64)))
    XCTAssertTrue(ended.offered(at: date(1440 + 599)))
    XCTAssertFalse(ended.offered(at: date(1440 + 600)))
    XCTAssertFalse(ended.offered(at: date(1400)), "a clock that went back")
  }

  func testTheQuestionSaysHowLongAgo() {
    XCTAssertEqual(ended.question(at: date(1440 + 64)), "Continue the workout that ended 1 min ago?")
    XCTAssertEqual(ended.question(at: date(1440 + 20)), "Continue the workout that ended just now?")
  }

  /// The wrist shows both parts: the carried sets first, the new exercises after them.
  func testContinueShowsTheEarlierSetsWithTheNewOnes() {
    let shown = ended.adding(
      sets: 2, reps: 4, exerciseSets: [.turkishGetUp: 2], exerciseOrder: [.turkishGetUp])
    XCTAssertEqual(shown.sets, 13)
    XCTAssertEqual(shown.reps, 106)
    XCTAssertEqual(shown.exerciseOrder, [.kettlebellSwing, .pistolSquat, .turkishGetUp])
    XCTAssertEqual(shown.exerciseSets, [.kettlebellSwing: 9, .pistolSquat: 2, .turkishGetUp: 2])
    let again = ended.adding(
      sets: 1, reps: 10, exerciseSets: [.kettlebellSwing: 1], exerciseOrder: [.kettlebellSwing])
    XCTAssertEqual(again.exerciseSets[.kettlebellSwing], 10)
    XCTAssertEqual(again.exerciseOrder, [.kettlebellSwing, .pistolSquat])
  }

  /// Kept on the wrist across a relaunch.
  func testItRoundTrips() throws {
    let data = try JSONEncoder().encode(ended)
    XCTAssertEqual(try JSONDecoder().decode(WorkoutCarry.self, from: data), ended)
  }
}
