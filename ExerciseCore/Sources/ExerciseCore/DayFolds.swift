// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  Which days of the Workouts list are folded (story 012, #121; Igor: "Have workouts remember what's collapsed").
//  Days older than a week start folded and newer ones open; a day the lifter folded or opened by hand stays that
//  way across launches. Only the hand-made choices are kept, as one small JSON object in the defaults.

import Foundation

public struct DayFolds: Equatable, Sendable {
  /// "yyyy-MM-dd" → folded, for the days the lifter changed by hand.
  public private(set) var choices: [String: Bool]

  public init(choices: [String: Bool] = [:]) { self.choices = choices }

  /// The stored string; anything unreadable is no choices at all (every day back to the default).
  public init(stored: String) {
    choices = (try? JSONDecoder().decode([String: Bool].self, from: Data(stored.utf8))) ?? [:]
  }

  public var stored: String {
    (try? JSONEncoder().encode(choices)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
  }

  /// Whether the day shows folded: the lifter's choice, else folded when it is older than a week.
  public func isFolded(_ day: String, olderThanAWeek: Bool) -> Bool {
    choices[day] ?? olderThanAWeek
  }

  /// Records a fold or an open made by hand; it outlasts the day's age changing its default.
  public mutating func set(_ day: String, folded: Bool) {
    choices[day] = folded
  }
}
