import XCTest
@testable import MobileConsentsSDK

final class ConsentSolutionManagerTests: XCTestCase {
    private var sut: ConsentSolutionManager!
    private var notificationCenter: NotificationCenter!
    private var mobileConsents: MobileConsentsMock!
    
    private var notificationCount: Int!
    private var observationToken: Any!
    
    override func setUp() {
        notificationCenter = .default
        mobileConsents = MobileConsentsMock()
        
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
        loadConsentSolution(consentSolution(consentItemConfigs: [(false, .setting), (false, .setting)]))
        
        XCTAssertTrue(sut.areAllRequiredConsentItemsSelected)
    }
    
    func test_hasNoRequiredConsentItems_whenLoadedSolutionHasNoRequiredConsentItems() {
        loadConsentSolution(consentSolution(consentItemConfigs: [(false, .setting), (false, .setting)]))
        
        XCTAssertFalse(sut.hasRequiredConsentItems)
    }
    
    func test_allRequiredConsentItemsAreSelected_whenLoadedSolutionHasOnlyRequiredConsentItemsOfTypeInfo() {
        loadConsentSolution(consentSolution(consentItemConfigs: [(false, .setting), (true, .info)]))
        
        XCTAssertTrue(sut.areAllRequiredConsentItemsSelected)
    }
    
    func test_hasNoRequiredConsentItems_whenLoadedSolutionHasRequiredConsentItemsOfTypeInfo() {
        loadConsentSolution(consentSolution(consentItemConfigs: [(false, .setting), (true, .info)]))
        
        XCTAssertFalse(sut.hasRequiredConsentItems)
    }
    
    func test_allRequiredConsentItemsAreNotSelected_whenLoadedSolutionHasRequiredConsentItemsOfTypeSetting() {
        loadConsentSolution(consentSolution(consentItemConfigs: [(true, .setting)]))
        
        XCTAssertFalse(sut.areAllRequiredConsentItemsSelected)
    }
    
    func test_hasRequiredConsentItems_whenLoadedSolutionHasRequiredConsentItemsOfTypeSetting() {
        loadConsentSolution(consentSolution(consentItemConfigs: [(true, .setting)]))
        
        XCTAssertTrue(sut.hasRequiredConsentItems)
    }
    
    func test_consentItemsSavedAsGivenAreAlreadyMarkedAsSelected_afterLoadingContentSolution() {
        mobileConsents.savedConsents = [
            SavedConsent(consentItemId: "0", consentGiven: true),
            SavedConsent(consentItemId: "1", consentGiven: false),
            SavedConsent(consentItemId: "2", consentGiven: true)
        ]
        
        loadConsentSolution(consentSolution(consentItemConfigs: [(true, .setting), (true, .setting), (false, .setting)]))
        
        XCTAssertTrue(sut.isConsentItemSelected(id: "0"))
        XCTAssertFalse(sut.isConsentItemSelected(id: "1"))
        XCTAssertTrue(sut.isConsentItemSelected(id: "2"))
    }
    
    func test_consentItemIsNotSelected_afterLoadingConsentSolution() {
        loadConsentSolution(consentSolution(consentItemConfigs: [(true, .setting)]))
        
        XCTAssertFalse(sut.isConsentItemSelected(id: "0"))
    }
    
    func test_consentItemIsSelected_afterMarkingItAsSelected() {
        loadConsentSolution(consentSolution(consentItemConfigs: [(true, .setting)]))
        sut.markConsentItem(id: "0", asSelected: true)
        
        XCTAssertTrue(sut.isConsentItemSelected(id: "0"))
        XCTAssertEqual(notificationCount, 1)
    }
    
    func test_consentItemIsNotSelected_afterMarkingItAsNotSelected() {
        loadConsentSolution(consentSolution(consentItemConfigs: [(true, .setting)]))
        sut.markConsentItem(id: "0", asSelected: true)
        sut.markConsentItem(id: "0", asSelected: false)
        
        XCTAssertFalse(sut.isConsentItemSelected(id: "0"))
        XCTAssertEqual(notificationCount, 2)
    }
    
    func test_acceptAllConsentItemsMarksAllConsentsAsSelected() {
        loadConsentSolution(consentSolution(consentItemConfigs: [(true, .setting), (true, .setting)]))
        
        sut.acceptAllConsentItems { _ in }
        
        XCTAssertTrue(sut.isConsentItemSelected(id: "0"))
        XCTAssertTrue(sut.isConsentItemSelected(id: "1"))
        
        XCTAssertEqual(notificationCount, 1)
    }
    
    func test_acceptAllConsentItemsPostsAllConsentsAsGiven() throws {
        loadConsentSolution(consentSolution(consentItemConfigs: [(true, .setting), (false, .setting), (true, .info)]))
        
        sut.acceptAllConsentItems { _ in }
        
        let processingPurposes = try XCTUnwrap(mobileConsents.postedConsents?.processingPurposes)
        
        XCTAssertTrue(processingPurposes.first { $0.consentItemId == "0" }?.consentGiven ?? false)
        XCTAssertTrue(processingPurposes.first { $0.consentItemId == "1" }?.consentGiven ?? false)
        XCTAssertTrue(processingPurposes.first { $0.consentItemId == "2" }?.consentGiven ?? false)
    }
    
    func test_acceptSelectedConsentItemsPostsOnlySelectedConsentsAndInfoConsentsAsGiven() throws {
        loadConsentSolution(consentSolution(consentItemConfigs: [(true, .setting), (false, .setting), (true, .info)]))
        
        sut.markConsentItem(id: "0", asSelected: true)
        
        sut.acceptSelectedConsentItems { _ in }
        
        let processingPurposes = try XCTUnwrap(mobileConsents.postedConsents?.processingPurposes)
        
        XCTAssertTrue(processingPurposes.first { $0.consentItemId == "0" }?.consentGiven ?? false)
        XCTAssertFalse(processingPurposes.first { $0.consentItemId == "1" }?.consentGiven ?? true)
        XCTAssertTrue(processingPurposes.first { $0.consentItemId == "2" }?.consentGiven ?? false)
    }
    
    func test_rejectAllConsentItemsMarksAllConsentsAsNotSelected() {
        loadConsentSolution(consentSolution(consentItemConfigs: [(true, .setting), (true, .setting)]))
         
        sut.markConsentItem(id: "0", asSelected: false)
        sut.markConsentItem(id: "1", asSelected: false)
        
        sut.rejectAllConsentItems { _ in }
        
        XCTAssertFalse(sut.isConsentItemSelected(id: "0"))
        XCTAssertFalse(sut.isConsentItemSelected(id: "1"))
        
        XCTAssertEqual(notificationCount, 3)
    }
    
    func test_rejectAllConsentItemsPostsOnlyInfoConsentsAsGiven() throws {
        loadConsentSolution(consentSolution(consentItemConfigs: [(false, .setting), (false, .setting), (true, .info)]))
        
        sut.markConsentItem(id: "0", asSelected: true) // Mark some consent as selected to check if it is not posted
        
        sut.rejectAllConsentItems { _ in }
        
        let processingPurposes = try XCTUnwrap(mobileConsents.postedConsents?.processingPurposes)
        
        XCTAssertFalse(processingPurposes.first { $0.consentItemId == "0" }?.consentGiven ?? true)
        XCTAssertFalse(processingPurposes.first { $0.consentItemId == "1" }?.consentGiven ?? true)
        XCTAssertTrue(processingPurposes.first { $0.consentItemId == "2" }?.consentGiven ?? false)
    }
    
    private func loadConsentSolution(_ consentSolution: ConsentSolution) {
        mobileConsents.fetchConsentSolutionResult = .success(consentSolution)
        
        sut.loadConsentSolutionIfNeeded { _ in }
    }
}

private final class MobileConsentsMock: MobileConsentsProtocol {
    var fetchConsentSolutionResult: Result<ConsentSolution, Error>!
    var postConsentResult: Error?
    
    var postedConsents: Consent?
    var savedConsents = [SavedConsent]()
    
    func fetchConsentSolution(forUniversalConsentSolutionId universalConsentSolutionId: String, completion: @escaping (Result<ConsentSolution, Error>) -> Void) {
        completion(fetchConsentSolutionResult)
    }
    
    func postConsent(_ consent: Consent, completion: @escaping (Error?) -> Void) {
        postedConsents = consent
        completion(postConsentResult)
    }
    
    func getSavedConsents() -> [SavedConsent] {
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
            translations: .init(translations: [], primaryLanguage: nil)
        )
    }
    
    return ConsentSolution(
        id: "1",
        versionId: "1",
        title: .init(
            translations: [
                .init(language: "EN", text: "TestTitle")
            ],
            primaryLanguage: nil
        ),
        description: .init(translations: [], primaryLanguage: nil),
        templateTexts: .init(
            readMoreButton: .init(translations: [], primaryLanguage: nil),
            rejectAllButton: .init(translations: [], primaryLanguage: nil),
            acceptAllButton: .init(translations: [], primaryLanguage: nil),
            acceptSelectedButton: .init(translations: [], primaryLanguage: nil),
            savePreferencesButton: .init(
                translations: [
                    .init(language: "EN", text: "Save preferences button title")
                ],
                primaryLanguage: nil
            ),
            privacyCenterTitle: .init(
                translations: [
                    .init(language: "EN", text: "Privacy center title")
                ],
                primaryLanguage: nil
            ),
            privacyPreferencesTabLabel: .init(translations: [], primaryLanguage: nil),
            poweredByCoiLabel: .init(translations: [], primaryLanguage: nil),
            consentPreferencesLabel: .init(translations: [], primaryLanguage: nil)
        ),
        consentItems: consentItems
    )
}
