// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  The running wrist workout on the lock screen and in the Dynamic Island (#161; Igor: "leave an icon at the top so
//  I can get back to the workout app"). Started when the phone learns of a workout (WorkoutMirror.live), updated
//  as WorkoutGlance says, ended with the workout. The clock runs on its own from startedAt. A tap opens the app.
//  iOS lets an app start an activity only while it is in front, so a workout that arrived in the background gets
//  its activity the next time the app becomes active.

import ActivityKit
import Combine
import ExerciseCore
import UIKit

/// Declared twice with the same name and shape, here and in ExerciseAnalyzerControls/WorkoutActivityView.swift:
/// the extension does not link ExerciseCore or the app, and ActivityKit matches the two by name.
struct WorkoutActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var heartRate: Int?
    var sets: Int
    var reps: Int
  }

  var startedAt: Date
}

@MainActor
final class WorkoutLiveActivity {
  static let shared = WorkoutLiveActivity()
  var onEvent: ((String, [String: Any]) -> Void)?

  private var activity: Activity<WorkoutActivityAttributes>?
  private var shown: WorkoutGlance?
  private var shownAt = Date.distantPast
  private var deferredLogged = false
  private var cancellables = Set<AnyCancellable>()

  /// Follows the mirror from launch; takes over an activity a previous run left up.
  func install(mirror: WorkoutMirror = .shared) {
    guard cancellables.isEmpty else { return }
    activity = Activity<WorkoutActivityAttributes>.activities.first
    // The mirror starts at nil until Health hands the running workout back, so that first nil must not end an
    // activity a previous run left up mid-workout; one with no workout behind it goes with the next workout's end,
    // or iOS takes it down after eight hours.
    if let live = mirror.live { follow(live) }
    mirror.$live.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] in self?.follow($0) }
      .store(in: &cancellables)
    NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
      .sink { [weak self] _ in if let live = mirror.live { self?.follow(live) } }.store(in: &cancellables)
  }

  private func follow(_ live: WorkoutWire?) {
    guard let live, !live.ending else {
      end(reason: live?.discarded == true ? "discarded" : "ended")
      return
    }
    if let activity, activity.attributes.startedAt != live.startDate { end(reason: "replaced") }
    let glance = WorkoutGlance(live)
    guard let activity else {
      start(live, glance)
      return
    }
    let now = Date()
    guard WorkoutGlance.shouldShow(glance, over: shown, shownAt: shownAt, now: now) else { return }
    shown = glance
    shownAt = now
    Task { await activity.update(ActivityContent(state: Self.state(glance), staleDate: nil)) }
  }

  private func start(_ live: WorkoutWire, _ glance: WorkoutGlance) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      if !deferredLogged { onEvent?("live_activity", ["action": "disabled"]) }
      deferredLogged = true
      return
    }
    guard UIApplication.shared.applicationState == .active else {
      if !deferredLogged { onEvent?("live_activity", ["action": "deferred"]) }
      deferredLogged = true
      return
    }
    do {
      activity = try Activity.request(
        attributes: WorkoutActivityAttributes(startedAt: live.startDate),
        content: ActivityContent(state: Self.state(glance), staleDate: nil))
      shown = glance
      shownAt = Date()
      deferredLogged = false
      onEvent?("live_activity", ["action": "start", "started_at": live.startedAt, "sets": glance.sets, "reps": glance.reps])
    } catch {
      onEvent?("live_activity", ["action": "failed", "message": "\(error)"])
    }
  }

  private func end(reason: String) {
    deferredLogged = false
    guard let activity else { return }
    self.activity = nil
    let final = shown.map(Self.state) ?? activity.content.state
    shown = nil
    onEvent?("live_activity", ["action": "end", "reason": reason, "sets": final.sets, "reps": final.reps])
    Task { await activity.end(ActivityContent(state: final, staleDate: nil), dismissalPolicy: .immediate) }
  }

  private static func state(_ glance: WorkoutGlance) -> WorkoutActivityAttributes.ContentState {
    .init(heartRate: glance.heartRate, sets: glance.sets, reps: glance.reps)
  }
}
