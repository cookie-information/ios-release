import Foundation
import XCTest
@testable import MobileConsentsSDK

final class ConsentStoreCompatibilityTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suite = "MobileConsentsSDK.ConsentStoreCompatibilityTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    func testStoreInstancesShareSQLiteDecisionWithoutLegacyWrites() throws {
        let writer = try makeStore()
        let reader = try makeStore()
        let userID = writer.userId
        let consent = value("shared", true)
        writer.recordPostResult(consents: [consent], versionId: "version", isInSync: false)

        let snapshot = try reader.persistenceInspection(
            suiteName: suite,
            clientID: "client"
        )
        XCTAssertEqual(snapshot.userId, userID)
        XCTAssertEqual(snapshot.values, ["shared": consent])
        XCTAssertFalse(snapshot.consentsInSync)
        assertNoLegacy()
    }

    func testClearLeavesEnvelopeAndNextUserIDIsStable() throws {
        let persistence = try makeStore()
        let oldID = persistence.userId
        try persistence.clearAll()

        XCTAssertTrue(
            try persistence.persistenceInspection(
                suiteName: suite,
                clientID: "client"
            ).consentsInSync
        )
        let newID = persistence.userId
        XCTAssertNotEqual(newID, oldID)
        XCTAssertEqual(persistence.userId, newID)
    }

    func testSnapshotDoesNotGenerateUserIDAndNoConsentIsInSync() throws {
        let persistence = try makeStore()
        let snapshot = try persistence.persistenceInspection(
            suiteName: suite,
            clientID: "client"
        )
        XCTAssertNil(snapshot.userId)
        XCTAssertTrue(snapshot.consentsInSync)
    }

    func testMigratesEmptyLegacyDecisionAsPending() throws {
        defaults.set("legacy-user", forKey: LegacyConsentStorageKey.userIdKey)
        defaults.set("legacy-version", forKey: LegacyConsentStorageKey.consentsVersionIdKey)
        defaults.set(false, forKey: LegacyConsentStorageKey.consentsInSyncKey)
        let persistence = try makeStore()
        _ = try persistence.readSnapshot()

        let snapshot = try persistence.persistenceInspection(
            suiteName: suite,
            clientID: "client"
        )

        XCTAssertEqual(snapshot.versionId, "legacy-version")
        XCTAssertEqual(snapshot.submission?.userConsents, [])
        XCTAssertFalse(snapshot.consentsInSync)
    }

    func testMalformedLegacyPayloadIsNotPartiallyImportedAndKeysRemain() throws {
        defaults.set("legacy-user", forKey: LegacyConsentStorageKey.userIdKey)
        defaults.set("legacy-version", forKey: LegacyConsentStorageKey.consentsVersionIdKey)
        defaults.set(
            ["valid": try JSONEncoder().encode(value("valid", true)), "invalid": Data("bad".utf8)],
            forKey: LegacyConsentStorageKey.consentsKey
        )
        let persistence = try makeStore()
        XCTAssertThrowsError(try persistence.readSnapshot()) { error in
            XCTAssertEqual(error as? ConsentStoreError, .readFailed)
        }
        let domain = ConsentStorageDomain.suite(suite)
        try ConsentDatabase(path: domain.consentDatabasePath).initialize()

        let snapshot = try ConsentPersistenceInspection.read(
            databaseURL: URL(fileURLWithPath: domain.consentDatabasePath),
            partition: ConsentPartitionID(
                solutionID: "solution",
                clientID: "client",
                clientSecret: "secret"
            )
        )

        XCTAssertNil(snapshot.userId)
        XCTAssertTrue(snapshot.values.isEmpty)
        XCTAssertNil(snapshot.submission)
        XCTAssertNotNil(defaults.object(forKey: LegacyConsentStorageKey.userIdKey))
        XCTAssertNotNil(defaults.object(forKey: LegacyConsentStorageKey.consentsKey))
        XCTAssertNotNil(defaults.object(forKey: LegacyConsentStorageKey.consentsVersionIdKey))

        defaults.set(
            ["valid": try JSONEncoder().encode(value("valid", true))],
            forKey: LegacyConsentStorageKey.consentsKey
        )
        let retriedStore = try makeStore()
        _ = try retriedStore.readSnapshot()
        let retried = try retriedStore.persistenceInspection(
            suiteName: suite,
            clientID: "client"
        )

        XCTAssertEqual(retried.userId, "legacy-user")
        XCTAssertEqual(retried.versionId, "legacy-version")
        XCTAssertEqual(retried.values, ["valid": value("valid", true)])
        assertNoLegacy()
    }

    func testStaleVersionWithoutLegacyUserIDDoesNotCreateProfile() throws {
        defaults.set("legacy-version", forKey: LegacyConsentStorageKey.consentsVersionIdKey)
        let persistence = try makeStore()
        _ = try persistence.readSnapshot()

        let snapshot = try persistence.persistenceInspection(
            suiteName: suite,
            clientID: "client"
        )

        XCTAssertNil(snapshot.userId)
        XCTAssertNil(snapshot.versionId)
        XCTAssertNil(snapshot.submission)
    }

    func testClearFailurePreservesLegacyKeys() throws {
        defaults.set("legacy-user", forKey: LegacyConsentStorageKey.userIdKey)
        let persistence = ConsentStore(
            database: ConsentDatabase(path: "/dev/null/MobileConsentsSDK.sqlite3"),
            domain: .suite(suite),
            partition: ConsentPartitionID(
                solutionID: "solution",
                clientID: "client",
                clientSecret: "secret"
            )
        )
        XCTAssertThrowsError(try persistence.clearAll()) { error in
            XCTAssertEqual(error as? ConsentStoreError, .persistenceFailed)
        }

        XCTAssertEqual(
            defaults.string(forKey: LegacyConsentStorageKey.userIdKey),
            "legacy-user"
        )
    }

    private func makeStore() throws -> ConsentStore {
        try XCTUnwrap(
            ConsentStore(
                suiteName: suite,
                solutionID: "solution",
                clientID: "client",
                clientSecret: "secret"
            )
        )
    }

    private func assertNoLegacy(file: StaticString = #filePath, line: UInt = #line) {
        [
            LegacyConsentStorageKey.userIdKey,
            LegacyConsentStorageKey.consentsKey,
            LegacyConsentStorageKey.consentsVersionIdKey,
            LegacyConsentStorageKey.consentsInSyncKey
        ].forEach {
            XCTAssertNil(defaults.object(forKey: $0), file: file, line: line)
        }
    }

    private func value(_ id: String, _ selected: Bool) -> UserConsentValue {
        UserConsentValue(
            consentItem: ConsentItem(
                id: id,
                required: false,
                type: .functional,
                translations: Translated(
                    translations: [
                        ConsentTranslation(
                            language: "EN",
                            shortText: "Text",
                            longText: "Details"
                        )
                    ],
                    primaryLanguage: nil
                )
            ),
            isSelected: selected
        )
    }
}
