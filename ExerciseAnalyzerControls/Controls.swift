// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  Lock-screen / Control Center button (issue #70): a Control that opens the app into Live, so a set can be
//  started from a locked phone without digging through the app list. OpenLiveIntent is declared twice, here
//  and in the app (RecordPrompt.swift), same name and shape: with openAppWhenRun the system opens the app and
//  runs the app's perform() in the app's process, so nothing crosses between processes. This copy's perform
//  never runs; it exists so the control can name the intent. Two handoffs failed before it (#153): a
//  UserDefaults flag in the extension's own container, then OpenURLIntent with exerciseanalyzer://live, which
//  does nothing for a custom scheme (it takes universal links only). iOS 18 only: the target ships
//  IPHONEOS_DEPLOYMENT_TARGET 18.0 and every declaration is gated.

import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct OpenLiveIntent: AppIntent {
  static var title: LocalizedStringResource = "Open Live"
  static var openAppWhenRun = true

  func perform() async throws -> some IntentResult { .result() }
}

@available(iOS 18, *)
struct ExerciseControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: "com.idvorkin.exerciseanalyzer.controls.live") {
      ControlWidgetButton(action: OpenLiveIntent()) {
        Label("Exercise", systemImage: "figure.strengthtraining.traditional")
      }
    }
    .displayName("Exercise")
    .description("Opens Exercise Analyzer into Live.")
  }
}

@main
@available(iOS 18, *)
struct ControlsBundle: WidgetBundle {
  var body: some Widget { ExerciseControl() }
}
