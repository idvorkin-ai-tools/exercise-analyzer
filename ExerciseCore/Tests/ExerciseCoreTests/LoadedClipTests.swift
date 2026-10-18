//  #176, step 5a: the clip on screen is one value, so a trim and its undo move its fields together.

import XCTest

@testable import ExerciseCore

final class LoadedClipTests: XCTestCase {
  private let original = URL(fileURLWithPath: "/clips/original.mov")
  private let cut = URL(fileURLWithPath: "/tmp/trimmed.mov")
  private let started = Date(timeIntervalSince1970: 1_000)

  private var recorded: LoadedClip<String> {
    LoadedClip(url: original, origin: "recording", entryID: "set", recordedAt: started, startedAt: started)
  }

  private func untrimmed(of clip: LoadedClip<String>) -> LoadedClip<String>.Untrimmed {
    .init(
      url: clip.url, pipeline: .restored(frames: [], reps: [], exercise: .kettlebellSwing), frames: [],
      origin: clip.origin, startedAt: clip.startedAt)
  }

  func testATrimPlaysTheCutAndMovesTheFirstFrame() {
    var clip = recorded
    clip.trimmed(to: cut, start: 4.5, joined: false)
    XCTAssertEqual(clip.playing, cut)
    XCTAssertEqual(clip.url, original)
    XCTAssertEqual(clip.startedAt, started.addingTimeInterval(4.5))
  }

  func testAJoinedTrimHasNoFirstFrameTime() {
    var clip = recorded
    clip.trimmed(to: cut, start: 4.5, joined: true)
    XCTAssertNil(clip.startedAt)
  }

  func testAnImportedClipStaysWithoutAClock() {
    var clip = LoadedClip(url: original, origin: "file", entryID: nil, recordedAt: nil, startedAt: nil)
    clip.trimmed(to: cut, start: 4.5, joined: false)
    XCTAssertNil(clip.startedAt)
  }

  func testUndoPutsTheOriginalBackAndNamesTheDroppedCut() {
    var clip = recorded
    let before = untrimmed(of: clip)
    clip.untrimmed = before
    clip.trimmed(to: cut, start: 4.5, joined: false)
    clip.origin = "photos"
    XCTAssertEqual(clip.undo(to: before), cut)
    XCTAssertEqual(clip.playing, original)
    XCTAssertNil(clip.trimmedURL)
    XCTAssertNil(clip.untrimmed)
    XCTAssertEqual(clip.origin, "recording")
    XCTAssertEqual(clip.startedAt, started)
    XCTAssertEqual(clip.entryID, "set")
  }
}
