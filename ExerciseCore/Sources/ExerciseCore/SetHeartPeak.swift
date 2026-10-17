// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  The last recorded set's heart peak on the wrist (#195, story 050): the rest head says how far the heart has
//  come down from it. The peak is the phone's rule for a set's peak (053): the highest reading from Record to
//  30 s after Done, since the heart lags the work. It is kept until the next Record; a set typed by hand has no
//  Record and changes nothing.

import Foundation

public struct SetHeartPeak: Equatable, Sendable {
  /// The heart lags the work: readings this long after Done still belong to the set (053).
  public static let lag: TimeInterval = 30

  public private(set) var peak: Int?
  private var recording = false
  private var endedAt: Date?

  public init() {}

  /// Record: a new set, a new peak.
  public mutating func recordStarted(at date: Date) {
    peak = nil
    recording = true
    endedAt = nil
  }

  /// Done (or Cancel): the peak still takes readings for `lag` seconds.
  public mutating func setEnded(at date: Date) {
    guard recording else { return }
    recording = false
    endedAt = date
  }

  public mutating func reading(_ bpm: Int, at date: Date) {
    let inSet = recording || endedAt.map { date.timeIntervalSince($0) <= Self.lag } ?? false
    guard inSet else { return }
    peak = max(peak ?? bpm, bpm)
  }

  /// A new workout.
  public mutating func reset() { self = SetHeartPeak() }

  /// How far below the peak the heart is now; nil while a set records, before any set, or when it has not come
  /// down (the rest head then reads the plain rate, 048).
  public func drop(now: Int?) -> Int? {
    guard !recording, let peak, let now, now < peak else { return nil }
    return peak - now
  }
}
