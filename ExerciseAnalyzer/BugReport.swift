// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  Shake to report, through BugKit (https://github.com/idvorkin/bug-kit): a shake, the Open menu's "Report a
//  problem" or ⌘I opens BugKit's sheet over whatever is up; "Log it" writes a `bug_report` event into the session
//  log and one line into Documents/bugs.jsonl (locked append, a unique folder per report) with the screenshot and,
//  in playback, the clip's frame at the playhead. This file is Exercise Analyzer's side: what a report carries.

import AVFoundation
import BugKit
import Combine
import ExerciseCore
import UIKit

extension VideoPoseSession {
  /// One reporter for the app, made on first use (the hooks read this session's state, so it cannot exist before it).
  func makeBugReporter() -> BugReporter {
    var options = BugReporterOptions()
    options.another = .keepMoment  // #212: every report from one sheet is about the shake's moment
    options.gentleShake = false  // a phone carried between sets flicks; iOS's own shake is the report gesture here
    options.launchHookPrefix = "SWING"  // SWING_BUG="a|b", SWING_SHAKE_AFTER=8 in the simulator checks
    options.placeholder = "e.g. counted 1 rep, there were 13"
    let log = log
    let reporter = BugReporter(
      hooks: BugReporterHooks(
        screen: { [unowned self] in self.bugScreen },
        context: { [unowned self] in
          // The moment of the shake: the frame comes from the clip and playhead as they were when the sheet opened.
          self.bugClip = self.source == .camera ? nil : self.currentFileURL.map { ($0, self.currentTime) }
          return self.bugContext()
        },
        sessionLog: { ("logs/\(log.url.lastPathComponent)", Int(Date().timeIntervalSince(log.startedAt) * 1000)) },
        logger: { type, fields in log.event(type, fields.mapValues(\.foundation)) },
        extraFiles: { [weak self] folder in
          guard let clip = await MainActor.run(body: { self?.bugClip }) else { return [] }
          return try await Self.writeFrame(of: clip, into: folder)
        }), options: options)
    bugStatus = reporter.$lastStatus.compactMap { $0 }.sink { [weak self] in self?.noteBugStatus($0) }
    return reporter
  }

  /// What a report carries besides the note (story 022): enough to find the moment in the log and the clip in
  /// Workouts. Numbers stay numbers, so `jq` can compare them.
  func bugContext() -> [String: JSONValue] {
    var context: [String: JSONValue] = [
      "exercise": .string(exercise.definition.name),
      "mode": .string(exerciseMode.storageValue),
      "source": .string("\(source)"),
      "playhead": .double((currentTime * 100).rounded() / 100),
      "reps": .int(reps.count),
      "phase": .string(latestFrame?.analysis?.phase ?? "–"),
    ]
    if let id = currentEntryID { context["recents_id"] = .string(id) }
    if let url = trimmedURL ?? currentFileURL { context["clip"] = .string(url.lastPathComponent) }
    if let detection {
      context["detected"] = .string(detection.exercise.rawValue)
      context["detected_confidence"] = .int(detection.confidence)
    }
    return context
  }

  /// The clip's frame at the playhead, as `frame.jpg` in the report's folder (story 026, #24): what the lifter was
  /// looking at, since the window snapshot can show the video layer black.
  private static func writeFrame(of clip: (url: URL, time: Double), into folder: URL) async throws -> [String] {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: clip.url))
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 720, height: 720)
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    let (image, _) = try await generator.image(at: CMTime(seconds: clip.time, preferredTimescale: 600))
    guard let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.8) else { return [] }
    try data.write(to: folder.appendingPathComponent("frame.jpg"))
    return ["frame.jpg"]
  }
}

extension JSONValue {
  /// The value as JSONSerialization takes it, for this app's `[String: Any]` session log.
  var foundation: Any {
    switch self {
    case .null: return NSNull()
    case .bool(let b): return b
    case .int(let i): return i
    case .double(let d): return d
    case .string(let s): return s
    case .array(let a): return a.map(\.foundation)
    case .object(let o): return o.mapValues(\.foundation)
    }
  }
}
