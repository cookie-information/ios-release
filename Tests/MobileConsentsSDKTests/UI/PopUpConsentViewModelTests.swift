import XCTest
@testable import MobileConsentsSDK

@MainActor
final class PopUpConsentViewModelTests: XCTestCase {
    var sut: PopUpConsentViewModel!

    private var notificationCenter: NotificationCenter!
    private var consentItemProvider: ConsentItemProviderMock!

    override func setUp() async throws {
        notificationCenter = NotificationCenter()
        consentItemProvider = ConsentItemProviderMock()
        sut = PopUpConsentViewModel(
            id: "testId",
            title: "",
            description: "",
            isRequired: true,
            consentItemProvider: consentItemProvider,
            notificationCenter: notificationCenter,
            accentColor: .white,
            fontSet: .standard
        )
    }

    func test_consentIsNotSelectedWhenProviderReportsItAsNotSelected() {
        consentItemProvider.consentItemSelections["testId"] = false

        XCTAssertFalse(sut.isSelected)
    }

    func test_consentIsSelectedWhenProviderReportsItAsSelected() {
        consentItemProvider.consentItemSelections["testId"] = true

        XCTAssertTrue(sut.isSelected)
    }

    func test_consentIsSelectedWhenProviderReportsItAsRequired() {
        consentItemProvider.requiredConsentItemIds = ["testId"]

        XCTAssertTrue(sut.isSelected)
    }

    func test_changingSelectionMarksConsent() {
        sut.selectionDidChange(true)

        XCTAssertTrue(try XCTUnwrap(consentItemProvider.consentItemSelections["testId"]))
    }

    func test_onUpdateIsCalledWhenCorrectNotificationIsPosted() {
        var onUpdateCalled = false

        sut.onUpdate = { _ in
            onUpdateCalled = true
        }

        notificationCenter.post(.init(name: ConsentSolutionManager.consentItemSelectionDidChange))

        XCTAssertTrue(onUpdateCalled)
    }

    func test_onUpdateIsCalledOnMainThreadWhenCorrectNotificationIsPostedInBackground() async {
        let postReturned = expectation(description: "Background post returned")
        let callback = expectation(description: "Update callback")
        postReturned.assertForOverFulfill = true
        callback.assertForOverFulfill = true
        sut.onUpdate = { _ in
            XCTAssertTrue(Thread.isMainThread)
            callback.fulfill()
        }
        let poster = BackgroundNotificationPoster(
            notificationCenter: notificationCenter,
            name: ConsentSolutionManager.consentItemSelectionDidChange,
            postReturned: postReturned
        )

        poster.start()

        await fulfillment(of: [postReturned, callback], timeout: 2)
    }

    func test_onUpdateIsNotCalledForWrongNotification() {
        let callback = expectation(description: "Update callback")
        callback.isInverted = true
        sut.onUpdate = { _ in
            callback.fulfill()
        }

        notificationCenter.post(.init(name: .init("wrongNotification")))

        wait(for: [callback], timeout: 0.1)
    }

    func test_viewModelDeallocatesAndStopsObserving() {
        let callback = expectation(description: "Update callback")
        callback.isInverted = true
        var viewModel: PopUpConsentViewModel? = sut
        viewModel?.onUpdate = { _ in
            callback.fulfill()
        }
        weak var weakViewModel: PopUpConsentViewModel?
        weakViewModel = viewModel

        sut = nil
        viewModel = nil

        XCTAssertNil(weakViewModel)
        notificationCenter.post(.init(name: ConsentSolutionManager.consentItemSelectionDidChange))
        wait(for: [callback], timeout: 0.1)
    }
}

private final class BackgroundNotificationPoster: NSObject {
    private let notificationCenter: NotificationCenter
    private let name: Notification.Name
    private let postReturned: XCTestExpectation

    init(
        notificationCenter: NotificationCenter,
        name: Notification.Name,
        postReturned: XCTestExpectation
    ) {
        self.notificationCenter = notificationCenter
        self.name = name
        self.postReturned = postReturned
    }

    func start() {
        performSelector(inBackground: #selector(post), with: nil)
    }

    @objc private func post() {
        XCTAssertFalse(Thread.isMainThread)
        notificationCenter.post(.init(name: name))
        postReturned.fulfill()
    }
}
