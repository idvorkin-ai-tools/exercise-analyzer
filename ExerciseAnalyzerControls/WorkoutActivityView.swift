// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  The running wrist workout's Live Activity (#161): the lock screen shows WORKOUT, the clock counting up by itself
//  from the start, heart rate and sets · reps; the Dynamic Island shows the figure and the clock, and the same four
//  when pressed. A tap opens the app. The app (WorkoutLiveActivity) starts, updates and ends it.

import ActivityKit
import SwiftUI
import WidgetKit

/// Mirror of the app's WorkoutActivityAttributes (ExerciseAnalyzer/WorkoutLiveActivity.swift): an extension
/// cannot import the app, and ActivityKit matches the two by name, so the name and fields must stay the same.
struct WorkoutActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var heartRate: Int?
    var sets: Int
    var reps: Int
  }

  var startedAt: Date
}

@available(iOS 18, *)
struct WorkoutActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
      HStack(spacing: 12) {
        Image(systemName: "figure.strengthtraining.traditional")
          .font(.title2).foregroundStyle(.green)
          .frame(width: 44, height: 44)
          .background(Color.green.opacity(0.2), in: Circle())
        VStack(alignment: .leading, spacing: 0) {
          Text("WORKOUT").font(.caption.bold()).foregroundStyle(.green)
          clock(context.attributes.startedAt).font(.system(size: 34, weight: .bold, design: .rounded))
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 2) {
          heart(context.state.heartRate).font(.title3.bold())
          Text(tally(context.state)).font(.subheadline).foregroundStyle(.secondary)
        }
      }
      .padding(16)
      .activityBackgroundTint(Color.black.opacity(0.75))
      .activitySystemActionForegroundColor(.green)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label("Workout", systemImage: "figure.strengthtraining.traditional")
            .font(.caption.bold()).foregroundStyle(.green)
        }
        DynamicIslandExpandedRegion(.trailing) {
          heart(context.state.heartRate).font(.headline)
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack {
            clock(context.attributes.startedAt).font(.system(size: 30, weight: .bold, design: .rounded))
            Spacer()
            Text(tally(context.state)).font(.headline)
          }
        }
      } compactLeading: {
        Image(systemName: "figure.strengthtraining.traditional").foregroundStyle(.green)
      } compactTrailing: {
        clock(context.attributes.startedAt).frame(width: 52).font(.caption.bold())
      } minimal: {
        Image(systemName: "figure.strengthtraining.traditional").foregroundStyle(.green)
      }
    }
  }

  /// Counts up from the start with no update from the app.
  private func clock(_ start: Date) -> some View {
    Text(timerInterval: start...Date.distantFuture, countsDown: false)
      .monospacedDigit().multilineTextAlignment(.trailing)
  }

  private func heart(_ bpm: Int?) -> some View {
    HStack(spacing: 3) {
      Image(systemName: "heart.fill").foregroundStyle(.red)
      Text(bpm.map(String.init) ?? "--").monospacedDigit()
    }
  }

  private func tally(_ state: WorkoutActivityAttributes.ContentState) -> String {
    "\(state.sets) set\(state.sets == 1 ? "" : "s") · \(state.reps) reps"
  }
}
