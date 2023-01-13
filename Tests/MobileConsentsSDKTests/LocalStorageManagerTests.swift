import XCTest

final class LocalStorageManagerTests: XCTestCase {
    let localStorageManager: LocalStorageManagerProtocol = LocalStorageManager(userDefaults: MockedUserDefaults())
    
    override func setUp() {
        localStorageManager.clearAll()
    }
    
    func testGetUserId() throws {
        XCTAssertNotNil(localStorageManager.userId)
    }
    
    func testNotRegenerateUserId() throws {
        let firstUserId = localStorageManager.userId
        let secondUserId = localStorageManager.userId
        XCTAssertEqual(firstUserId, secondUserId)
    }
    
    func testAddUniqueConsent() throws {
        localStorageManager.addConsent(consentItemId: "CONSENT_ID_1", consentGiven: true)
        let consents = localStorageManager.consents
        
        XCTAssertEqual(consents.count, 1)
        XCTAssertEqual(consents.first?.key, "CONSENT_ID_1")
        XCTAssertEqual(consents.first?.value, true)
    }
    
    func testAddNotUniqueConsent() throws {
        localStorageManager.addConsent(consentItemId: "CONSENT_ID_1", consentGiven: true)
        localStorageManager.addConsent(consentItemId: "CONSENT_ID_1", consentGiven: true)
        let consents = localStorageManager.consents
        
        XCTAssertEqual(consents.count, 1)
        XCTAssertEqual(consents.first?.key, "CONSENT_ID_1")
        XCTAssertEqual(consents.first?.value, true)
    }

    func testAddUniqueConsentsArray() throws {
        let newConsents = [["CONSENT_ID_1": true], ["CONSENT_ID_2": true]]
        localStorageManager.addConsentsArray(newConsents)
        let consents = localStorageManager.consents
        
        XCTAssertEqual(consents.count, 2)
    }
    
    func testAddNotUniqueConsentsArray() throws {
        let newConsents = [["CONSENT_ID_1": true], ["CONSENT_ID_1": true]]
        localStorageManager.addConsentsArray(newConsents)
        let consents = localStorageManager.consents
        
        XCTAssertEqual(consents.count, 1)
    }
}
