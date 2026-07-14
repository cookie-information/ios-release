import XCTest
@testable import MobileConsentsSDK

final class RouterTests: XCTestCase {
    private var router: Router!
    private var completionCount = 0
    private var errorCount = 0

    private let sampleError = NSError(domain: "Sample", code: 1234)

    // Synchronous setUp so it runs on the main thread — showPrivacyPopUp
    // instantiates a real UIViewController.
    override func setUp() {
        router = Router(consentSolutionManager: ConsentSolutionManagerMock(), fontSet: .standard)
        completionCount = 0
        errorCount = 0

        router.showPrivacyPopUp(
            animated: false,
            completion: { [weak self] _ in self?.completionCount += 1 },
            error: { [weak self] _ in self?.errorCount += 1 }
        )
    }

    func test_closeAllInvokesCompletionOnlyOnce() {
        router.closeAll(error: nil)
        router.closeAll(error: nil)

        XCTAssertEqual(completionCount, 1)
    }

    func test_closeAllInvokesErrorHandlerOnlyOnce() {
        router.closeAll(error: sampleError)
        router.closeAll(error: sampleError)

        XCTAssertEqual(errorCount, 1)
        XCTAssertEqual(completionCount, 0)
    }

    func test_closeAllAfterErrorDoesNotInvokeCompletion() {
        // A tap sneaking in during the error dismissal must not report success.
        router.closeAll(error: sampleError)
        router.closeAll(error: nil)

        XCTAssertEqual(errorCount, 1)
        XCTAssertEqual(completionCount, 0)
    }
}
