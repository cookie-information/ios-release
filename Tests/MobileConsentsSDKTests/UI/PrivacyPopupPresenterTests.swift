import UIKit
import XCTest
@testable import MobileConsentsSDK

@MainActor
final class PrivacyPopupPresenterTests: XCTestCase {
    func testBackgroundCallPresentsCustomPopupAndCompletesOnMainThread() async throws {
        let suiteName = "PrivacyPopupPresenterTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(forResource: "ConsentSolution", withExtension: "json")
        )
        let transport = PrivacyPopupPresenterHTTPTransport(
            responseBody: try Data(contentsOf: fixtureURL)
        )

        let mobileConsents = try XCTUnwrap(MobileConsents(
            storageSuiteName: suiteName,
            transport: transport,
            uiLanguageCode: "en",
            clientID: "client-id",
            clientSecret: "client-secret",
            solutionID: "solution-id",
            accentColor: nil,
            fontSet: .standard
        ))
        let presenter = RecordingPresentingViewController()
        let backgroundCall = expectation(description: "Public API called off the main thread")
        let presentation = expectation(description: "Custom popup presented")
        let dataLoaded = expectation(description: "Custom popup view model loaded fixture data")
        let completion = expectation(description: "Completion called")
        backgroundCall.assertForOverFulfill = true
        presentation.assertForOverFulfill = true
        dataLoaded.assertForOverFulfill = true
        completion.assertForOverFulfill = true
        let customViewType: PrivacyPopupProtocol.Type = ClosingPrivacyPopupViewController.self

        presenter.onPresent = { viewController, animated in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertFalse(animated)
            let popup = viewController as? ClosingPrivacyPopupViewController
            XCTAssertNotNil(popup)
            presentation.fulfill()

            popup?.load {
                XCTAssertTrue(Thread.isMainThread)
                dataLoaded.fulfill()
                popup?.close()
            }
        }

        let invoker = BackgroundPrivacyPopupInvoker(
            mobileConsents: mobileConsents,
            customViewType: customViewType,
            presenter: presenter,
            backgroundCall: backgroundCall,
            completion: { consents in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(consents.count, 3)
                completion.fulfill()
            },
            errorHandler: { error in
                XCTFail("Unexpected error: \(error)")
            }
        )
        defer { withExtendedLifetime(invoker) {} }
        invoker.start()

        await fulfillment(of: [backgroundCall, presentation, dataLoaded, completion], timeout: 2.0)

        let fetchCount = await transport.fetchCount()

        XCTAssertEqual(fetchCount, 1)
    }
}

private final class BackgroundPrivacyPopupInvoker: NSObject {
    private let mobileConsents: MobileConsents
    private let customViewType: PrivacyPopupProtocol.Type
    private let presenter: UIViewController
    private let backgroundCall: XCTestExpectation
    private let completion: ([UserConsent]) -> Void
    private let errorHandler: (Error) -> Void

    init(
        mobileConsents: MobileConsents,
        customViewType: PrivacyPopupProtocol.Type,
        presenter: UIViewController,
        backgroundCall: XCTestExpectation,
        completion: @escaping ([UserConsent]) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {
        self.mobileConsents = mobileConsents
        self.customViewType = customViewType
        self.presenter = presenter
        self.backgroundCall = backgroundCall
        self.completion = completion
        self.errorHandler = errorHandler
    }

    func start() {
        performSelector(inBackground: #selector(invoke), with: nil)
    }

    @objc private func invoke() {
        XCTAssertFalse(Thread.isMainThread)
        backgroundCall.fulfill()
        mobileConsents.showPrivacyPopUp(
            customViewType: customViewType,
            onViewController: presenter,
            animated: false,
            completion: completion,
            errorHandler: errorHandler
        )
    }
}

private actor PrivacyPopupPresenterHTTPTransport: HTTPTransport {
    private let responseBody: Data
    private var count = 0

    init(responseBody: Data) {
        self.responseBody = responseBody
    }

    func start(
        snapshot: HTTPRequestSnapshot,
        id _: HTTPRequestID
    ) async throws -> HTTPTransportOperation {
        count += 1
        let task = Task<HTTPResponseSnapshot, Error>(
            name: "PrivacyPopupPresenterTests.HTTPTransport.fixtureResponse"
        ) {
            HTTPResponseSnapshot(
                url: snapshot.url,
                statusCode: 200,
                body: self.responseBody
            )
        }
        return HTTPTransportOperation(task: task)
    }

    func fetchCount() -> Int {
        count
    }
}

private final class RecordingPresentingViewController: UIViewController {
    var onPresent: ((UIViewController, Bool) -> Void)?
    private var retainedPresentedViewController: UIViewController?

    override func present(
        _ viewControllerToPresent: UIViewController,
        animated flag: Bool,
        completion: (() -> Void)? = nil
    ) {
        retainedPresentedViewController = viewControllerToPresent
        onPresent?(viewControllerToPresent, flag)
        completion?()
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        retainedPresentedViewController = nil
        completion?()
    }
}

private final class ClosingPrivacyPopupViewController: UIViewController, PrivacyPopupProtocol {
    private let viewModel: PrivacyPopUpViewModel

    init(viewModel: PrivacyPopUpViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func load(onDataLoaded: @escaping () -> Void) {
        viewModel.onDataLoaded = { _ in
            onDataLoaded()
        }
        viewModel.viewDidLoad()
    }

    func close() {
        viewModel.router?.closeAll(error: nil)
    }
}
