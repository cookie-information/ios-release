import XCTest
@testable import MobileConsentsSDK

class PrivacyPopUpViewModelTests: XCTestCase {
    var sut: PrivacyPopUpViewModel!
    var consentSolutionManager: ConsentSolutionManagerMock!
    var router: RouterMock!

    var isLoading: Bool?
    var loadedData: PrivacyPopUpData?

    private let sampleError = NSError(domain: "Sample", code: 1234)

    override func setUpWithError() throws {
        consentSolutionManager = ConsentSolutionManagerMock()
        router = RouterMock()
        sut = PrivacyPopUpViewModel(
            consentSolutionManager: consentSolutionManager,
            accentColor: .popUpBackground,
            fontSet: .standard
        )
        sut.router = router
        isLoading = nil
        loadedData = nil

        sut.onLoadingChange = { [weak self] isLoading in
            self?.isLoading = isLoading
        }

        sut.onDataLoaded = { [weak self] data in
            self?.loadedData = data
        }
    }

    func test_viewDidLoadShowsLoader() {
        sut.viewDidLoad()

        XCTAssertTrue(try XCTUnwrap(isLoading))
    }

    func test_loaderIsHiddenAfterLoadingConsentSolutionFinishesWithSuccess() {
        sut.viewDidLoad()

        consentSolutionManager.loadConsentSolutionIfNeededCompletion?(.success(consentSolution(consentItemConfigs: [])))

        XCTAssertFalse(try XCTUnwrap(isLoading))
    }

    func test_loaderIsHiddenAfterLoadingConsentSolutionFinishesWithError() {
        sut.viewDidLoad()

        consentSolutionManager.loadConsentSolutionIfNeededCompletion?(.failure(sampleError))

        XCTAssertFalse(try XCTUnwrap(isLoading))
    }

    func test_popUpIsClosedWithErrorAfterLoadingConsentSolutionFinishesWithError() {
        sut.viewDidLoad()

        consentSolutionManager.loadConsentSolutionIfNeededCompletion?(.failure(sampleError))

        XCTAssertTrue(router.closeAllCalled)
        XCTAssertNotNil(router.closeAllError)
    }

    func test_dataIsLoadedAfterLoadingConsentSolutionFinishes() {
        sut.viewDidLoad()

        consentSolutionManager.loadConsentSolutionIfNeededCompletion?(.success(consentSolution(consentItemConfigs: [])))

        XCTAssertNotNil(loadedData)
    }

    func test_loadedDataIsCorrect() throws {
        sut.viewDidLoad()

        let solution = consentSolution(consentItemConfigs: [])

        consentSolutionManager.loadConsentSolutionIfNeededCompletion?(.success(solution))

        let data = try XCTUnwrap(loadedData)

        XCTAssertEqual(data.title, solution.templateTexts.privacyCenterTitle.primaryTranslation().text)
        XCTAssertEqual(data.acceptAllButtonTitle, solution.templateTexts.acceptAllButton.primaryTranslation().text)
        XCTAssertEqual(data.saveSelectionButtonTitle, solution.templateTexts.acceptSelectedButton.primaryTranslation().text)
        XCTAssertEqual(data.readMoreButton, solution.templateTexts.readMoreButton.primaryTranslation().text)
    }

    func test_tappingRejectAllButtonShowsLoaderAndHidesItAfterFinish() {
        sut.buttonTapped(type: .rejectAll)

        XCTAssertTrue(try XCTUnwrap(isLoading))

        consentSolutionManager.completion?(nil)

        XCTAssertFalse(try XCTUnwrap(isLoading))
    }

    func test_tappingRejectAllClosesAfterSuccessfulFinish() {
        sut.buttonTapped(type: .rejectAll)

        consentSolutionManager.completion?(nil)

        XCTAssertTrue(router.closeAllCalled)
        XCTAssertNil(router.closeAllError)
    }

    func test_tappingRejectAllClosesWithErrorAfterError() {
        sut.buttonTapped(type: .rejectAll)

        consentSolutionManager.completion?(sampleError)

        XCTAssertTrue(router.closeAllCalled)
        XCTAssertNotNil(router.closeAllError)
    }

    func test_tappingAcceptAllButtonShowsLoaderAndHidesItAfterFinish() {
        sut.buttonTapped(type: .acceptAll)

        XCTAssertTrue(try XCTUnwrap(isLoading))

        consentSolutionManager.completion?(nil)

        XCTAssertFalse(try XCTUnwrap(isLoading))
    }

    func test_tappingAcceptAllClosesAfterSuccessfulFinish() {
        sut.buttonTapped(type: .acceptAll)

        consentSolutionManager.completion?(nil)

        XCTAssertTrue(router.closeAllCalled)
        XCTAssertNil(router.closeAllError)
    }

    func test_tappingAcceptAllClosesWithErrorAfterError() {
        sut.buttonTapped(type: .acceptAll)

        consentSolutionManager.completion?(sampleError)

        XCTAssertTrue(router.closeAllCalled)
        XCTAssertNotNil(router.closeAllError)
    }

    func test_tappingAcceptSelectedButtonShowsLoaderAndHidesItAfterFinish() {
        sut.buttonTapped(type: .acceptSelected)

        XCTAssertTrue(try XCTUnwrap(isLoading))

        consentSolutionManager.completion?(nil)

        XCTAssertFalse(try XCTUnwrap(isLoading))
    }

    func test_tappingAcceptSelectedClosesAfterSuccessfulFinish() {
        sut.buttonTapped(type: .acceptSelected)

        consentSolutionManager.completion?(nil)

        XCTAssertTrue(router.closeAllCalled)
        XCTAssertNil(router.closeAllError)
    }

    func test_tappingAcceptSelectedClosesWithErrorAfterError() {
        sut.buttonTapped(type: .acceptSelected)

        consentSolutionManager.completion?(sampleError)

        XCTAssertTrue(router.closeAllCalled)
        XCTAssertNotNil(router.closeAllError)
    }
}

final class ConsentSolutionManagerMock: ConsentSolutionManagerProtocol {
    var settings: [ConsentItem] { [] }
    var localizationOverride: [Locale: LabelText] = [:]

    var areAllRequiredConsentItemsSelected = false
    var hasRequiredConsentItems = true
    var consentItemSelections = [String: Bool]()
    var requiredConsentItemIds = Set<String>()

    var loadConsentSolutionIfNeededCompletion: ((Result<ConsentSolution, Error>) -> Void)?

    var completion: ((Error?) -> Void)?

    func loadConsentSolutionIfNeeded(completion: @escaping (Result<ConsentSolution, Error>) -> Void) {
        loadConsentSolutionIfNeededCompletion = completion
    }

    func rejectAllConsentItems(completion: @escaping (Error?) -> Void) {
        self.completion = completion
    }

    func acceptAllConsentItems(completion: @escaping (Error?) -> Void) {
        self.completion = completion
    }

    func acceptSelectedConsentItems(completion: @escaping (Error?) -> Void) {
        self.completion = completion
    }

    func isConsentItemSelected(id: String) -> Bool {
        consentItemSelections[id, default: false]
    }

    func isConsentItemRequired(id: String) -> Bool {
        requiredConsentItemIds.contains(id)
    }

    func markConsentItem(id: String, asSelected selected: Bool) {
        consentItemSelections[id] = selected
    }
}

final class RouterMock: RouterProtocol {
    private(set) var closeAllCalled = false
    private(set) var closeAllError: Error?

    func closeAll(error: Error?) {
        closeAllCalled = true
        closeAllError = error
    }
}
