// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  The row of exercise drawings and the video diamond above the day list (#265, story 073): one tap keeps only
//  the days with that exercise, the diamond only the days with every set on video, both together narrow further.
//  For looking, not a setting: the app keeps it for one visit and stores nothing.

/// What the row has picked, and which days it keeps.
public struct DayFilter: Equatable, Sendable {
  public var exercise: ExerciseKind?
  public var onVideo: Bool

  public init(exercise: ExerciseKind? = nil, onVideo: Bool = false) {
    self.exercise = exercise
    self.onVideo = onVideo
  }

  public var isActive: Bool { exercise != nil || onVideo }

  /// A day with these exercises (on camera or typed) and this diamond stays in the list.
  public func keeps(exercises: [ExerciseKind], allOnVideo: Bool) -> Bool {
    if let exercise, !exercises.contains(exercise) { return false }
    return !onVideo || allOnVideo
  }

  /// A tap on a drawing picks it; a second tap on the picked one shows every day again.
  public mutating func tap(_ kind: ExerciseKind) {
    exercise = exercise == kind ? nil : kind
  }

  /// The row's drawings: every exercise in the history, once, in the order it last appeared (the days newest first).
  public static func row(_ newestFirst: [[ExerciseKind]]) -> [ExerciseKind] {
    var seen: [ExerciseKind] = []
    for day in newestFirst {
      for kind in day where !seen.contains(kind) { seen.append(kind) }
    }
    return seen
  }
}
