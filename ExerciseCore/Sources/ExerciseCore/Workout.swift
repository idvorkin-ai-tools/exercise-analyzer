// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  The workout (story 048, #82): one HKWorkoutSession on the wrist for the whole gym hour, mirrored to the phone.
//  The watch owns it; the phone keeps a row per ended workout so Workouts can draw the day as one workout.

import Foundation

/// What the watch tells the phone about the running workout, over the mirrored workout session: sent on every
/// heart-rate sample and on every transition, and once more with `ending` set just before the session ends.
public struct WorkoutWire: Codable, Equatable, Sendable {
  public var startedAt: Double
  public var heartRate: Int?
  public var heartRateAverage: Int?
  public var heartRateMax: Int?
  /// Analyzed sets since Start and their reps, as the wrist counts them (the phone's post-pass counts, 045).
  public var sets: Int
  public var reps: Int
  /// The last message: the session ends right after it.
  public var ending: Bool
  /// With `ending`: Discard, not End. Nothing is written to Health and the phone keeps no row.
  public var discarded: Bool

  public init(
    startedAt: Double, heartRate: Int? = nil, heartRateAverage: Int? = nil, heartRateMax: Int? = nil, sets: Int = 0,
    reps: Int = 0, ending: Bool = false, discarded: Bool = false
  ) {
    self.startedAt = startedAt
    self.heartRate = heartRate
    self.heartRateAverage = heartRateAverage
    self.heartRateMax = heartRateMax
    self.sets = sets
    self.reps = reps
    self.ending = ending
    self.discarded = discarded
  }

  public var startDate: Date { Date(timeIntervalSince1970: startedAt) }
}

/// What the workout's Live Activity shows beside its self-running clock (#161): the wrist's heart rate, sets and
/// reps. The wire brings heart rate every few seconds; the activity follows a new set or rep at once and heart
/// rate at most every `heartRateEvery`, so the lock screen is current without an update per beat.
public struct WorkoutGlance: Equatable, Sendable {
  public var heartRate: Int?
  public var sets: Int
  public var reps: Int

  public static let heartRateEvery: TimeInterval = 30

  public init(heartRate: Int?, sets: Int, reps: Int) {
    self.heartRate = heartRate
    self.sets = sets
    self.reps = reps
  }

  public init(_ wire: WorkoutWire) { self.init(heartRate: wire.heartRate, sets: wire.sets, reps: wire.reps) }

  /// Whether the activity should take `next`, shown `shown` since `shownAt`.
  public static func shouldShow(_ next: WorkoutGlance, over shown: WorkoutGlance?, shownAt: Date, now: Date) -> Bool {
    guard let shown else { return true }
    if next.sets != shown.sets || next.reps != shown.reps { return true }
    return next.heartRate != shown.heartRate && now.timeIntervalSince(shownAt) >= heartRateEvery
  }
}

/// The workout chart's time axis in time into the workout, not time of day (#165; Igor: "In graph view switch to
/// relative time not time of day"): ticks on round elapsed times, about `target` across the window, labelled "15 min"
/// or, zoomed in to steps under a minute, "12:15".
public enum ElapsedAxis {
  static let steps: [TimeInterval] = [15, 30, 60, 120, 300, 600, 900, 1800, 3600]

  /// Seconds since `start` at which to draw a tick in `window` (seconds since start), about `target` of them.
  public static func ticks(window: ClosedRange<TimeInterval>, target: Int = 4) -> [TimeInterval] {
    let span = max(window.upperBound - window.lowerBound, 1)
    // Past the last step (a workout left running), whole hours, as many as keep about `target` ticks.
    let step = steps.first { span / $0 <= Double(target) } ?? (span / Double(target) / 3600).rounded(.up) * 3600
    let first = (window.lowerBound / step).rounded(.up) * step
    return stride(from: first, through: window.upperBound, by: step).map { $0 }
  }

  /// "0", "15 min", "1 h 15 min"; with sub-minute steps, "12:15".
  public static func label(_ seconds: TimeInterval, fine: Bool) -> String {
    let whole = Int(seconds.rounded())
    if fine { return String(format: "%d:%02d", whole / 60, whole % 60) }
    let minutes = whole / 60
    if minutes == 0 { return "0" }
    if minutes < 60 { return "\(minutes) min" }
    return minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(minutes % 60) min"
  }

  /// Whether `ticks` are closer than a minute, so their labels need seconds.
  public static func isFine(_ ticks: [TimeInterval]) -> Bool {
    zip(ticks, ticks.dropFirst()).contains { $1 - $0 < 60 }
  }
}

/// An ended workout as the phone keeps it: the span, the heart rate, and the Health record it became.
public struct StoredWorkout: Codable, Hashable, Identifiable, Sendable {
  public var id: String
  public var start: Date
  public var end: Date
  public var heartRateAverage: Int?
  public var heartRateMax: Int?
  /// Sets and reps as the wrist counted them at End; Workouts counts the day's sets itself.
  public var sets: Int
  public var reps: Int

  public init(
    id: String = UUID().uuidString, start: Date, end: Date, heartRateAverage: Int? = nil, heartRateMax: Int? = nil,
    sets: Int = 0, reps: Int = 0
  ) {
    self.id = id
    self.start = start
    self.end = end
    self.heartRateAverage = heartRateAverage
    self.heartRateMax = heartRateMax
    self.sets = sets
    self.reps = reps
  }

  public var duration: TimeInterval { end.timeIntervalSince(start) }

  /// The workout covers the date: a set recorded then belongs to it.
  public func contains(_ date: Date) -> Bool { date >= start && date <= end }
}

/// The phone's list of ended workouts, one JSON file, newest last.
public struct WorkoutIndex: Codable, Equatable, Sendable {
  public static let fileName = "workouts.json"
  public var workouts: [StoredWorkout]

  public init(workouts: [StoredWorkout] = []) { self.workouts = workouts }

  public static func load(root: URL) -> WorkoutIndex {
    let url = root.appendingPathComponent(fileName)
    guard let data = try? Data(contentsOf: url), let index = try? JSONDecoder().decode(WorkoutIndex.self, from: data)
    else { return WorkoutIndex() }
    return index
  }

  public func save(root: URL) throws {
    try JSONEncoder().encode(self).write(to: root.appendingPathComponent(Self.fileName), options: .atomic)
  }

  /// Workouts closer than this, one's end to the next's start, are one session (#169).
  public static let sessionGap: TimeInterval = 30 * 60

  /// The workouts as the phone shows them (#169; Igor: "if I have multiple workouts with a diff of less than 30
  /// minutes, let's just merge them into one"), in start order: a workout that starts under `gap` after the
  /// previous one ends joins it. The session keeps the first workout's id (its heart-rate folder, re-read over the
  /// whole span), spans first start to last end, sums sets and reps, and weights the average heart rate by time.
  /// Health keeps its separate records.
  public func sessions(gap: TimeInterval = sessionGap) -> [StoredWorkout] {
    var merged: [(session: StoredWorkout, parts: [StoredWorkout])] = []
    for workout in workouts.sorted(by: { $0.start < $1.start }) {
      if let last = merged.last, workout.start.timeIntervalSince(last.session.end) < gap {
        merged[merged.count - 1].parts.append(workout)
        merged[merged.count - 1].session.end = max(last.session.end, workout.end)
      } else {
        merged.append((workout, [workout]))
      }
    }
    return merged.map { entry in
      guard entry.parts.count > 1 else { return entry.session }
      var session = entry.session
      session.sets = entry.parts.reduce(0) { $0 + $1.sets }
      session.reps = entry.parts.reduce(0) { $0 + $1.reps }
      session.heartRateMax = entry.parts.compactMap(\.heartRateMax).max()
      let rated = entry.parts.compactMap { part in part.heartRateAverage.map { (bpm: Double($0), seconds: part.duration) } }
      let seconds = rated.reduce(0) { $0 + $1.seconds }
      session.heartRateAverage = seconds > 0 ? Int((rated.reduce(0) { $0 + $1.bpm * $1.seconds } / seconds).rounded()) : nil
      return session
    }
  }

  /// The workouts that started on the calendar day of `date`, in start order.
  public func workouts(on date: Date, calendar: Calendar = .current) -> [StoredWorkout] {
    let day = calendar.startOfDay(for: date)
    return workouts.filter { calendar.startOfDay(for: $0.start) == day }.sorted { $0.start < $1.start }
  }
}
