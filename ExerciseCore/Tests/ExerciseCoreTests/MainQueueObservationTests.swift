import Observation
import XCTest

@testable import ExerciseCore

final class MainQueueObservationTests: XCTestCase {
  @Observable @MainActor final class Model {
    var first = 0
    var second = 10
    var useFirst = true
    var optional: Int? = 1
  }

  @MainActor
  private func drain() async {
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async { continuation.resume() }
    }
  }

  @MainActor
  func testDropsInitialValueCoalescesCommittedValuesAndRegistersAgain() async {
    let model = Model()
    var values: [Int] = []
    let token = MainQueueObservation(
      read: { model.first },
      onChange: {
        XCTAssertTrue(Thread.isMainThread)
        values.append($0)
      })
    XCTAssertTrue(values.isEmpty)
    model.first = 1
    model.first = 2
    XCTAssertTrue(values.isEmpty, "Delivery must wait for the setter to commit")
    await drain()
    XCTAssertEqual(values, [2])
    model.first = 3
    await drain()
    XCTAssertEqual(values, [2, 3], "The second mutation requires re-registration")
    withExtendedLifetime(token) {}
  }

  @MainActor
  func testDependenciesAreReadAgainBeforeDeliveryAndMutationInReceiverIsObserved() async {
    let model = Model()
    var values: [Int] = []
    let token = MainQueueObservation(
      read: { model.useFirst ? model.first : model.second },
      onChange: { value in
        values.append(value)
        if value == 10 { model.second = 11 }
      })
    model.useFirst = false
    await drain()
    await drain()
    XCTAssertEqual(values, [10, 11])
    model.first = 1
    await drain()
    XCTAssertEqual(values, [10, 11], "The old dependency must no longer notify")
    model.second = 12
    await drain()
    XCTAssertEqual(values, [10, 11, 12])
    withExtendedLifetime(token) {}
  }

  @MainActor
  func testCancellationSuppressesPendingDeliveryAndReleasesCaptures() async {
    var model: Model? = Model()
    weak let weakModel = model
    var values: [Int] = []
    let token = MainQueueObservation(read: { [model] in model?.first ?? 0 }, onChange: { values.append($0) })
    model?.first = 1
    token.cancel()
    token.cancel()
    model = nil
    XCTAssertNil(weakModel)
    await drain()
    XCTAssertTrue(values.isEmpty)
  }

  @MainActor
  func testDroppingTokenSuppressesQueuedDeliveryWithoutRegistrarRetainingOwner() async {
    let model = Model()
    var calls = 0
    var token: MainQueueObservation<Int>? = MainQueueObservation(read: { model.first }, onChange: { _ in calls += 1 })
    weak let weakToken = token
    model.first = 1
    token = nil
    XCTAssertNil(weakToken)
    await drain()
    model.first = 2
    await drain()
    XCTAssertEqual(calls, 0)
  }

  @MainActor
  func testIdleRegistrationDoesNotKeepTokenOrItsCapturedModelAlive() async {
    var model: Model? = Model()
    weak let weakModel = model
    var calls = 0
    var token: MainQueueObservation<Int>? = MainQueueObservation(
      read: { [model] in model?.first ?? 0 }, onChange: { _ in calls += 1 })
    weak let weakToken = token
    model = nil
    XCTAssertNotNil(weakModel, "The live token owns its read closure")
    token = nil
    XCTAssertNil(weakToken, "An idle registrar must hold the token weakly")
    XCTAssertNil(weakModel, "Dropping the token must release its read closure")
    await drain()
    XCTAssertEqual(calls, 0)
  }

  @MainActor
  func testNilIsDeliveredAndCancellationBeforeMutationStopsTracking() async {
    let model = Model()
    var values: [Int?] = []
    let token = MainQueueObservation(read: { model.optional }, onChange: { values.append($0) })
    model.optional = nil
    await drain()
    XCTAssertEqual(values.count, 1)
    XCTAssertNil(values.first ?? 0)
    model.optional = 2
    await drain()
    XCTAssertEqual(values, [nil, 2])
    token.cancel()
    model.optional = 3
    await drain()
    XCTAssertEqual(values, [nil, 2])
  }
}
