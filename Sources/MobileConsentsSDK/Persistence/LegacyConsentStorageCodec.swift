import Foundation

enum LegacyConsentStorageKey {
    static let userIdKey = "com.MobileConsents.userIdKey"
    static let consentsKey = "com.MobileConsents.consentsKey"
    static let consentsVersionIdKey = "com.MobileConsents.consentsVersionIdKey"
    static let consentsInSyncKey = "com.MobileConsents.consentsInSync"
}

enum LegacyConsentStorageCodec {
    static func strictDecode(_ storedObject: Any?) throws -> [String: UserConsentValue] {
        guard let storedObject else {
            return [:]
        }
        guard let storedEntries = storedObject as? [String: Any] else {
            throw ConsentStoreError.readFailed
        }

        do {
            var decodedValues = [String: UserConsentValue]()
            for (consentID, storedValue) in storedEntries {
                guard let data = storedValue as? Data else {
                    throw ConsentStoreError.readFailed
                }
                decodedValues[consentID] = try JSONDecoder().decode(
                    UserConsentValue.self,
                    from: data
                )
            }
            return decodedValues
        } catch {
            throw ConsentStoreError.readFailed
        }
    }
}
