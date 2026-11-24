// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  The running workout to Larry's Cockpit (story 084, #376): follows the wrist's workout and the sets saved in it,
//  turns them into events (`WorkoutStream`, ExerciseCore) and sends them, one at a time, oldest first, while the
//  exercise menu's "Send workouts to Larry" is on (off by default). What waits is kept across launches. Each answer
//  is a `workout_event` line in the session log.
//  ponytail: an ending that lands after the session ended (ea-iwi's late Discard) is not sent again as a
//  discard. Upgrade: a correcting `ended` for the same workout id once the Cockpit says how it takes one.

import ExerciseCore
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class CockpitWorkoutSender {
  static let shared = CockpitWorkoutSender()
  static let enabledKey = "sendWorkoutsToLarry"
  private static let streamKey = "workoutStream"
  /// Larry's Cockpit, as Grabber reaches it; `SWING_COCKPIT_URL` points elsewhere for a test.
  nonisolated static let cockpit =
    URL(string: ProcessInfo.processInfo.environment["SWING_COCKPIT_URL"] ?? "https://c-5004.squeaker-teeth.ts.net")
    ?? URL(fileURLWithPath: "/")

  /// The exercise menu's switch; off drops whatever waits.
  var enabled: Bool {
    get {
      access(keyPath: \.enabled)
      return UserDefaults.standard.bool(forKey: Self.enabledKey)
    }
    set {
      withMutation(keyPath: \.enabled) { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
      onEvent?("workout_event", ["action": newValue ? "on" : "off"])
      if !newValue {
        stream = WorkoutStream()
        retry?.cancel()
        retryDelay = Self.firstRetry
      }
    }
  }
  /// After a "waiting" answer the next try comes on its own, 30 s later, doubling to 10 min.
  private static let firstRetry: TimeInterval = 30
  private static let lastRetry: TimeInterval = 10 * 60
  @ObservationIgnored var onEvent: ((String, [String: Any]) -> Void)?

  @ObservationIgnored private var stream = WorkoutStream() { didSet { save() } }
  @ObservationIgnored private var sending = false
  @ObservationIgnored private var retry: Task<Void, Never>?
  @ObservationIgnored private var retryDelay = CockpitWorkoutSender.firstRetry
  /// A workout was heard this run: only then is a nil `live` an end, not the launch's not-knowing-yet.
  @ObservationIgnored private var heard = false
  @ObservationIgnored private var observations: [AnyObject] = []

  private init() {
    if let data = UserDefaults.standard.data(forKey: Self.streamKey),
      let saved = try? JSONDecoder().decode(WorkoutStream.self, from: data)
    {
      stream = saved
    }
  }

  func install(mirror: WorkoutMirror, recents: RecentsStore) {
    guard observations.isEmpty else { return }
    let follow: () -> Void = { [weak self] in self?.follow(mirror: mirror, recents: recents) }
    observations = [
      MainQueueObservation(read: { mirror.live }, onChange: { _ in follow() }),
      MainQueueObservation(read: { recents.entries }, onChange: { _ in follow() }),
      NotificationCenter.default.addObserver(
        forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
      ) { [weak self] _ in Task { @MainActor in self?.flush() } } as AnyObject,
    ]
    follow()
  }

  private func follow(mirror: WorkoutMirror, recents: RecentsStore) {
    guard enabled else { return }
    let live = mirror.live
    if live != nil { heard = true }
    guard live != nil || heard else {
      flush()  // what waits from before the launch still goes
      return
    }
    let now = Date()
    let series = live.flatMap { mirror.liveHeartRateSeries(for: WorkoutMirror.soFar($0)) }
    let before = stream
    stream.follow(live, sets: recents.entries, heartRate: series, now: now)
    for event in stream.pending where !before.pending.contains(where: { $0.id == event.id }) {
      onEvent?("workout_event", fields(event, action: "queued"))
    }
    flush()
  }

  /// Sends what waits, oldest first; stops at the first retry, since the rest would wait the same way, and tries
  /// again on its own later.
  func flush() {
    guard enabled, !sending else { return }
    for event in stream.dropStale(now: Date()) {
      var f = fields(event, action: "dropped")
      f["reason"] = "waited over a day"
      onEvent?("workout_event", f)
    }
    guard let event = stream.pending.first else { return }
    sending = true
    Task { [weak self] in
      let outcome = await Self.send(event)
      guard let self else { return }
      self.sending = false
      var f = self.fields(event, action: "sent")
      self.retry?.cancel()
      switch outcome {
      case .sent(let duplicate):
        f["duplicate"] = duplicate
        self.stream.done(event.id)
        self.retryDelay = Self.firstRetry
        self.onEvent?("workout_event", f)
        self.flush()
      case .refused(let status, let reason):
        f["action"] = "refused"
        f["status"] = status
        f["reason"] = reason
        self.stream.done(event.id)
        self.retryDelay = Self.firstRetry
        self.onEvent?("workout_event", f)
        self.flush()
      case .retry(let reason):
        f["action"] = "waiting"
        f["reason"] = reason
        self.onEvent?("workout_event", f)
        let delay = self.retryDelay
        self.retryDelay = min(delay * 2, Self.lastRetry)
        self.retry = Task { [weak self] in
          try? await Task.sleep(for: .seconds(delay))
          guard !Task.isCancelled else { return }
          self?.flush()
        }
      }
    }
  }

  private nonisolated static func send(_ event: WorkoutEvent) async -> WorkoutEventWire.Outcome {
    do {
      let request = try WorkoutEventWire.request(event, cockpit: cockpit, sentAt: Date())
      let (data, response) = try await URLSession.shared.data(for: request)
      return WorkoutEventWire.outcome(status: (response as? HTTPURLResponse)?.statusCode, body: data)
    } catch {
      return WorkoutEventWire.outcome(status: nil, body: nil, error: error.localizedDescription)
    }
  }

  private func fields(_ event: WorkoutEvent, action: String) -> [String: Any] {
    // "event", not "type": the session log's own `type` is the line's.
    ["action": action, "id": event.id, "event": event.type.rawValue, "waiting": stream.pending.count]
  }

  private func save() {
    if let data = try? JSONEncoder().encode(stream) { UserDefaults.standard.set(data, forKey: Self.streamKey) }
  }
}
