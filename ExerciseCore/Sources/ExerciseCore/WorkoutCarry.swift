// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  The workout that just ended on the wrist (#238, story 048; Igor: "On quick restart workout ask if want to
//  continue"). Start within `window` of its End asks "Continue the workout that ended 1 min ago?"; Continue
//  starts a new Health session (an ended one cannot resume) and shows the wrist this one's clock and sets on top
//  of the new session's own. Display only: the new session's own counts go to Health and the phone, which joins
//  the two itself (#169), so nothing is counted twice.

import Foundation

public struct WorkoutCarry: Codable, Equatable, Sendable {
  /// How long after an End Start still asks (Igor picked A with 10 minutes, 2026-10-17).
  public static let window: TimeInterval = 10 * 60

  /// What the wrist showed as the start: an earlier part's start when this one continued too.
  public var start: Date
  public var end: Date
  public var sets: Int
  public var reps: Int
  public var exerciseSets: [ExerciseKind: Int]
  public var exerciseOrder: [ExerciseKind]

  public init(
    start: Date, end: Date, sets: Int, reps: Int, exerciseSets: [ExerciseKind: Int], exerciseOrder: [ExerciseKind]
  ) {
    self.start = start
    self.end = end
    self.sets = sets
    self.reps = reps
    self.exerciseSets = exerciseSets
    self.exerciseOrder = exerciseOrder
  }

  public func offered(at now: Date) -> Bool {
    now >= end && now.timeIntervalSince(end) < Self.window
  }

  public func question(at now: Date) -> String {
    let minutes = Int(now.timeIntervalSince(end) / 60)
    return "Continue the workout that ended \(minutes < 1 ? "just now" : "\(minutes) min ago")?"
  }

  /// The wrist's tally with this one under it: its sets first, the new session's exercises after.
  public func adding(
    sets: Int, reps: Int, exerciseSets: [ExerciseKind: Int], exerciseOrder: [ExerciseKind]
  ) -> (sets: Int, reps: Int, exerciseSets: [ExerciseKind: Int], exerciseOrder: [ExerciseKind]) {
    (
      self.sets + sets, self.reps + reps, self.exerciseSets.merging(exerciseSets, uniquingKeysWith: +),
      self.exerciseOrder + exerciseOrder.filter { !self.exerciseOrder.contains($0) }
    )
  }
}
