import XCTest
@testable import MobileConsentsSDK

final class LocalStorageManagerTests: XCTestCase {
    private static let suiteName = "MobileConsentsSDKTests"

    private var userDefaults: UserDefaults!
    private var localStorageManager: LocalStorageManager!

    override func setUpWithError() throws {
        userDefaults = try XCTUnwrap(UserDefaults(suiteName: Self.suiteName))
        userDefaults.removePersistentDomain(forName: Self.suiteName)
        localStorageManager = LocalStorageManager(userDefaults: userDefaults)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: Self.suiteName)
    }

    func testGetUserId() throws {
        XCTAssertFalse(localStorageManager.userId.isEmpty)
    }

    func testNotRegenerateUserId() throws {
        let firstUserId = localStorageManager.userId
        let secondUserId = localStorageManager.userId
        XCTAssertEqual(firstUserId, secondUserId)
    }

    func testAddUniqueConsentsArray() throws {
        let newConsents = [
            userConsent(consentItemId: "CONSENT_ID_1", isSelected: true),
            userConsent(consentItemId: "CONSENT_ID_2", isSelected: false)
        ]
        localStorageManager.addConsentsArray(newConsents, versionId: "VERSION_ID")
        let consents = localStorageManager.consents

        XCTAssertEqual(consents.count, 2)
        XCTAssertEqual(consents["CONSENT_ID_1"]?.isSelected, true)
        XCTAssertEqual(consents["CONSENT_ID_2"]?.isSelected, false)
    }

    func testAddNotUniqueConsentsArray() throws {
        let newConsents = [
            userConsent(consentItemId: "CONSENT_ID_1", isSelected: true),
            userConsent(consentItemId: "CONSENT_ID_1", isSelected: true)
        ]
        localStorageManager.addConsentsArray(newConsents, versionId: "VERSION_ID")
        let consents = localStorageManager.consents

        XCTAssertEqual(consents.count, 1)
        XCTAssertEqual(consents.first?.key, "CONSENT_ID_1")
    }

    func testAddConsentsArrayStoresVersionId() throws {
        localStorageManager.addConsentsArray(
            [userConsent(consentItemId: "CONSENT_ID_1", isSelected: true)],
            versionId: "VERSION_ID"
        )

        XCTAssertEqual(localStorageManager.versionId, "VERSION_ID")
    }

    func testClearAllRemovesConsents() throws {
        localStorageManager.addConsentsArray(
            [userConsent(consentItemId: "CONSENT_ID_1", isSelected: true)],
            versionId: "VERSION_ID"
        )

        localStorageManager.clearAll()

        XCTAssertTrue(localStorageManager.consents.isEmpty)
    }

    private func userConsent(consentItemId: String, isSelected: Bool) -> UserConsent {
        UserConsent(
            consentItem: ConsentItem(
                id: consentItemId,
                required: false,
                type: .functional,
                translations: Translated(translations: [], primaryLanguage: nil)
            ),
            isSelected: isSelected
        )
    }
}
