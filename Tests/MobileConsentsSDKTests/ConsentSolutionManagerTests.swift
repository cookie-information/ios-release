import XCTest
@testable import MobileConsentsSDK

final class ConsentSolutionManagerTests: XCTestCase {
    private var sut: ConsentSolutionManager!
    private var notificationCenter: NotificationCenter!
    private var mobileConsents: MobileConsentsProtocolMock!

    private var notificationCount: Int!
    private var observationToken: Any!

    override func setUp() {
        notificationCenter = NotificationCenter()
        mobileConsents = MobileConsentsProtocolMock()

        sut = ConsentSolutionManager(
            consentSolutionId: "TestConsentSolutionId",
            mobileConsents: mobileConsents,
            notificationCenter: notificationCenter,
            asyncDispatcher: DummyAsyncDispatcher()
        )

        notificationCount = 0

        observationToken = notificationCenter.addObserver(
            forName: ConsentSolutionManager.consentItemSelectionDidChange,
            object: nil,
            queue: nil) { [weak self] _ in
            self?.notificationCount += 1
        }
    }

    override func tearDown() {
        sut = nil
        notificationCount = nil
        notificationCenter.removeObserver(observationToken as Any)
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
            savedConsent(consentItemId: "0", consentGiven: true),
            savedConsent(consentItemId: "1", consentGiven: false),
            savedConsent(consentItemId: "2", consentGiven: true)
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

    private func savedConsent(consentItemId: String, consentGiven: Bool) -> UserConsent {
        UserConsent(
            consentItem: ConsentItem(
                id: consentItemId,
                required: false,
                type: .functional,
                translations: Translated(translations: [], primaryLanguage: nil)
            ),
            isSelected: consentGiven
        )
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

func consentSolution(consentItemConfigs: [(Bool, ConsentItemType)]) -> ConsentSolution {
    let consentItems = consentItemConfigs.enumerated().map { index, config in
        ConsentItem(
            id: "\(index)",
            required: config.0,
            type: config.1,
            translations: Translated(
                translations: [
                    ConsentTranslation(language: "EN", shortText: "Consent short text", longText: "Consent long text")
                ],
                primaryLanguage: nil
            )
        )
    }

    return ConsentSolution(
        id: "1",
        versionId: "1",
        templateTexts: TemplateTexts(
            readMoreButton: translated("Read more button title"),
            rejectAllButton: translated("Reject all button title"),
            acceptAllButton: translated("Accept all button title"),
            acceptSelectedButton: translated("Accept selected button title"),
            savePreferencesButton: translated("Save preferences button title"),
            privacyCenterTitle: translated("Privacy center title"),
            privacyPreferencesTabLabel: translated("Privacy preferences tab"),
            poweredByCoiLabel: translated("Powered by Cookie Information"),
            consentPreferencesLabel: translated("Consent preferences label"),
            readMoreScreenHeader: nil,
            optionalTableSectionHeader: nil,
            requiredTableSectionHeader: nil
        ),
        consentItems: consentItems
    )
}

private func translated(_ text: String) -> Translated<TemplateTranslation> {
    Translated(translations: [TemplateTranslation(language: "EN", text: text)], primaryLanguage: nil)
}
