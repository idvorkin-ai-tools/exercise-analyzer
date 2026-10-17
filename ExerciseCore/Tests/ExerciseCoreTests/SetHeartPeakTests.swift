// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  #195, story 050: the wrist's rest head shows how far the heart has come down from the last recorded set's peak.

import XCTest

@testable import ExerciseCore

final class SetHeartPeakTests: XCTestCase {
  private func date(_ t: Double) -> Date { Date(timeIntervalSince1970: t) }

  /// The peak is the highest reading from Record to 30 s after Done; the drop is that peak minus the reading now.
  func testTheDropIsFromTheSetsPeakIncludingTheLagAfterDone() {
    var peak = SetHeartPeak()
    peak.reading(110, at: date(990))  // before Record: not the set's
    peak.recordStarted(at: date(1000))
    peak.reading(140, at: date(1010))
    peak.setEnded(at: date(1025))
    peak.reading(157, at: date(1040))  // the heart lags the work: 15 s after Done still counts
    peak.reading(165, at: date(1060))  // 35 s after Done: the rest, not the set
    XCTAssertEqual(peak.peak, 157)
    XCTAssertEqual(peak.drop(now: 128), 29)
  }

  /// Before the first recorded set, while a set records, and when the heart has not come down, there is no drop.
  func testNoDropBeforeTheFirstSetWhileRecordingOrAboveThePeak() {
    var peak = SetHeartPeak()
    peak.reading(120, at: date(990))
    XCTAssertNil(peak.drop(now: 100))
    peak.recordStarted(at: date(1000))
    peak.reading(150, at: date(1010))
    XCTAssertNil(peak.drop(now: 140))
    peak.setEnded(at: date(1020))
    XCTAssertEqual(peak.drop(now: 140), 10)
    XCTAssertNil(peak.drop(now: 150))
    XCTAssertNil(peak.drop(now: 155))
    XCTAssertNil(peak.drop(now: nil))
  }

  /// The next Record starts a new peak; a set with no reading at all leaves none.
  func testTheNextRecordStartsANewPeak() {
    var peak = SetHeartPeak()
    peak.recordStarted(at: date(1000))
    peak.reading(160, at: date(1010))
    peak.setEnded(at: date(1020))
    peak.recordStarted(at: date(1200))
    peak.setEnded(at: date(1220))
    XCTAssertNil(peak.peak)
    peak.reading(130, at: date(1230))
    XCTAssertEqual(peak.peak, 130)
    peak.reset()
    XCTAssertNil(peak.drop(now: 100))
  }
}
