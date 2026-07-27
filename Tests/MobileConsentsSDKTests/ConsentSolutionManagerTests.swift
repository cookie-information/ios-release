import XCTest
@testable import MobileConsentsSDK

final class ConsentSolutionManagerTests: XCTestCase {
    private var sut: ConsentSolutionManager!
    private var notificationCenter: NotificationCenter!
    private var mobileConsents: MobileConsentsProtocolMock!

    // Incremented from the notification observer; posts always happen on the main thread.
    private var notificationCount = 0

    @objc private func consentItemSelectionDidChange() {
        notificationCount += 1
    }

    override func setUp() async throws {
        notificationCenter = NotificationCenter()
        mobileConsents = MobileConsentsProtocolMock()

        sut = ConsentSolutionManager(
            consentSolutionId: "TestConsentSolutionId",
            mobileConsents: mobileConsents,
            notificationCenter: notificationCenter,
            asyncDispatcher: DummyAsyncDispatcher()
        )

        notificationCount = 0

        notificationCenter.addObserver(
            self,
            selector: #selector(consentItemSelectionDidChange),
            name: ConsentSolutionManager.consentItemSelectionDidChange,
            object: nil
        )
    }

    override func tearDown() async throws {
        sut = nil
        notificationCenter.removeObserver(self)
    }

    func test_areAllRequiredConsentItemsSelectedIsFalse_whenConsentSolutionIsNotLoaded() {
        XCTAssertFalse(sut.areAllRequiredConsentItemsSelected)
    }

    func test_hasRequiredConsentItemsIsFalse_whenConsentSolutionIsNotLoaded() {
        XCTAssertFalse(sut.hasRequiredConsentItems)
    }

    func test_allRequiredConsentItemsAreSelected_whenLoadedSolutionHasNoRequiredConsentItems() {
        loadConsentSolution(consentSolution(consentItemConfigs: [(false, .functional), (false, .functional)]))

        XCTAssertTrue(sut.areAllRequiredConsentItemsSelected)
    }

    func test_hasNoRequiredConsentItems_whenLoadedSolutionHasNoRequiredConsentItems() {
        loadConsentSolution(consentSolution(consentItemConfigs: [(false, .functional), (false, .functional)]))

        XCTAssertFalse(sut.hasRequiredConsentItems)
    }

    func test_allRequiredConsentItemsAreSelected_whenLoadedSolutionHasOnlyRequiredConsentItemsOfTypePrivacyPolicy() {
        loadConsentSolution(consentSolution(consentItemConfigs: [(false, .functional), (true, .privacyPolicy)]))

        XCTAssertTrue(sut.areAllRequiredConsentItemsSelected)
    }

    func test_hasNoRequiredConsentItems_whenLoadedSolutionHasRequiredConsentItemsOfTypePrivacyPolicy() {
        loadConsentSolution(consentSolution(consentItemConfigs: [(false, .functional), (true, .privacyPolicy)]))

        XCTAssertFalse(sut.hasRequiredConsentItems)
    }

    func test_allRequiredConsentItemsAreNotSelected_whenLoadedSolutionHasRequiredConsentItemsOfTypeFunctional() {
        loadConsentSolution(consentSolution(consentItemConfigs: [(true, .functional)]))

        XCTAssertFalse(sut.areAllRequiredConsentItemsSelected)
    }

    func test_hasRequiredConsentItems_whenLoadedSolutionHasRequiredConsentItemsOfTypeFunctional() {
        loadConsentSolution(consentSolution(consentItemConfigs: [(true, .functional)]))

        XCTAssertTrue(sut.hasRequiredConsentItems)
    }

    func test_consentItemsSavedAsGivenAreAlreadyMarkedAsSelected_afterLoadingContentSolution() {
        mobileConsents.savedConsents = [
            userConsent(consentItemId: "0", isSelected: true),
            userConsent(consentItemId: "1", isSelected: false),
            userConsent(consentItemId: "2", isSelected: true)
        ]

        loadConsentSolution(consentSolution(consentItemConfigs: [(true, .functional), (true, .functional), (false, .functional)]))

        XCTAssertTrue(sut.isConsentItemSelected(id: "0"))
        XCTAssertFalse(sut.isConsentItemSelected(id: "1"))
        XCTAssertTrue(sut.isConsentItemSelected(id: "2"))
    }

    func test_consentItemIsNotSelected_afterLoadingConsentSolution() {
        loadConsentSolution(consentSolution(consentItemConfigs: [(true, .functional)]))

        XCTAssertFalse(sut.isConsentItemSelected(id: "0"))
    }

    func test_consentItemIsSelected_afterMarkingItAsSelected() {
        loadConsentSolution(consentSolution(consentItemConfigs: [(true, .functional)]))
        sut.markConsentItem(id: "0", asSelected: true)

        XCTAssertTrue(sut.isConsentItemSelected(id: "0"))
        XCTAssertEqual(notificationCount, 1)
    }

    func test_consentItemIsNotSelected_afterMarkingItAsNotSelected() {
        loadConsentSolution(consentSolution(consentItemConfigs: [(true, .functional)]))
        sut.markConsentItem(id: "0", asSelected: true)
        sut.markConsentItem(id: "0", asSelected: false)

        XCTAssertFalse(sut.isConsentItemSelected(id: "0"))
        XCTAssertEqual(notificationCount, 2)
    }

    func test_acceptAllConsentItemsMarksAllConsentsAsSelected() {
        loadConsentSolution(consentSolution(consentItemConfigs: [(true, .functional), (true, .functional)]))

        sut.acceptAllConsentItems { _ in }

        XCTAssertTrue(sut.isConsentItemSelected(id: "0"))
        XCTAssertTrue(sut.isConsentItemSelected(id: "1"))

        XCTAssertEqual(notificationCount, 1)
    }

    func test_acceptAllConsentItemsPostsAllNonPrivacyPolicyConsentsAsGiven() throws {
        loadConsentSolution(consentSolution(consentItemConfigs: [(true, .functional), (false, .functional), (true, .privacyPolicy)]))

        sut.acceptAllConsentItems { _ in }

        let processingPurposes = try XCTUnwrap(mobileConsents.postedConsents?.processingPurposes)

        XCTAssertTrue(processingPurposes.first { $0.consentItemId == "0" }?.consentGiven ?? false)
        XCTAssertTrue(processingPurposes.first { $0.consentItemId == "1" }?.consentGiven ?? false)
        // Privacy policy items are excluded from posted processing purposes
        XCTAssertNil(processingPurposes.first { $0.consentItemId == "2" })
    }

    func test_acceptSelectedConsentItemsPostsOnlySelectedAndRequiredConsentsAsGiven() throws {
        loadConsentSolution(consentSolution(consentItemConfigs: [(true, .functional), (false, .functional), (true, .privacyPolicy)]))

        sut.markConsentItem(id: "0", asSelected: true)

        sut.acceptSelectedConsentItems { _ in }

        let processingPurposes = try XCTUnwrap(mobileConsents.postedConsents?.processingPurposes)

        XCTAssertTrue(processingPurposes.first { $0.consentItemId == "0" }?.consentGiven ?? false)
        XCTAssertFalse(processingPurposes.first { $0.consentItemId == "1" }?.consentGiven ?? true)
        XCTAssertNil(processingPurposes.first { $0.consentItemId == "2" })
    }

    func test_rejectAllConsentItemsMarksAllConsentsAsNotSelected() {
        loadConsentSolution(consentSolution(consentItemConfigs: [(true, .functional), (true, .functional)]))

        sut.markConsentItem(id: "0", asSelected: false)
        sut.markConsentItem(id: "1", asSelected: false)

        sut.rejectAllConsentItems { _ in }

        XCTAssertFalse(sut.isConsentItemSelected(id: "0"))
        XCTAssertFalse(sut.isConsentItemSelected(id: "1"))

        XCTAssertEqual(notificationCount, 3)
    }

    func test_rejectAllConsentItemsPostsNonRequiredConsentsAsNotGiven() throws {
        loadConsentSolution(consentSolution(consentItemConfigs: [(false, .functional), (false, .functional), (true, .privacyPolicy)]))

        sut.markConsentItem(id: "0", asSelected: true) // Mark some consent as selected to check if it is not posted

        sut.rejectAllConsentItems { _ in }

        let processingPurposes = try XCTUnwrap(mobileConsents.postedConsents?.processingPurposes)

        XCTAssertFalse(processingPurposes.first { $0.consentItemId == "0" }?.consentGiven ?? true)
        XCTAssertFalse(processingPurposes.first { $0.consentItemId == "1" }?.consentGiven ?? true)
        XCTAssertNil(processingPurposes.first { $0.consentItemId == "2" })
    }

    func test_postingConsentBeforeConsentSolutionIsLoaded_completesWithError() {
        // No consent solution has been loaded, so the completion must still fire
        // (with an error) instead of hanging the pop-up spinner forever.
        let receivedError = Ref<Error?>(nil)

        sut.acceptSelectedConsentItems { error in
            receivedError.value = error
        }

        XCTAssertTrue(receivedError.value is ConsentSolutionManagerError)
        XCTAssertNil(mobileConsents.postedConsents, "Nothing should be posted when there is no consent solution")
    }

    private func loadConsentSolution(_ consentSolution: ConsentSolution) {
        mobileConsents.fetchConsentSolutionResult = .success(consentSolution)

        sut.loadConsentSolutionIfNeeded { _ in }
    }

}

private final class MobileConsentsProtocolMock: MobileConsentsProtocol {
    var fetchConsentSolutionResult: Result<ConsentSolution, Error>!
    var postConsentResult: Error?

    var postedConsents: Consent?
    var savedConsents = [UserConsent]()

    func fetchConsentSolution(completion: @escaping (Result<ConsentSolution, Error>) -> Void) {
        completion(fetchConsentSolutionResult)
    }

    func postConsent(_ consent: Consent, completion: @escaping (Error?) -> Void) {
        postedConsents = consent
        completion(postConsentResult)
    }

    func getSavedConsents() -> [UserConsent] {
        savedConsents
    }
}

struct DummyAsyncDispatcher: AsyncDispatcher {
    func async(execute work: @escaping () -> Void) {
        work()
    }
}

