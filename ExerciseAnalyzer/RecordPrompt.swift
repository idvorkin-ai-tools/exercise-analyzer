// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  "Record" from the watch while the phone app is not in front (issue #10): iOS keeps the camera and the
//  foreground out of reach of a backgrounded app, so the phone posts a notification; tapping it opens the app
//  and starts the camera.

import AppIntents
import Foundation
import UserNotifications

enum RecordPrompt {
  static let tapped = Notification.Name("ExerciseAnalyzer.recordPromptTapped")
  static let category = "record"

  /// Ask once while the app is in front: a request made from a background-launched app is deferred by iOS until
  /// the app is foregrounded, and its completion never runs, so the watch's Record would post nothing.
  static func prepare(log: SessionLog) {
    #if targetEnvironment(simulator)
      return  // no watch on the simulator, and the permission dialog would sit over every screenshot
    #endif
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      log.event("notification_auth", ["status": settings.authorizationStatus.rawValue])
      guard settings.authorizationStatus == .notDetermined else { return }
      center.requestAuthorization(options: [.alert, .sound]) { granted, error in
        log.event("notification_auth", ["requested": true, "granted": granted, "error": error.map { "\($0)" } ?? ""])
      }
    }
  }

  /// A Preview asked while the phone app is backgrounded carries the viewfinder flag, so the tap opens
  /// into the viewfinder instead of recording (047).
  static func post(log: SessionLog, viewfinder: Bool = false) {
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      let granted = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
      log.event(
        "record_prompt",
        ["status": settings.authorizationStatus.rawValue, "granted": granted, "viewfinder": viewfinder])
      guard granted else { return }
      let content = UNMutableNotificationContent()
      content.title = viewfinder ? "Ready to frame" : "Ready to record"
      content.body =
        viewfinder
        ? "Tap to open Exercise Analyzer and frame the shot."
        : "Tap to open Exercise Analyzer and start the camera."
      content.sound = .default
      content.categoryIdentifier = category
      content.userInfo = ["viewfinder": viewfinder]
      let request = UNNotificationRequest(identifier: "record-from-watch", content: content, trigger: nil)
      center.add(request) { error in
        if let error { log.event("error", ["where": "record_prompt", "message": "\(error)"]) }
      }
    }
  }
}

/// Lock-screen / Control Center button (#70): the control (ExerciseAnalyzerControls) names OpenLiveIntent,
/// and with openAppWhenRun the system opens the app and runs this copy's perform() here, in the app's process
/// (#153: the extension's own copy must match this one's name and shape). The session, observing `live`,
/// logs `launch_control` and starts the camera, the same as a RecordPrompt tap. On a cold launch perform()
/// can run before the session exists, so the press also waits in `pending` until the session takes it.
@MainActor
enum ControlLaunch {
  static let live = Notification.Name("ExerciseAnalyzer.controlLaunchLive")
  private static var pending = false

  static func request() {
    pending = true
    NotificationCenter.default.post(name: live, object: nil)
  }

  /// True once per press: the session calls it on the notification and again at init.
  static func take() -> Bool {
    defer { pending = false }
    return pending
  }
}

struct OpenLiveIntent: AppIntent {
  static var title: LocalizedStringResource = "Open Live"
  static var openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    ControlLaunch.request()
    return .result()
  }
}

/// Routes a tap on the record notification to the session.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
  static let shared = NotificationRouter()

  func install() { UNUserNotificationCenter.current().delegate = self }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.notification.request.content.categoryIdentifier == RecordPrompt.category {
      let viewfinder = response.notification.request.content.userInfo["viewfinder"] as? Bool ?? false
      NotificationCenter.default.post(name: RecordPrompt.tapped, object: viewfinder)
    }
    completionHandler()
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }
}
