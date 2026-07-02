import XCTest
@testable import MobileConsentsSDK

class PopUpConsentViewModelTests: XCTestCase {
    var sut: PopUpConsentViewModel!

    private var notificationCenter: NotificationCenter!
    private var consentItemProvider: ConsentItemProviderMock!

    override func setUpWithError() throws {
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

final class ConsentItemProviderMock: ConsentItemProvider {
    var consentItemSelections = [String: Bool]()
    var requiredConsentItemIds = Set<String>()

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
