import XCTest
@testable import MobileConsentsSDK

@MainActor
final class ConsentSolutionManagerTests: XCTestCase {
    private var sut: ConsentSolutionManager!
    private var notificationCenter: NotificationCenter!
    private var mobileConsents: ConsentSolutionClientMock!

    // Incremented from the notification observer; posts always happen on the main thread.
    private var notificationCount = 0

    @objc private func consentItemSelectionDidChange() {
        notificationCount += 1
    }

    override func setUp() async throws {
        notificationCenter = NotificationCenter()
        mobileConsents = ConsentSolutionClientMock()

        sut = ConsentSolutionManager(
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

    func test_consentItemsSavedAsGivenAreAlreadyMarkedAsSelected_afterLoadingContentSolution() async {
        mobileConsents.savedConsents = [
            userConsent(consentItemId: "0", isSelected: true),
            userConsent(consentItemId: "1", isSelected: false),
            userConsent(consentItemId: "2", isSelected: true)
        ]

        await loadConsentSolution(consentSolution(consentItemConfigs: [(true, .functional), (true, .functional), (false, .functional)]))

        XCTAssertTrue(sut.isConsentItemSelected(id: "0"))
        XCTAssertFalse(sut.isConsentItemSelected(id: "1"))
        XCTAssertTrue(sut.isConsentItemSelected(id: "2"))
    }

    func test_consentItemIsNotSelected_afterLoadingConsentSolution() async {
        await loadConsentSolution(consentSolution(consentItemConfigs: [(true, .functional)]))

        XCTAssertFalse(sut.isConsentItemSelected(id: "0"))
    }

    func test_loadConsentSolutionIfNeeded_whenSolutionIsCached_callsCompletionInlineWithoutRefetching() async {
        let solution = consentSolution(consentItemConfigs: [(true, .functional)])
        mobileConsents.fetchConsentSolutionResult = .success(solution)

        await loadConsentSolution(solution)
        XCTAssertEqual(mobileConsents.fetchConsentCallCount, 1)

        var completionWasCalled = false
        sut.loadConsentSolutionIfNeeded { result in
            completionWasCalled = true
            guard case .success(let receivedSolution) = result else {
                XCTFail("Expected the cached solution")
                return
            }
            XCTAssertEqual(receivedSolution, solution)
        }

        XCTAssertTrue(completionWasCalled, "The cached path is synchronous in 1.6")
        XCTAssertEqual(mobileConsents.fetchConsentCallCount, 1, "A cached solution must not refetch")
    }

    func test_loadConsentSolutionIfNeeded_whenInitializedWithContext_doesNotLoadAgain() async {
        let solution = consentSolution(consentItemConfigs: [(true, .functional)])
        let savedConsent = userConsent(consentItemId: "0", isSelected: true)
        sut = ConsentSolutionManager(
            mobileConsents: mobileConsents,
            notificationCenter: notificationCenter,
            asyncDispatcher: DummyAsyncDispatcher(),
            loadedContext: LoadedConsentContext(
                solution: solution,
                savedConsents: [savedConsent]
            )
        )

        let completion = expectation(description: "Cached solution loaded")
        var receivedSolution: ConsentSolution?
        sut.loadConsentSolutionIfNeeded { result in
            receivedSolution = try? result.get()
            completion.fulfill()
        }
        await fulfillment(of: [completion], timeout: 2)

        XCTAssertEqual(receivedSolution, solution)
        XCTAssertEqual(mobileConsents.fetchConsentCallCount, 0)
        XCTAssertEqual(mobileConsents.loadSavedConsentsCallCount, 0)
        XCTAssertTrue(sut.isConsentItemSelected(id: "0"))
    }

    func test_loadConsentSolutionIfNeeded_whenFetchingNetworkSolution_defersCompletionToDispatcher() async {
        let dispatcher = RecordingAsyncDispatcher()
        sut = ConsentSolutionManager(
            mobileConsents: mobileConsents,
            notificationCenter: notificationCenter,
            asyncDispatcher: dispatcher
        )
        let solution = consentSolution(consentItemConfigs: [(true, .functional)])
        mobileConsents.fetchConsentSolutionResult = .success(solution)
        let savedConsentsLoaded = expectation(description: "Saved consents loaded")
        mobileConsents.onLoadSavedConsents = { savedConsentsLoaded.fulfill() }

        var completionWasCalled = false
        sut.loadConsentSolutionIfNeeded { result in
            completionWasCalled = true
            guard case .success = result else {
                XCTFail("Expected the fetched solution")
                return
            }
        }

        XCTAssertFalse(completionWasCalled, "The network path must not complete inline")
        await fulfillment(of: [savedConsentsLoaded], timeout: 2)
        XCTAssertEqual(dispatcher.pendingWorkCount, 1)

        dispatcher.runNext()

        XCTAssertTrue(completionWasCalled)
        XCTAssertEqual(mobileConsents.fetchConsentCallCount, 1)
    }

    func test_consentItemIsSelected_afterMarkingItAsSelected() async {
        await loadConsentSolution(consentSolution(consentItemConfigs: [(true, .functional)]))
        sut.markConsentItem(id: "0", asSelected: true)

        XCTAssertTrue(sut.isConsentItemSelected(id: "0"))
        XCTAssertEqual(notificationCount, 1)
    }

    func test_consentItemIsNotSelected_afterMarkingItAsNotSelected() async {
        await loadConsentSolution(consentSolution(consentItemConfigs: [(true, .functional)]))
        sut.markConsentItem(id: "0", asSelected: true)
        sut.markConsentItem(id: "0", asSelected: false)

        XCTAssertFalse(sut.isConsentItemSelected(id: "0"))
        XCTAssertEqual(notificationCount, 2)
    }

    func test_acceptAllConsentItemsMarksAllConsentsAsSelected() async {
        await loadConsentSolution(consentSolution(consentItemConfigs: [(true, .functional), (true, .functional)]))

        sut.acceptAllConsentItems { _ in }

        XCTAssertTrue(sut.isConsentItemSelected(id: "0"))
        XCTAssertTrue(sut.isConsentItemSelected(id: "1"))

        XCTAssertEqual(notificationCount, 1)
    }

    func test_acceptAllConsentItemsPostsAllNonPrivacyPolicyConsentsAsGiven() async throws {
        await loadConsentSolution(consentSolution(consentItemConfigs: [(true, .functional), (false, .functional), (true, .privacyPolicy)]))

        sut.acceptAllConsentItems { _ in }

        let processingPurposes = try XCTUnwrap(mobileConsents.postedConsents?.processingPurposes)

        XCTAssertTrue(processingPurposes.first { $0.consentItemId == "0" }?.consentGiven ?? false)
        XCTAssertTrue(processingPurposes.first { $0.consentItemId == "1" }?.consentGiven ?? false)
        // Privacy policy items are excluded from posted processing purposes
        XCTAssertNil(processingPurposes.first { $0.consentItemId == "2" })
    }

    func test_acceptSelectedConsentItemsPostsOnlySelectedAndRequiredConsentsAsGiven() async throws {
        await loadConsentSolution(consentSolution(consentItemConfigs: [(true, .functional), (false, .functional), (true, .privacyPolicy)]))

        sut.markConsentItem(id: "0", asSelected: true)

        sut.acceptSelectedConsentItems { _ in }

        let processingPurposes = try XCTUnwrap(mobileConsents.postedConsents?.processingPurposes)

        XCTAssertTrue(processingPurposes.first { $0.consentItemId == "0" }?.consentGiven ?? false)
        XCTAssertFalse(processingPurposes.first { $0.consentItemId == "1" }?.consentGiven ?? true)
        XCTAssertNil(processingPurposes.first { $0.consentItemId == "2" })
    }

    func test_acceptSelectedConsentItemsCarriesSavedChoicesAndDefaultsNewItemsToNotGiven() async throws {
        mobileConsents.savedConsents = [
            userConsent(consentItemId: "0", isSelected: true),
            userConsent(consentItemId: "1", isSelected: false),
        ]
        await loadConsentSolution(
            consentSolution(
                consentItemConfigs: [
                    (false, .functional),
                    (false, .functional),
                    (false, .functional),
                    (true, .functional),
                ]
            )
        )

        sut.acceptSelectedConsentItems { _ in }

        let processingPurposes = try XCTUnwrap(mobileConsents.postedConsents?.processingPurposes)
        XCTAssertTrue(processingPurposes.first { $0.consentItemId == "0" }?.consentGiven ?? false)
        XCTAssertFalse(processingPurposes.first { $0.consentItemId == "1" }?.consentGiven ?? true)
        XCTAssertFalse(processingPurposes.first { $0.consentItemId == "2" }?.consentGiven ?? true)
        XCTAssertTrue(processingPurposes.first { $0.consentItemId == "3" }?.consentGiven ?? false)
    }

    func test_rejectAllConsentItemsMarksAllConsentsAsNotSelected() async {
        await loadConsentSolution(consentSolution(consentItemConfigs: [(true, .functional), (true, .functional)]))

        sut.markConsentItem(id: "0", asSelected: false)
        sut.markConsentItem(id: "1", asSelected: false)

        sut.rejectAllConsentItems { _ in }

        XCTAssertFalse(sut.isConsentItemSelected(id: "0"))
        XCTAssertFalse(sut.isConsentItemSelected(id: "1"))

        XCTAssertEqual(notificationCount, 3)
    }

    func test_rejectAllConsentItemsPostsNonRequiredConsentsAsNotGiven() async throws {
        await loadConsentSolution(consentSolution(consentItemConfigs: [(false, .functional), (false, .functional), (true, .privacyPolicy)]))

        sut.markConsentItem(id: "0", asSelected: true) // Mark some consent as selected to check if it is not posted

        sut.rejectAllConsentItems { _ in }

        let processingPurposes = try XCTUnwrap(mobileConsents.postedConsents?.processingPurposes)

        XCTAssertFalse(processingPurposes.first { $0.consentItemId == "0" }?.consentGiven ?? true)
        XCTAssertFalse(processingPurposes.first { $0.consentItemId == "1" }?.consentGiven ?? true)
        XCTAssertNil(processingPurposes.first { $0.consentItemId == "2" })
    }

    func test_postingConsentBeforeConsentSolutionIsLoaded_completesWithError() {
        var receivedError: Error?

        sut.acceptSelectedConsentItems { error in
            receivedError = error
        }

        XCTAssertTrue(receivedError is ConsentSolutionManagerError)
        XCTAssertNil(mobileConsents.postedConsents, "Nothing should be posted when there is no consent solution")
    }

    func test_acceptAllConsentItemsBeforeConsentSolutionIsLoadedDoesNotCreateSubmission() {
        sut.acceptAllConsentItems { _ in }

        XCTAssertNil(mobileConsents.postedConsents)
    }

    func test_rejectAllConsentItemsBeforeConsentSolutionIsLoadedDoesNotCreateSubmission() {
        sut.rejectAllConsentItems { _ in }

        XCTAssertNil(mobileConsents.postedConsents)
    }

    private func loadConsentSolution(_ consentSolution: ConsentSolution) async {
        mobileConsents.fetchConsentSolutionResult = .success(consentSolution)

        await withCheckedContinuation { continuation in
            sut.loadConsentSolutionIfNeeded { _ in
                continuation.resume()
            }
        }
    }

}

private final class ConsentSolutionClientMock: ConsentSolutionClient {
    var fetchConsentSolutionResult: Result<ConsentSolution, Error>!
    var postConsentResult: Error?

    private(set) var fetchConsentCallCount = 0
    private(set) var loadSavedConsentsCallCount = 0
    var postedConsents: Consent?
    var savedConsents = [UserConsent]()
    var onLoadSavedConsents: (() -> Void)?

    func fetchConsentSolution(completion: @escaping (Result<ConsentSolution, Error>) -> Void) {
        fetchConsentCallCount += 1
        completion(fetchConsentSolutionResult)
    }

    func postConsent(_ consent: Consent, completion: @escaping (Error?) -> Void) {
        postedConsents = consent
        completion(postConsentResult)
    }

    func loadSavedConsents() async throws -> [UserConsent] {
        loadSavedConsentsCallCount += 1
        onLoadSavedConsents?()
        return savedConsents
    }
}

struct DummyAsyncDispatcher: AsyncDispatcher {
    func async(execute work: @escaping () -> Void) {
        work()
    }
}

private final class RecordingAsyncDispatcher: AsyncDispatcher {
    private var pendingWork = [() -> Void]()

    var pendingWorkCount: Int {
        pendingWork.count
    }

    func async(execute work: @escaping () -> Void) {
        pendingWork.append(work)
    }

    func runNext() {
        precondition(!pendingWork.isEmpty)
        pendingWork.removeFirst()()
    }
}
