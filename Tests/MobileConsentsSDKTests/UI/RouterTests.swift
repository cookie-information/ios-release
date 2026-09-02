import XCTest
@testable import MobileConsentsSDK

@MainActor
final class RouterTests: XCTestCase {
    private var router: Router!
    private var completionCount = 0
    private var errorCount = 0
    private var dismissingViewController: DismissingViewController!

    private let sampleError = NSError(domain: "Sample", code: 1234)

    private func setUpRouter() {
        router = Router(consentSolutionManager: ConsentSolutionManagerMock(), fontSet: .standard)
        completionCount = 0
        errorCount = 0

        router.showPrivacyPopUp(
            animated: false,
            completion: { [weak self] _ in self?.completionCount += 1 },
            error: { [weak self] _ in self?.errorCount += 1 }
        )

        dismissingViewController = DismissingViewController()
        router.rootViewController = dismissingViewController
    }

    func test_closeAllInvokesCompletionOnlyOnce() {
        setUpRouter()
        router.closeAll(error: nil)
        router.closeAll(error: nil)

        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(dismissingViewController.dismissCallCount, 1)
    }

    func test_closeAllInvokesErrorHandlerOnlyOnce() {
        setUpRouter()
        router.closeAll(error: sampleError)
        router.closeAll(error: sampleError)

        XCTAssertEqual(errorCount, 1)
        XCTAssertEqual(completionCount, 0)
        XCTAssertEqual(dismissingViewController.dismissCallCount, 1)
    }

    func test_closeAllAfterErrorDoesNotInvokeCompletion() {
        setUpRouter()
        // A tap sneaking in during the error dismissal must not report success.
        router.closeAll(error: sampleError)
        router.closeAll(error: nil)

        XCTAssertEqual(errorCount, 1)
        XCTAssertEqual(completionCount, 0)
        XCTAssertEqual(dismissingViewController.dismissCallCount, 1)
    }

}

private final class DismissingViewController: UIViewController {
    private(set) var dismissCallCount = 0

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        dismissCallCount += 1
        completion?()
    }
}
