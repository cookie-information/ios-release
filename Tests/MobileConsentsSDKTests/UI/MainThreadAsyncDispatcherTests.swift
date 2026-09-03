import Foundation
import XCTest
@testable import MobileConsentsSDK

@MainActor
final class MainThreadAsyncDispatcherTests: XCTestCase {
    func testMainThreadCallRunsAsynchronouslyOnMainThread() async {
        let dispatcher = MainThreadAsyncDispatcher()
        let completed = expectation(description: "Work completed")
        var didRun = false

        dispatcher.async {
            XCTAssertTrue(Thread.isMainThread)
            didRun = true
            completed.fulfill()
        }

        XCTAssertFalse(didRun)
        await fulfillment(of: [completed], timeout: 2)
        XCTAssertTrue(didRun)
    }

    func testBackgroundCallRunsOnMainThread() async {
        let dispatcher = MainThreadAsyncDispatcher()
        let completed = expectation(description: "Background work completed")
        let invoker = BackgroundDispatcherInvoker(
            dispatcher: dispatcher,
            completion: completed
        )

        invoker.start()

        await fulfillment(of: [completed], timeout: 2)
    }

    func testMultipleCallsRunInSubmissionOrder() async {
        let dispatcher = MainThreadAsyncDispatcher()
        let completed = expectation(description: "All work completed")
        completed.expectedFulfillmentCount = 3
        var values: [Int] = []

        for value in 1...3 {
            dispatcher.async {
                values.append(value)
                completed.fulfill()
            }
        }

        await fulfillment(of: [completed], timeout: 2)
        XCTAssertEqual(values, [1, 2, 3])
    }
}

private final class BackgroundDispatcherInvoker: NSObject {
    private let dispatcher: AsyncDispatcher
    private let completion: XCTestExpectation

    init(dispatcher: AsyncDispatcher, completion: XCTestExpectation) {
        self.dispatcher = dispatcher
        self.completion = completion
    }

    func start() {
        performSelector(inBackground: #selector(invoke), with: nil)
    }

    @objc private func invoke() {
        XCTAssertFalse(Thread.isMainThread)
        dispatcher.async {
            XCTAssertTrue(Thread.isMainThread)
            self.completion.fulfill()
        }
    }
}
