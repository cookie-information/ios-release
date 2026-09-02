import Foundation
import XCTest
@testable import MobileConsentsSDK

final class MainActorRequestDispatcherTests: XCTestCase {
    func testBackgroundRequestPerformsOnMainActorExactlyOnce() {
        let dispatcher = MainActorRequestDispatcher()
        let backgroundCall = expectation(description: "Background call")
        let performed = expectation(description: "Main actor request")
        performed.assertForOverFulfill = true
        let request = RecordingMainActorRequest {
            XCTAssertTrue(Thread.isMainThread)
            performed.fulfill()
        }
        let invoker = BackgroundDispatcherInvoker(
            dispatcher: dispatcher,
            request: request,
            backgroundCall: backgroundCall
        )

        invoker.start()

        wait(for: [backgroundCall, performed], timeout: 2)
    }

    @MainActor
    func testAcceptedRequestSurvivesDispatcherDeallocation() async {
        let performed = expectation(description: "Main actor request")
        performed.assertForOverFulfill = true
        let request = RecordingMainActorRequest {
            performed.fulfill()
        }
        weak var weakDispatcher: MainActorRequestDispatcher?
        var dispatcher: MainActorRequestDispatcher? = MainActorRequestDispatcher()
        weakDispatcher = dispatcher

        dispatcher?.dispatch(request)
        dispatcher = nil

        await fulfillment(of: [performed], timeout: 2)
        XCTAssertNil(weakDispatcher)
    }
}

private final class RecordingMainActorRequest: MainActorRequest {
    private let operation: @MainActor () -> Void

    init(operation: @escaping @MainActor () -> Void) {
        self.operation = operation
    }

    @MainActor
    override func perform() {
        operation()
    }
}

private final class BackgroundDispatcherInvoker: NSObject {
    private let dispatcher: MainActorRequestDispatcher
    private let request: MainActorRequest
    private let backgroundCall: XCTestExpectation

    init(
        dispatcher: MainActorRequestDispatcher,
        request: MainActorRequest,
        backgroundCall: XCTestExpectation
    ) {
        self.dispatcher = dispatcher
        self.request = request
        self.backgroundCall = backgroundCall
    }

    func start() {
        performSelector(inBackground: #selector(invoke), with: nil)
    }

    @objc private func invoke() {
        XCTAssertFalse(Thread.isMainThread)
        backgroundCall.fulfill()
        dispatcher.dispatch(request)
    }
}
