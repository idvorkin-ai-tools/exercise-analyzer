// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  Dim while held awake (#160; Igor: "dim while held awake"): when the screen stays on only so the wrist can reach
//  the phone between sets (KeepAwake.dims), it drops to KeepAwake.dimBrightness after KeepAwake.dimAfter without a
//  touch. Any touch, or the hold changing to something looked at (Record, a pass, watch mode) or ending, puts the
//  lifter's own brightness back. Touches are seen by a recognizer on the window that never claims them.

import ExerciseCore
import UIKit

@MainActor
final class ScreenDimmer {
  var onEvent: ((String, [String: Any]) -> Void)?
  private var lastTouch = Date()
  /// Whether the last update's hold dims. The clock restarts on entering one (the app back in front included,
  /// since a backgrounded app's hold does not dim), so the 30 s counts only time the app is in front.
  private var dimming = false
  /// The lifter's brightness while dimmed; nil when not dimmed.
  private var restoreTo: CGFloat?
  private weak var watchedWindow: UIWindow?

  /// Called on every keep-awake decision and on the session's 3 s tick.
  func update(_ reason: KeepAwake, now: Date = Date()) {
    watchTouches()
    defer { dimming = reason.dims }
    guard reason.dims else {
      restore(reason: reason.rawValue)
      return
    }
    if !dimming { lastTouch = now }
    guard restoreTo == nil, now.timeIntervalSince(lastTouch) >= KeepAwake.dimAfter, let screen else { return }
    restoreTo = screen.brightness
    screen.brightness = CGFloat(KeepAwake.dimBrightness)
    onEvent?("screen_dim", ["on": true, "reason": reason.rawValue, "brightness": Double(restoreTo ?? 0)])
  }

  private func touched() {
    lastTouch = Date()
    restore(reason: "touch")
  }

  private func restore(reason: String) {
    guard let level = restoreTo else { return }
    restoreTo = nil
    screen?.brightness = level
    onEvent?("screen_dim", ["on": false, "reason": reason, "brightness": Double(level)])
  }

  private var window: UIWindow? {
    UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow)
  }

  private var screen: UIScreen? { window?.windowScene?.screen }

  /// The key window can arrive after launch, so the recognizer goes on whichever window is key at the next update.
  private func watchTouches() {
    guard let window, window !== watchedWindow else { return }
    watchedWindow = window
    window.addGestureRecognizer(TouchSeen { [weak self] in self?.touched() })
  }
}

/// Reports the start of every touch and never recognizes, so every control underneath behaves as before.
private final class TouchSeen: UIGestureRecognizer, UIGestureRecognizerDelegate {
  private let onTouch: () -> Void

  init(onTouch: @escaping () -> Void) {
    self.onTouch = onTouch
    super.init(target: nil, action: nil)
    cancelsTouchesInView = false
    delaysTouchesBegan = false
    delaysTouchesEnded = false
    delegate = self
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    onTouch()
    state = .failed
  }

  func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
    true
  }
}
