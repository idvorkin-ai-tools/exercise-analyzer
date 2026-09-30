// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  Step 2 (#52): the index carries the analyzer version and model set per entry, backfilled once from each
//  set's analysis.json. All file-level, all on a temporary directory: save, load, stale, models, replacement.

import Foundation
import XCTest

@testable import ExerciseCore

final class RecentsIndexTests: XCTestCase {
  private var roots: [URL] = []

  override func tearDown() {
    for root in roots { try? FileManager.default.removeItem(at: root) }
    roots = []
    super.tearDown()
  }

  private func tempRoot() -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    roots.append(root)
    return root
  }

  private func entry(_ id: String, version: String? = AnalysisVersion.current, models: [String]? = ["yolo26n-pose"]) -> RecentEntry {
    RecentEntry(
      id: id, analyzedAt: Date(timeIntervalSince1970: 1_000_000), recordedAt: nil, duration: 60, repCount: 4, bestScore: 80,
      source: .file(name: "clip.mov"), thumbnail: nil, exercise: .kettlebellSwing, originalName: "clip.mov",
      analysisVersion: version, models: models)
  }

  private func writeSnapshot(
    id: String, root: URL, analysisVersion: String? = AnalysisVersion.current,
    models: [String]? = ["yolo26n-pose"]
  ) {
    var snapshot = AnalysisSnapshot(exercise: .kettlebellSwing, frames: [], reps: [])
    snapshot.analysisVersion = analysisVersion
    snapshot.models = models
    let dir = root.appendingPathComponent(id, isDirectory: true)
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try! JSONEncoder().encode(snapshot).write(to: dir.appendingPathComponent("analysis.json"))
  }

  func testSaveLoadRoundTripKeepsMetadata() throws {
    let root = tempRoot()
    var older = entry("b", version: "old", models: [])
    older.analyzedAt = Date(timeIntervalSince1970: 1)
    try RecentsIndex(entries: [entry("a"), older]).save(root: root)
    let loaded = RecentsIndex.load(root: root)
    XCTAssertEqual(loaded.entries.map(\.id), ["a", "b"])
    XCTAssertEqual(loaded.entries[0].analysisVersion, AnalysisVersion.current)
    XCTAssertEqual(loaded.entries[0].models, ["yolo26n-pose"])
    XCTAssertEqual(loaded.entries[1].analysisVersion, "old")
    XCTAssertEqual(loaded.entries[1].models, [])
  }

  func testMissingIndexLoadsEmpty() {
    XCTAssertTrue(RecentsIndex.load(root: tempRoot()).entries.isEmpty)
  }

  /// One row this build cannot read (an exercise it does not know, a downgrade past #158) must not empty the
  /// list: the other rows load, and the file as found is kept beside the index before any save writes over it.
  func testABadRowIsDroppedAndTheFileKeptAside() throws {
    let root = tempRoot()
    try RecentsIndex(entries: [entry("a"), entry("b")]).save(root: root)
    let url = root.appendingPathComponent("index.json")
    var rows = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
    rows[1]["exercise"] = "handstand"
    try JSONSerialization.data(withJSONObject: rows).write(to: url)
    let loaded = RecentsIndex.load(root: root)
    XCTAssertEqual(loaded.entries.map(\.id), ["a"])
    guard case .droppedRows(1, let kept)? = loaded.damage else { return XCTFail("damage: \(String(describing: loaded.damage))") }
    XCTAssertTrue(kept.hasPrefix("index.json.bad-"))
    XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(kept)), try Data(contentsOf: url))
  }

  func testAnUnreadableIndexStartsEmptyAndIsKeptAside() throws {
    let root = tempRoot()
    let url = root.appendingPathComponent("index.json")
    try Data("[{\"id\": \"a\",".utf8).write(to: url)
    let loaded = RecentsIndex.load(root: root)
    XCTAssertTrue(loaded.entries.isEmpty)
    guard case .unreadableFile(let kept)? = loaded.damage else { return XCTFail("damage: \(String(describing: loaded.damage))") }
    XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(kept)), try Data(contentsOf: url))
  }

  /// Launch after launch with the same damage keeps one copy, not one per launch (PR #175 review); a new damage
  /// is kept too.
  func testTheSameDamageIsKeptOnce() throws {
    let root = tempRoot()
    let url = root.appendingPathComponent("index.json")
    try Data("[{\"id\": \"a\",".utf8).write(to: url)
    guard case .unreadableFile(let first)? = RecentsIndex.load(root: root).damage,
      case .unreadableFile(let second)? = RecentsIndex.load(root: root).damage
    else { return XCTFail("no damage") }
    XCTAssertEqual(first, second)
    try Data("[{\"id\": \"b\",".utf8).write(to: url)
    Thread.sleep(forTimeInterval: 1.1)  // the copy's name carries the second
    guard case .unreadableFile(let third)? = RecentsIndex.load(root: root).damage else { return XCTFail("no damage") }
    XCTAssertNotEqual(third, first)
    let copies = try FileManager.default.contentsOfDirectory(atPath: root.path).filter { $0.hasPrefix("index.json.bad-") }
    XCTAssertEqual(copies.count, 2)
  }

  func testOldIndexRowsDecodeWithNilFields() throws {
    // An index.json from before step 2 has neither key.
    let root = tempRoot()
    let json = """
      [{"id":"a","analyzedAt":778297200.0,"duration":60,"repCount":4,"source":{"file":{"name":"clip.mov"}},"exercise":"kettlebell-swing","originalName":"clip.mov"}]
      """
    try json.write(to: root.appendingPathComponent("index.json"), atomically: true, encoding: .utf8)
    let loaded = RecentsIndex.load(root: root)
    XCTAssertEqual(loaded.entries.count, 1)
    XCTAssertNil(loaded.entries[0].analysisVersion)
    XCTAssertNil(loaded.entries[0].models)
  }

  func testBackfillFillsFromSnapshotAndPersists() throws {
    let root = tempRoot()
    try RecentsIndex(entries: [entry("a", version: nil, models: nil)]).save(root: root)
    writeSnapshot(id: "a", root: root, analysisVersion: "2026-09-12.0", models: ["yolo26n-pose", "det"])
    var index = RecentsIndex.load(root: root)
    XCTAssertTrue(index.backfill(root: root))
    XCTAssertEqual(index.entries[0].analysisVersion, "2026-09-12.0")
    XCTAssertEqual(index.entries[0].models, ["yolo26n-pose", "det"])
    try index.save(root: root)
    // The snapshot is gone, but the fields survive on the re-read index: backfilled once.
    try FileManager.default.removeItem(at: root.appendingPathComponent("a", isDirectory: true))
    let reloaded = RecentsIndex.load(root: root)
    XCTAssertEqual(reloaded.entries[0].analysisVersion, "2026-09-12.0")
    XCTAssertEqual(reloaded.entries[0].models, ["yolo26n-pose", "det"])
  }

  func testBackfillSkipsUnreadableSnapshots() {
    let root = tempRoot()
    try! RecentsIndex(entries: [entry("ghost", version: nil, models: nil)]).save(root: root)
    var index = RecentsIndex.load(root: root)
    XCTAssertFalse(index.backfill(root: root))
    XCTAssertNil(index.entries[0].analysisVersion)
    XCTAssertNil(index.entries[0].models)
  }

  func testStalePredicate() {
    XCTAssertFalse(entry("a").isStale(currentVersion: AnalysisVersion.current))
    XCTAssertTrue(entry("a", version: "2026-09-12.0").isStale(currentVersion: AnalysisVersion.current))
    // Nil (a snapshot that never recorded one, or none readable) counts as stale; every caller that needs
    // the poses guards the snapshot load first or skips the entry when it fails.
    XCTAssertTrue(entry("a", version: nil, models: nil).isStale(currentVersion: AnalysisVersion.current))
  }

  func testSameClipReplacement() {
    let photos = entry("a")
    var photosEntry = photos
    photosEntry.source = .photos(identifier: "ABC")
    XCTAssertTrue(photosEntry.isSameClip(source: .photos(identifier: "ABC"), originalName: nil, duration: 999))
    XCTAssertFalse(photosEntry.isSameClip(source: .photos(identifier: "DEF"), originalName: nil, duration: 60))
    let file = entry("b")
    XCTAssertTrue(file.isSameClip(source: .file(name: "other.mov"), originalName: "clip.mov", duration: 60.05))
    XCTAssertFalse(file.isSameClip(source: .file(name: "other.mov"), originalName: "clip.mov", duration: 61))
    XCTAssertFalse(file.isSameClip(source: .file(name: "other.mov"), originalName: "renamed.mov", duration: 60))
  }

  /// #111: deleting says whether the video goes too.
  func testDeletingASetSaysWhetherTheVideoGoesToo() {
    let inApp = SetDeletionPrompt(for: entry("a"))
    XCTAssertTrue(inApp.isFinal)
    XCTAssertEqual(inApp.confirm, "Delete for good")
    XCTAssertTrue(inApp.message.contains("only copy"))

    var photos = entry("b")
    photos.source = .photos(identifier: "ABC")
    let kept = SetDeletionPrompt(for: photos)
    XCTAssertFalse(kept.isFinal)
    XCTAssertEqual(kept.confirm, "Remove")
    XCTAssertEqual(kept.message, "The video stays in Photos.")

    photos.originalBackup = "original.mov"
    XCTAssertTrue(SetDeletionPrompt(for: photos).message.contains("Undo trim"))
  }
}
