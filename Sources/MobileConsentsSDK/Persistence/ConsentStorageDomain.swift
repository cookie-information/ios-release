import Foundation

struct ConsentStorageDomain: Hashable, Sendable {
    static let standard = ConsentStorageDomain(
        legacyUserDefaultsSuiteName: nil,
        consentDatabasePath: FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("MobileConsentsSDK.sqlite3").path
    )

    private let legacyUserDefaultsSuiteName: String?
    let consentDatabasePath: String

    init(
        legacyUserDefaultsSuiteName: String?,
        consentDatabasePath: String
    ) {
        self.legacyUserDefaultsSuiteName = legacyUserDefaultsSuiteName
        self.consentDatabasePath = consentDatabasePath
    }

    func makeLegacyUserDefaults() -> UserDefaults? {
        if let legacyUserDefaultsSuiteName {
            return UserDefaults(suiteName: legacyUserDefaultsSuiteName)
        }
        return .standard
    }
}
