import XCTest
@testable import MobileConsentsSDK

@MainActor
class PrivacyPopUpViewModelTests: XCTestCase {
    var sut: PrivacyPopUpViewModel!
    var consentSolutionManager: ConsentSolutionManagerMock!
    var router: RouterMock!

    var isLoading: Bool?
    var loadedData: PrivacyPopUpData?

    private let sampleError = NSError(domain: "Sample", code: 1234)

    override func setUp() async throws {
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

    func test_tappingRejectAllKeepsPopupOpenUntilSaveFinishes() {
        assertSavePending(for: { $0.rejectAll() })
    }

    func test_tappingAcceptAllKeepsPopupOpenUntilSaveFinishes() {
        assertSavePending(for: { $0.acceptAll() })
    }

    func test_tappingAcceptSelectedKeepsPopupOpenUntilSaveFinishes() {
        assertSavePending(for: { $0.acceptSelected() })
    }

    func test_tappingAcceptAllCompletesCallbacksAfterLateSuccess() {
        sut.acceptAll()
        consentSolutionManager.completion?(nil)

        XCTAssertEqual(router.closeAllCallCount, 1)
        XCTAssertNil(router.closeAllError)
        XCTAssertFalse(try XCTUnwrap(isLoading))
    }

    func test_tappingAcceptAllCompletesErrorHandlerAfterLateFailure() {
        sut.acceptAll()
        consentSolutionManager.completion?(sampleError)

        XCTAssertEqual(router.closeAllCallCount, 1)
        XCTAssertEqual(router.closeAllError as NSError?, sampleError)
        XCTAssertFalse(try XCTUnwrap(isLoading))
    }

    func test_doubleTapEnqueuesOnlyOneSubmission() {
        sut.acceptAll()
        sut.acceptAll()

        XCTAssertEqual(consentSolutionManager.acceptAllCallCount, 1)
        XCTAssertEqual(router.closeAllCallCount, 0)
    }

    func test_tappingAcceptBeforeConsentSolutionIsLoadedKeepsPopUpOpenAndHidesLoader() {
        sut.acceptAll()

        XCTAssertEqual(router.closeAllCallCount, 0)

        consentSolutionManager.completion?(ConsentSolutionManagerError.consentSolutionNotLoaded)

        XCTAssertFalse(try XCTUnwrap(isLoading))
    }

    func test_postingCompletionKeepsViewModelAliveUntilItFinishes() {
        sut.acceptAll()
        weak var viewModel: PrivacyPopUpViewModel?
        viewModel = sut
        sut = nil

        XCTAssertNotNil(viewModel)

        do {
            let completion = consentSolutionManager.completion
            consentSolutionManager.completion = nil
            completion?(nil)
        }

        XCTAssertNil(viewModel)
        XCTAssertEqual(router.closeAllCallCount, 1)
    }

    private func assertSavePending(for action: (PrivacyPopUpViewModel) -> Void) {
        action(sut)

        XCTAssertNotNil(consentSolutionManager.completion)
        XCTAssertEqual(router.closeAllCallCount, 0)
        XCTAssertTrue(try XCTUnwrap(isLoading))
    }
}

// Inherits the ConsentItemProvider stubbing from the shared ConsentItemProviderMock.
final class ConsentSolutionManagerMock: ConsentItemProviderMock, ConsentSolutionManagerProtocol {
    var settings: [ConsentItem] { [] }
    var localizationOverride: [Locale: LabelText] = [:]

    var loadConsentSolutionIfNeededCompletion: ((Result<ConsentSolution, Error>) -> Void)?

    var completion: ((Error?) -> Void)?
    private(set) var acceptAllCallCount = 0

    func loadConsentSolutionIfNeeded(completion: @escaping (Result<ConsentSolution, Error>) -> Void) {
        loadConsentSolutionIfNeededCompletion = completion
    }

    func rejectAllConsentItems(completion: @escaping (Error?) -> Void) {
        self.completion = completion
    }

    func acceptAllConsentItems(completion: @escaping (Error?) -> Void) {
        acceptAllCallCount += 1
        self.completion = completion
    }

    func acceptSelectedConsentItems(completion: @escaping (Error?) -> Void) {
        self.completion = completion
    }

}

final class RouterMock: RouterProtocol {
    private(set) var closeAllCalled = false
    private(set) var closeAllCallCount = 0
    private(set) var closeAllError: Error?

    func closeAll(error: Error?) {
        closeAllCalled = true
        closeAllCallCount += 1
        closeAllError = error
    }
}
