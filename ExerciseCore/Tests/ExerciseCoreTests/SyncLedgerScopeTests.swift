// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  #226 (Codex review 7): the sync ledger says what this device has written to the iCloud container. Written under
//  one account it says nothing about another's container, which starts empty.

import XCTest

@testable import ExerciseCore

final class SyncLedgerScopeTests: XCTestCase {
  private let written = ["set-1": "f1", "workout-1": "w1"]
  private let me = Data("account-a".utf8)
  private let other = Data("account-b".utf8)

  func testTheSameAccountKeepsItsLedger() {
    let scope = SyncLedgerScope.resolve(ledger: written, writtenUnder: me, signedIn: me)
    XCTAssertEqual(scope.ledger, written)
    XCTAssertFalse(scope.reset)
    XCTAssertEqual(scope.identity, me)
  }

  func testAnotherAccountStartsEmptySoEverythingIsWrittenAgain() {
    let scope = SyncLedgerScope.resolve(ledger: written, writtenUnder: me, signedIn: other)
    XCTAssertEqual(scope.ledger, [:])
    XCTAssertTrue(scope.reset)
    XCTAssertEqual(scope.identity, other)
  }

  /// Two archives of one token can differ in bytes: the comparison the app passes decides, not the bytes.
  func testTheAccountIsComparedByTheGivenRuleNotTheBytes() {
    let sameAccountOtherBytes = Data("account-a, archived again".utf8)
    let scope = SyncLedgerScope.resolve(
      ledger: written, writtenUnder: me, signedIn: sameAccountOtherBytes, same: { $0.prefix(9) == $1.prefix(9) })
    XCTAssertEqual(scope.ledger, written)
    XCTAssertFalse(scope.reset)
  }

  /// Signed out: nothing can be written, and signing back in to the same account must not rewrite it all.
  func testSignedOutKeepsTheLedgerAndItsAccount() {
    let scope = SyncLedgerScope.resolve(ledger: written, writtenUnder: me, signedIn: nil)
    XCTAssertEqual(scope.ledger, written)
    XCTAssertFalse(scope.reset)
    XCTAssertEqual(scope.identity, me)
  }

  /// A ledger from before the account was kept could be another account's (Codex on PR #287: one switched before
  /// the update would never get the unchanged sets), so it is dropped; the pass after only rewrites the small rows,
  /// since files already there and as new are skipped.
  func testALedgerFromBeforeTheAccountWasKeptIsDropped() {
    let scope = SyncLedgerScope.resolve(ledger: written, writtenUnder: nil, signedIn: me)
    XCTAssertEqual(scope.ledger, [:])
    XCTAssertTrue(scope.reset)
    XCTAssertEqual(scope.identity, me)
  }

  /// A first launch has nothing to drop: the account signed in is simply stored.
  func testAnEmptyLedgerIsClaimedWithoutAReset() {
    let scope = SyncLedgerScope.resolve(ledger: [:], writtenUnder: nil, signedIn: me)
    XCTAssertFalse(scope.reset)
    XCTAssertEqual(scope.identity, me)
  }
}
