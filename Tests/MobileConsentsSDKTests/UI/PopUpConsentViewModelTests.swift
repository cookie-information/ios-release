import XCTest
@testable import MobileConsentsSDK

class PopUpConsentViewModelTests: XCTestCase {
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
}
