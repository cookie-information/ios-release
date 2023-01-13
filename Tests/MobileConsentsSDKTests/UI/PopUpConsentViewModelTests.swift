import XCTest

class PopUpConsentViewModelTests: XCTestCase {
    var sut: PopUpConsentViewModel!
    
    private var notificationCenter: NotificationCenter!
    private var consentItemProvider: ConsentItemProviderMock!

    override func setUpWithError() throws {
        notificationCenter = .default
        consentItemProvider = ConsentItemProviderMock()
        sut = PopUpConsentViewModel(
            id: "testId",
            title: "",
            description: "",
            isRequired: true,
            consentItemProvider: consentItemProvider,
            notificationCenter: notificationCenter,
            accentColor: .white
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
    func isConsentItemRequired(id: String) -> Bool {
        true
    }
    
    var consentItemSelections = [String: Bool]()
    
    func isConsentItemSelected(id: String) -> Bool {
        consentItemSelections[id, default: false]
    }
    
    func markConsentItem(id: String, asSelected selected: Bool) {
        consentItemSelections[id] = selected
    }
}
