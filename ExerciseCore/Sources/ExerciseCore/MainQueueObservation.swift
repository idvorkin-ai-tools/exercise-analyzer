import Foundation
import Observation

/// Tracks dependencies immediately, then delivers their latest value on the main queue after a mutation.
/// Changes before delivery coalesce. Keep the token alive; cancellation also suppresses queued delivery.
/// Reads and cancellation belong to the main actor. Neither the registrar nor the queue owns the token.
@MainActor
public final class MainQueueObservation<Value> {
  private var read: (() -> Value)?
  private var receive: ((Value) -> Void)?

  public init(read: @escaping () -> Value, onChange: @escaping (Value) -> Void) {
    self.read = read
    self.receive = onChange
    _ = register()
  }

  public func cancel() {
    read = nil
    receive = nil
  }

  private func register() -> Value? {
    guard let read else { return nil }
    return withObservationTracking {
      read()
    } onChange: { [weak self] in
      // Observation calls before the setter commits. Re-read and re-arm after it finishes.
      DispatchQueue.main.async { [weak self] in
        guard let self, let value = self.register() else { return }
        self.receive?(value)
      }
    }
  }
}
