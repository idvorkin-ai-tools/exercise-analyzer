import XCTest
@testable import ExerciseCore

/// The models' one owner (#147): passes queue in order, a cancelled waiter leaves the line without the lease,
/// and the live path's tryAcquire fails while a pass holds it.
final class ModelLeaseTests: XCTestCase {
  private actor Order {
    var names: [String] = []
    func append(_ name: String) { names.append(name) }
  }

  /// Lets a freshly started task reach its wait in line (tasks start asynchronously).
  private func settle() async { for _ in 0..<20 { await Task.yield() }; try? await Task.sleep(for: .milliseconds(20)) }

  func testTryAcquireFailsWhileHeldAndSucceedsAfterRelease() {
    let lease = ModelLease()
    XCTAssertTrue(lease.tryAcquire())
    XCTAssertFalse(lease.tryAcquire(), "a live frame must skip while a pass holds the models")
    lease.release()
    XCTAssertFalse(lease.isHeld)
    XCTAssertTrue(lease.tryAcquire())
    lease.release()
  }

  func testWaitersAcquireInArrivalOrder() async throws {
    let lease = ModelLease()
    let order = Order()
    XCTAssertTrue(lease.tryAcquire())
    var tasks: [Task<Void, Error>] = []
    for name in ["A", "B", "C"] {
      tasks.append(
        Task {
          try await lease.acquire()
          await order.append(name)
          lease.release()
        })
      await settle()  // each waiter queues before the next starts
    }
    let before = await order.names
    XCTAssertEqual(before, [], "nobody runs while the first holder still has the models")
    lease.release()
    for task in tasks { try await task.value }
    let after = await order.names
    XCTAssertEqual(after, ["A", "B", "C"])
    XCTAssertFalse(lease.isHeld)
  }

  func testHandOffKeepsTryAcquireOut() async throws {
    let lease = ModelLease()
    XCTAssertTrue(lease.tryAcquire())
    let waiter = Task {
      try await lease.acquire()
      return lease.isHeld
    }
    await settle()
    lease.release()
    let heldByWaiter = try await waiter.value
    XCTAssertTrue(heldByWaiter)
    XCTAssertFalse(lease.tryAcquire(), "the lease passed straight to the waiter; a live frame cannot slip in")
    lease.release()
    XCTAssertFalse(lease.isHeld)
  }

  func testCancelledWaiterLeavesTheLineWithoutTheLease() async throws {
    let lease = ModelLease()
    let order = Order()
    XCTAssertTrue(lease.tryAcquire())
    let cancelled = Task {
      try await lease.acquire()
      await order.append("cancelled")
      lease.release()
    }
    await settle()
    let next = Task {
      try await lease.acquire()
      await order.append("next")
      lease.release()
    }
    await settle()
    cancelled.cancel()
    do {
      try await cancelled.value
      XCTFail("a waiter cancelled in line must throw")
    } catch is CancellationError {}
    XCTAssertTrue(lease.isHeld, "the holder still has it; the cancel must not free the models")
    lease.release()
    try await next.value
    let names = await order.names
    XCTAssertEqual(names, ["next"])
    XCTAssertFalse(lease.isHeld)
  }

  func testAcquireInACancelledTaskThrowsEvenWhenFree() async {
    let lease = ModelLease()
    let task = Task {
      withUnsafeCurrentTask { $0?.cancel() }
      try await lease.acquire()
    }
    do {
      try await task.value
      XCTFail("a cancelled pass must not take the models")
    } catch {}
    XCTAssertFalse(lease.isHeld)
  }
}
