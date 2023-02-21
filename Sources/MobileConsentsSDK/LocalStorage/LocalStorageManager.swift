import UIKit

protocol LocalStorageManagerProtocol {
    var userId: String { get }
    var consents: [String: UserConsent] { get }
    func removeUserId()
    func addConsent(consentItemId: String, consent: UserConsent)
    func addConsentsArray(_ consentsArray: [UserConsent], versionId: String)
    func clearAll()
}

struct LocalStorageManager: LocalStorageManagerProtocol {
    
    private let userIdKey = "com.MobileConsents.userIdKey"
    private let consentsKey = "com.MobileConsents.consentsKey"
    private let consentSolutionVersionIdKey = "com.MobileConsents.consentsVersionIdKey"
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults = UserDefaults.standard) {
        self.userDefaults = userDefaults
    }
    
    internal var userId: String {
        guard let userId: String = userDefaults.get(forKey: userIdKey) else {
            return generateAndStoreUserId()
        }
        return userId
    }
    
    internal var versionId: String? {
        let id: String? = userDefaults.get(forKey: consentSolutionVersionIdKey)
        return id
    }
    
    private func generateAndStoreUserId() -> String {
        let userId = UUID().uuidString
        userDefaults.set(userId, forKey: userIdKey)
        return userId
    }
    
    func removeUserId() {
        userDefaults.removeObject(forKey: userId)
    }
    
    var consents: [String: UserConsent] {
        guard let consents: [String: Any] = userDefaults.get(forKey: consentsKey) else { return [:] }
        return  consents
            .map { dict -> [String: UserConsent] in
                do {
                    let decoded = try JSONDecoder().decode(UserConsent.self, from: dict.value as? Data ?? Data())
                    return [dict.key : decoded]
                } catch {
                    debugPrint(error)
                }
                return [:]
            }
            .flatMap {$0}
            .reduce([String: UserConsent](), { partialResult, tuple in
                var dict = partialResult
                dict[tuple.0] = tuple.1
                return dict
            })
        
    }
    
    func addConsent(consentItemId: String, consent: UserConsent) {
        var consents = self.consents
        consents[consentItemId] = consent
        userDefaults.set(consents, forKey: consentsKey)
        
    }
    
    func addConsentsArray(_ consentsArray: [UserConsent], versionId: String) {
        var consents = [String: Any]()
        userDefaults.set(versionId, forKey: consentSolutionVersionIdKey)
        consentsArray.forEach { consent in
            do {
                let id = consent.consentItem.id
                let encoded = try JSONEncoder().encode(consent)
                consents[id] = encoded
            } catch {
                debugPrint(error)
            }
            userDefaults.set(consents, forKey: consentsKey)
        }
    }
    
    
    
    func clearAll() {
        userDefaults.removeObject(forKey: userIdKey)
        userDefaults.removeObject(forKey: consentsKey)
    }
}


