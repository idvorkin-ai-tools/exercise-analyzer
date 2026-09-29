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
    folds.set("2026-09-28", folded: true, olderThanAWeek: false)
    folds.set("2026-09-01", folded: false, olderThanAWeek: true)
    let relaunched = DayFolds(stored: folds.stored)
    XCTAssertTrue(relaunched.isFolded("2026-09-28", olderThanAWeek: false))
    XCTAssertFalse(relaunched.isFolded("2026-09-01", olderThanAWeek: true))
  }

  /// Folding back to the default forgets the day, so only real choices are kept.
  func testAChoiceBackToTheDefaultIsForgotten() {
    var folds = DayFolds()
    folds.set("2026-09-28", folded: true, olderThanAWeek: false)
    folds.set("2026-09-28", folded: false, olderThanAWeek: false)
    XCTAssertEqual(folds.choices, [:])
  }

  /// A day a week on: opened by hand while recent, it stays open once it is old enough to start folded.
  func testAnOpenedDayStaysOpenAsItAges() {
    var folds = DayFolds()
    folds.set("2026-09-28", folded: true, olderThanAWeek: false)
    folds.set("2026-09-28", folded: false, olderThanAWeek: false)
    XCTAssertTrue(folds.isFolded("2026-09-28", olderThanAWeek: true))  // no choice kept: the age rule decides
    folds.set("2026-09-20", folded: false, olderThanAWeek: true)
    XCTAssertFalse(folds.isFolded("2026-09-20", olderThanAWeek: true))
  }

  func testAnUnreadableStoreIsNoChoices() {
    XCTAssertEqual(DayFolds(stored: "not json"), DayFolds())
    XCTAssertEqual(DayFolds(stored: ""), DayFolds())
  }
}
