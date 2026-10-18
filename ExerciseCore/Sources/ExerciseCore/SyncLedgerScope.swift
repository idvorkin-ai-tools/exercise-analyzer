// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

import Foundation

/// Which iCloud account the sync ledger was written under (#226, Codex review 7): a ledger says what this device
/// has written to the container, so under another account, whose container starts empty, it is dropped and every
/// set and workout is written again. The account is the archived `ubiquityIdentityToken`.
public struct SyncLedgerScope: Equatable {
  /// The ledger to keep.
  public var ledger: [String: String]
  /// The account it now belongs to, to store beside it; nil only when there was never one.
  public var identity: Data?
  /// The ledger was dropped for another account, or for one never recorded.
  public var reset: Bool

  /// Signed out keeps everything (nothing can be written, and the same account back must not rewrite it all); a
  /// ledger from before the account was stored is dropped, since it could be another account's (Codex on PR #287).
  /// `same` compares two stored accounts: the app unarchives both tokens and asks `isEqual`, as Apple says to,
  /// since two archives of one token need not be the same bytes.
  public static func resolve(
    ledger: [String: String], writtenUnder stored: Data?, signedIn current: Data?,
    same: (Data, Data) -> Bool = { $0 == $1 }
  ) -> SyncLedgerScope {
    guard let current else { return SyncLedgerScope(ledger: ledger, identity: stored, reset: false) }
    if let stored, same(stored, current) { return SyncLedgerScope(ledger: ledger, identity: current, reset: false) }
    if stored == nil, ledger.isEmpty { return SyncLedgerScope(ledger: ledger, identity: current, reset: false) }
    return SyncLedgerScope(ledger: [:], identity: current, reset: true)
  }
}
