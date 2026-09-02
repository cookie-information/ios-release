import Foundation

struct ConsentStorageDomain: Hashable, Sendable {
    private static let applicationSupportDirectory = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    ).first ?? FileManager.default.temporaryDirectory.appendingPathComponent(
        "MobileConsentsSDK",
        isDirectory: true
    )

    static let standard = ConsentStorageDomain(
        legacyUserDefaultsSuiteName: nil,
        consentDatabasePath: applicationSupportDirectory
            .appendingPathComponent("MobileConsentsSDK.sqlite3")
            .path
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
