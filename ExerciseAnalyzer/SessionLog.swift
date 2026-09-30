// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  JSON Lines session log written to Documents/logs (visible in Finder and the Files app, pull with
//  `just pull-logs`). One event per line with a monotonic `t` in ms since the session started.

import Foundation
import ExerciseCore
import UIKit

final class SessionLog: @unchecked Sendable {
  let url: URL
  private let queue = DispatchQueue(label: "swing.log")
  private var handle: FileHandle?
  private let start = Date()
  var startedAt: Date { start }

  init() {
    let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("logs", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    url = dir.appendingPathComponent("swing-\(formatter.string(from: start)).jsonl")
    FileManager.default.createFile(atPath: url.path, contents: nil)
    do {
      handle = try FileHandle(forWritingTo: url)
    } catch {
      // No file, no evidence: say so once where a tethered run can see it; every event after this is dropped.
      print("SessionLog: cannot open \(url.path): \(error)")
    }
    event(
      "session_start",
      [
        "device": UIDevice.current.model, "system": UIDevice.current.systemVersion,
        "app": Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "",
        "build": Bundle.main.infoDictionary?["CFBundleVersion"] ?? "",
        "analysis": AnalysisVersion.current,
        "started": ISO8601DateFormatter().string(from: start),
      ])
  }

  func event(_ type: String, _ fields: [String: Any] = [:]) {
    var record: [String: Any] = ["type": type, "t": Int(Date().timeIntervalSince(start) * 1000)]
    for (key, value) in fields { record[key] = Self.sanitize(value) }
    queue.async { [self] in
      guard let handle else { return }
      let data: Data
      do {
        data = try JSONSerialization.data(withJSONObject: record)
      } catch {
        // A value JSON cannot carry (a Date, a CGRect) must not lose the line: keep the type and say what happened.
        let fallback: [String: Any] = [
          "type": "error", "t": record["t"] ?? 0, "where": "log", "event": type, "message": "\(error)",
        ]
        data = (try? JSONSerialization.data(withJSONObject: fallback)) ?? Data()
      }
      handle.write(data)
      handle.write(Data([0x0A]))
    }
  }

  func frame(_ frame: FrameRecord, source: String, inferenceMs: Double, fps: Double, personConf: Float?) {
    var fields: [String: Any] = [
      "time": frame.time, "src": source, "infer_ms": inferenceMs, "fps": fps,
    ]
    if let personConf { fields["conf"] = personConf }
    if let analysis = frame.analysis {
      fields["phase"] = analysis.phase
      fields["rep"] = analysis.repCount
      for (key, value) in analysis.metrics { fields[key] = value }
    }
    event("frame", fields)
  }

  func rep(_ rep: RepRecord, source: String) {
    event(
      "rep",
      [
        "src": source, "number": rep.number, "score": rep.quality.score,
        "feedback": rep.quality.feedback,
        "quality": rep.quality.metrics.mapValues { Self.sanitize($0) },
        "positions": rep.positions.mapValues { $0.time },
      ])
  }

  /// JSONSerialization rejects non-finite doubles; round and clamp so a NaN angle can't drop a whole line.
  /// Recurses into dictionaries and arrays (a bell box, a list of ankle confidences).
  private static func sanitize(_ value: Any) -> Any {
    switch value {
    case let d as Double: return d.isFinite ? (d * 100).rounded() / 100 : -1
    case let f as Float: return sanitize(Double(f))
    case let dict as [String: Any]: return dict.mapValues { sanitize($0) }
    case let array as [Any]: return array.map { sanitize($0) }
    default: return value
    }
  }
}
