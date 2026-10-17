// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  #265, story 073: the row of drawings and the video diamond above the day list keep only the days that match.

import XCTest

@testable import ExerciseCore

final class DayFilterTests: XCTestCase {
  /// The row holds the exercises in my history, in the order they last appeared (newest day first), once each.
  func testTheRowIsTheHistoryInTheOrderTheyLastAppeared() {
    let newestFirst: [[ExerciseKind]] = [
      [.kettlebellSwing], [.pistolSquat, .kettlebellSwing], [.turkishGetUp], [.kettlebellSwing],
    ]
    XCTAssertEqual(DayFilter.row(newestFirst), [.kettlebellSwing, .pistolSquat, .turkishGetUp])
  }

  func testNoFilterKeepsEveryDay() {
    let filter = DayFilter()
    XCTAssertFalse(filter.isActive)
    XCTAssertTrue(filter.keeps(exercises: [.kettlebellSwing], allOnVideo: false))
    XCTAssertTrue(filter.keeps(exercises: [], allOnVideo: false))  // a workout with no set on camera
  }

  func testAnExerciseKeepsOnlyItsDays() {
    let filter = DayFilter(exercise: .pistolSquat)
    XCTAssertTrue(filter.keeps(exercises: [.kettlebellSwing, .pistolSquat], allOnVideo: false))
    XCTAssertFalse(filter.keeps(exercises: [.kettlebellSwing], allOnVideo: true))
  }

  func testTheDiamondKeepsOnlyTheDaysAllOnVideo() {
    let filter = DayFilter(onVideo: true)
    XCTAssertTrue(filter.keeps(exercises: [.kettlebellSwing], allOnVideo: true))
    XCTAssertFalse(filter.keeps(exercises: [.kettlebellSwing], allOnVideo: false))
  }

  func testBothTogetherNarrowFurther() {
    let filter = DayFilter(exercise: .pistolSquat, onVideo: true)
    XCTAssertTrue(filter.keeps(exercises: [.pistolSquat], allOnVideo: true))
    XCTAssertFalse(filter.keeps(exercises: [.pistolSquat], allOnVideo: false))
    XCTAssertFalse(filter.keeps(exercises: [.kettlebellSwing], allOnVideo: true))
  }

  /// A second tap on the picked drawing shows every day again; a tap on another drawing switches to it.
  func testASecondTapClears() {
    var filter = DayFilter()
    filter.tap(.pistolSquat)
    XCTAssertEqual(filter.exercise, .pistolSquat)
    filter.tap(.kettlebellSwing)
    XCTAssertEqual(filter.exercise, .kettlebellSwing)
    filter.tap(.kettlebellSwing)
    XCTAssertNil(filter.exercise)
    filter.onVideo.toggle()
    filter.onVideo.toggle()
    XCTAssertFalse(filter.isActive)
  }
}
