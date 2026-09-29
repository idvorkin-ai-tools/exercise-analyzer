// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  #121: the Workouts list remembers the days the lifter folded or opened, across launches.

import XCTest

@testable import ExerciseCore

final class DayFoldsTests: XCTestCase {
  func testDaysStartFoldedOnlyWhenOlderThanAWeek() {
    let folds = DayFolds()
    XCTAssertTrue(folds.isFolded("2026-09-01", olderThanAWeek: true))
    XCTAssertFalse(folds.isFolded("2026-09-28", olderThanAWeek: false))
  }

  func testAChoiceByHandSurvivesARelaunch() {
    var folds = DayFolds()
    folds.set("2026-09-28", folded: true)
    folds.set("2026-09-01", folded: false)
    let relaunched = DayFolds(stored: folds.stored)
    XCTAssertTrue(relaunched.isFolded("2026-09-28", olderThanAWeek: false))
    XCTAssertFalse(relaunched.isFolded("2026-09-01", olderThanAWeek: true))
  }

  /// Folding a recent day and opening it again is remembered as open, not dropped as the default.
  func testFoldThenOpenIsRememberedAsOpen() {
    var folds = DayFolds()
    folds.set("2026-09-28", folded: true)
    folds.set("2026-09-28", folded: false)
    XCTAssertEqual(DayFolds(stored: folds.stored).choices, ["2026-09-28": false])
  }

  /// A day a week on: opened by hand while recent, it stays open once it is old enough to start folded.
  func testAnOpenedDayStaysOpenAsItAges() {
    var folds = DayFolds()
    folds.set("2026-09-28", folded: true)
    folds.set("2026-09-28", folded: false)
    XCTAssertFalse(folds.isFolded("2026-09-28", olderThanAWeek: true))
    folds.set("2026-09-20", folded: false)
    XCTAssertFalse(folds.isFolded("2026-09-20", olderThanAWeek: true))
  }

  func testAnUnreadableStoreIsNoChoices() {
    XCTAssertEqual(DayFolds(stored: "not json"), DayFolds())
    XCTAssertEqual(DayFolds(stored: ""), DayFolds())
  }
}
