import Foundation
import SQLite3
import XCTest
@testable import MobileConsentsSDK

final class ConsentStoreTests: XCTestCase {
    private var latestSuiteName: String!

    func testRoundTripsFullPendingSubmission() async throws {
        let storage = try makeStorage()
        let submission = submission(
            values: [value("full", true)],
            purposes: [
                ProcessingPurpose(
                    consentItemId: "purpose",
                    consentGiven: false,
                    language: "pl"
                )
            ],
            customData: ["region": "EU"]
        )

        try storage.savePending(
            submission: submission
        )

        let snapshot = try storage.persistenceInspection(
            suiteName: latestSuiteName,
            clientID: "client"
        )
        XCTAssertEqual(snapshot.submission, submission)
        XCTAssertFalse(snapshot.consentsInSync)
    }

    func testEmptySubmissionReplacesPreviousState() async throws {
        let storage = try makeStorage()
        try storage.savePending(
            submission: submission(version: "old", values: [value("old", true)])
        )

        try storage.savePending(
            submission: submission(values: [])
        )

        let snapshot = try storage.persistenceInspection(
            suiteName: latestSuiteName,
            clientID: "client"
        )
        XCTAssertEqual(snapshot.values, [:])
        XCTAssertEqual(snapshot.versionId, "version")
        XCTAssertFalse(snapshot.consentsInSync)
    }

    func testClaimReleaseAndCompletionRoundTripThroughStore() throws {
        let storage = try makeStorage()
        try storage.savePending(
            submission: submission(values: [value("value", true)])
        )
        let firstClaim = try XCTUnwrap(
            storage.claimPendingSynchronization()
        )

        XCTAssertNil(try storage.claimPendingSynchronization())
        XCTAssertTrue(try storage.releaseSynchronizationClaim(firstClaim))

        let retryClaim = try XCTUnwrap(
            storage.claimPendingSynchronization()
        )
        XCTAssertEqual(retryClaim.revisionID, firstClaim.revisionID)
        XCTAssertTrue(try storage.completeSynchronizationClaim(retryClaim))
        XCTAssertTrue(
            try storage.persistenceInspection(
                suiteName: latestSuiteName,
                clientID: "client"
            ).consentsInSync
        )
    }

    func testClaimOperationsReportPersistenceFailure() {
        let suite = uniqueSuiteName()
        let storage = ConsentStore(
            database: ConsentDatabase(path: "/dev/null/MobileConsentsSDK.sqlite3"),
            domain: .suite(suite),
            partition: ConsentPartitionID(
                solutionID: "solution",
                clientID: "client",
                clientSecret: "secret"
            )
        )
        let claim = ConsentSynchronizationClaim(
            userID: "user",
            revisionID: UUID(),
            solutionVersionID: "version",
            submission: submission(values: []),
            claimedAt: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertThrowsError(try storage.claimPendingSynchronization()) { error in
            XCTAssertEqual(error as? ConsentStoreError, .persistenceFailed)
        }
        XCTAssertThrowsError(try storage.completeSynchronizationClaim(claim)) { error in
            XCTAssertEqual(error as? ConsentStoreError, .persistenceFailed)
        }
        XCTAssertThrowsError(try storage.releaseSynchronizationClaim(claim)) { error in
            XCTAssertEqual(error as? ConsentStoreError, .persistenceFailed)
        }
    }

    func testMigratesCompleteReleasedStorageAndRemovesLegacyKeys() async throws {
        let suite = uniqueSuiteName()
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set("legacy-user", forKey: LegacyConsentStorageKey.userIdKey)
        defaults.set("legacy-version", forKey: LegacyConsentStorageKey.consentsVersionIdKey)
        defaults.set(false, forKey: LegacyConsentStorageKey.consentsInSyncKey)
        defaults.set(
            try encodeLegacy([value("legacy", true)]),
            forKey: LegacyConsentStorageKey.consentsKey
        )
        let storage = try XCTUnwrap(
            ConsentStore(
                suiteName: suite,
                solutionID: "solution",
                clientID: "client",
                clientSecret: "secret"
            )
        )
        _ = try storage.readSnapshot()

        let snapshot = try storage.persistenceInspection(
            suiteName: suite,
            clientID: "client"
        )

        XCTAssertEqual(snapshot.userId, "legacy-user")
        XCTAssertEqual(snapshot.versionId, "legacy-version")
        XCTAssertEqual(snapshot.submission?.consentSolutionId, "solution")
        XCTAssertFalse(snapshot.consentsInSync)
        assertNoLegacy(in: defaults)
    }

    func testMigratesEmptyReleasedStorageAsSynchronizedDecision() async throws {
        let suite = uniqueSuiteName()
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set("legacy-user", forKey: LegacyConsentStorageKey.userIdKey)
        defaults.set("legacy-version", forKey: LegacyConsentStorageKey.consentsVersionIdKey)
        let storage = try XCTUnwrap(
            ConsentStore(suiteName: suite, solutionID: "solution", clientID: "client", clientSecret: "secret")
        )
        _ = try storage.readSnapshot()

        let snapshot = try storage.persistenceInspection(
            suiteName: suite,
            clientID: "client"
        )

        XCTAssertEqual(snapshot.versionId, "legacy-version")
        XCTAssertEqual(snapshot.submission?.userConsents, [])
        XCTAssertTrue(snapshot.consentsInSync)
    }

    func testMigratesEmptyReleasedStorageAsPendingDecision() async throws {
        let suite = uniqueSuiteName()
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set("legacy-user", forKey: LegacyConsentStorageKey.userIdKey)
        defaults.set("legacy-version", forKey: LegacyConsentStorageKey.consentsVersionIdKey)
        defaults.set(false, forKey: LegacyConsentStorageKey.consentsInSyncKey)
        let storage = try XCTUnwrap(
            ConsentStore(suiteName: suite, solutionID: "solution", clientID: "client", clientSecret: "secret")
        )
        _ = try storage.readSnapshot()

        let snapshot = try storage.persistenceInspection(
            suiteName: suite,
            clientID: "client"
        )

        XCTAssertEqual(snapshot.versionId, "legacy-version")
        XCTAssertEqual(snapshot.submission?.userConsents, [])
        XCTAssertFalse(snapshot.consentsInSync)
    }

    func testStaleVersionWithoutLegacyUserIDDoesNotCreateProfile() async throws {
        let suite = uniqueSuiteName()
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set("legacy-version", forKey: LegacyConsentStorageKey.consentsVersionIdKey)
        let storage = try XCTUnwrap(
            ConsentStore(suiteName: suite, solutionID: "solution", clientID: "client", clientSecret: "secret")
        )
        _ = try storage.readSnapshot()

        let snapshot = try storage.persistenceInspection(
            suiteName: suite,
            clientID: "client"
        )

        XCTAssertNil(snapshot.userId)
        XCTAssertNil(snapshot.versionId)
        XCTAssertNil(snapshot.submission)
    }

    func testSeparateStorageInstancesKeepDifferentPartitionsInSharedDatabase() async throws {
        let suite = uniqueSuiteName()
        let first = try XCTUnwrap(
            ConsentStore(
                suiteName: suite,
                solutionID: "solution-a",
                clientID: "client-a",
                clientSecret: "secret-a"
            )
        )
        let second = try XCTUnwrap(
            ConsentStore(
                suiteName: suite,
                solutionID: "solution-b",
                clientID: "client-b",
                clientSecret: "secret-b"
            )
        )
        let firstSubmission = submission(
            solutionID: "solution-a",
            version: "version-a",
            values: []
        )
        let secondSubmission = submission(
            solutionID: "solution-b",
            version: "version-b",
            values: []
        )
        async let firstSave: Void = first.savePending(
            submission: firstSubmission
        )
        async let secondSave: Void = second.savePending(
            submission: secondSubmission
        )
        try await firstSave
        try await secondSave

        let firstSnapshot = try first.readSnapshot()
        let secondSnapshot = try second.readSnapshot()
        XCTAssertEqual(firstSnapshot.versionId, "version-a")
        XCTAssertEqual(secondSnapshot.versionId, "version-b")
    }

    func testConcurrentStoresPreserveDifferentVersionsOfSameConfiguration() async throws {
        let (first, second) = try makeSharedStores()
        let barrier = ConsentStoreSaveBarrier(participantCount: 2)
        let firstSubmission = submission(
            version: "first",
            values: [value("first", true)]
        )
        let secondSubmission = submission(
            version: "second",
            values: [value("second", false)]
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask(name: "ConsentStoreTests.saveFirstVersion") {
                await barrier.wait()
                try first.savePending(submission: firstSubmission)
            }
            group.addTask(name: "ConsentStoreTests.saveSecondVersion") {
                await barrier.wait()
                try second.savePending(submission: secondSubmission)
            }
            try await group.waitForAll()
        }

        var claimedVersions = Set<String>()
        while let claim = try first.claimPendingSynchronization() {
            claimedVersions.insert(claim.solutionVersionID)
            XCTAssertTrue(try first.completeSynchronizationClaim(claim))
        }
        XCTAssertEqual(claimedVersions, Set(["first", "second"]))
    }

    func testConcurrentStoresWriteOneCompleteRevisionForSameVersion() async throws {
        let (first, second) = try makeSharedStores()
        let barrier = ConsentStoreSaveBarrier(participantCount: 2)
        let firstSubmission = submission(
            values: [value("first", true)],
            customData: ["writer": "first"]
        )
        let secondSubmission = submission(
            values: [value("second", false)],
            customData: ["writer": "second"]
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask(name: "ConsentStoreTests.saveFirstRevision") {
                await barrier.wait()
                try first.savePending(submission: firstSubmission)
            }
            group.addTask(name: "ConsentStoreTests.saveSecondRevision") {
                await barrier.wait()
                try second.savePending(submission: secondSubmission)
            }
            try await group.waitForAll()
        }

        let snapshot = try first.persistenceInspection(
            suiteName: latestSuiteName,
            clientID: "client"
        )
        XCTAssertTrue(snapshot.submission == firstSubmission || snapshot.submission == secondSubmission)
        let claim = try XCTUnwrap(first.claimPendingSynchronization())
        XCTAssertEqual(claim.submission, snapshot.submission)
        XCTAssertTrue(try first.completeSynchronizationClaim(claim))
        XCTAssertNil(try first.claimPendingSynchronization())
    }

    func testClearRemovesProfileAndNextUserIDIsStable() async throws {
        let storage = try makeStorage()
        let oldID = storage.userId
        try storage.savePending(
            submission: submission(values: [value("value", true)])
        )

        try storage.clearAll()

        let cleared = try storage.persistenceInspection(
            suiteName: latestSuiteName,
            clientID: "client"
        )
        XCTAssertNil(cleared.userId)
        let newID = storage.userId
        XCTAssertNotEqual(newID, oldID)
        let stableID = storage.userId
        XCTAssertEqual(stableID, newID)
    }

    func testSavePendingAfterClearCreatesNewProfileAndDecision() async throws {
        let storage = try makeStorage()
        let oldUserID = storage.userId
        try storage.savePending(
            submission: submission(version: "existing", values: [value("existing", true)])
        )

        try storage.clearAll()

        try storage.savePending(
            submission: submission(
                version: "new",
                values: [value("new", true)]
            )
        )

        let snapshot = try storage.persistenceInspection(
            suiteName: latestSuiteName,
            clientID: "client"
        )
        XCTAssertNotEqual(snapshot.userId, oldUserID)
        XCTAssertEqual(snapshot.versionId, "new")
        XCTAssertEqual(snapshot.values.keys.sorted(), ["new"])
        XCTAssertFalse(snapshot.consentsInSync)
    }

    func testConcurrentSaveAndClearAlwaysProduceCompleteTransactionalState() async throws {
        for iteration in 0..<100 {
            let storage = try makeStorage()
            try storage.savePending(
                submission: submission(
                    version: "existing",
                    values: [value("existing", true)]
                )
            )
            let racedSubmission = submission(
                version: "raced",
                values: [value("raced", false)]
            )

            async let save: Void = storage.savePending(submission: racedSubmission)
            async let clear: Void = storage.clearAll()
            try await save
            try await clear

            let snapshot = try storage.persistenceInspection(
                suiteName: latestSuiteName,
                clientID: "client"
            )
            if snapshot.versionId == nil {
                XCTAssertNil(snapshot.userId, "Iteration \(iteration)")
                XCTAssertTrue(snapshot.values.isEmpty, "Iteration \(iteration)")
                XCTAssertNil(snapshot.submission, "Iteration \(iteration)")
                XCTAssertTrue(snapshot.consentsInSync, "Iteration \(iteration)")
                XCTAssertNil(
                    try storage.claimPendingSynchronization(),
                    "Iteration \(iteration)"
                )
            } else {
                XCTAssertNotNil(snapshot.userId, "Iteration \(iteration)")
                XCTAssertEqual(snapshot.versionId, "raced", "Iteration \(iteration)")
                XCTAssertEqual(snapshot.values.keys.sorted(), ["raced"], "Iteration \(iteration)")
                XCTAssertEqual(snapshot.submission, racedSubmission, "Iteration \(iteration)")
                XCTAssertFalse(snapshot.consentsInSync, "Iteration \(iteration)")
                let claim = try XCTUnwrap(
                    storage.claimPendingSynchronization(),
                    "Iteration \(iteration)"
                )
                XCTAssertEqual(claim.solutionVersionID, "raced", "Iteration \(iteration)")
                XCTAssertEqual(claim.submission, racedSubmission, "Iteration \(iteration)")
                XCTAssertTrue(
                    try storage.completeSynchronizationClaim(claim),
                    "Iteration \(iteration)"
                )
                XCTAssertNil(
                    try storage.claimPendingSynchronization(),
                    "Iteration \(iteration)"
                )
            }
        }
    }

    func testSavePendingReportsPersistenceFailure() async throws {
        let suite = uniqueSuiteName()
        let storage = ConsentStore(
            database: ConsentDatabase(path: "/dev/null/MobileConsentsSDK.sqlite3"),
            domain: .suite(suite),
            partition: ConsentPartitionID(solutionID: "solution", clientID: "client", clientSecret: "secret")
        )
        do {
            try storage.savePending(
                submission: submission(values: [])
            )
            XCTFail("Expected persistence failure")
        } catch let error as ConsentStoreError {
            XCTAssertEqual(error, .persistenceFailed)
        }
    }

    func testSnapshotReportsReadFailureForCorruptedSQLitePath() async throws {
        let suite = uniqueSuiteName()
        let storage = ConsentStore(
            database: ConsentDatabase(path: "/dev/null/MobileConsentsSDK.sqlite3"),
            domain: .suite(suite),
            partition: ConsentPartitionID(solutionID: "solution", clientID: "client", clientSecret: "secret")
        )

        do {
            _ = try storage.readSnapshot()
            XCTFail("Expected read failure")
        } catch let error as ConsentStoreError {
            XCTAssertEqual(error, .readFailed)
        }
    }

    func testSavePendingWithDifferentSolutionReportsMismatchWithoutCreatingDatabase() async throws {
        let suite = uniqueSuiteName()
        let domain = ConsentStorageDomain.suite(suite)
        let databasePath = domain.consentDatabasePath
        let storage = ConsentStore(
            database: ConsentDatabase(path: databasePath),
            domain: domain,
            partition: ConsentPartitionID(solutionID: "solution", clientID: "client", clientSecret: "secret")
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: databasePath))

        do {
            try storage.savePending(
                submission: submission(solutionID: "other-solution", values: [])
            )
            XCTFail("Expected solution mismatch failure")
        } catch let error as ConsentStoreError {
            XCTAssertEqual(error, .solutionMismatch)
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: databasePath))
    }

    func testClearFailurePreservesLegacyKeys() async throws {
        let suite = uniqueSuiteName()
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set("legacy-user", forKey: LegacyConsentStorageKey.userIdKey)
        let storage = ConsentStore(
            database: ConsentDatabase(path: "/dev/null/MobileConsentsSDK.sqlite3"),
            domain: .suite(suite),
            partition: ConsentPartitionID(solutionID: "solution", clientID: "client", clientSecret: "secret")
        )

        XCTAssertThrowsError(try storage.clearAll()) { error in
            XCTAssertEqual(error as? ConsentStoreError, .persistenceFailed)
        }

        XCTAssertEqual(
            defaults.string(forKey: LegacyConsentStorageKey.userIdKey),
            "legacy-user"
        )
    }

    private func makeStorage() throws -> ConsentStore {
        latestSuiteName = uniqueSuiteName()
        return try XCTUnwrap(
            ConsentStore(
                suiteName: latestSuiteName,
                solutionID: "solution",
                clientID: "client",
                clientSecret: "secret"
            )
        )
    }

    private func makeSharedStores() throws -> (ConsentStore, ConsentStore) {
        let suite = uniqueSuiteName()
        latestSuiteName = suite
        let domain = ConsentStorageDomain.suite(suite)
        addDatabaseTeardown(at: domain.consentDatabasePath)
        let first = try XCTUnwrap(
            ConsentStore(
                suiteName: suite,
                solutionID: "solution",
                clientID: "client",
                clientSecret: "secret"
            )
        )
        let second = try XCTUnwrap(
            ConsentStore(
                suiteName: suite,
                solutionID: "solution",
                clientID: "client",
                clientSecret: "secret"
            )
        )
        return (first, second)
    }

    private func uniqueSuiteName() -> String {
        "MobileConsentsSDK.ConsentStoreTests.\(UUID().uuidString)"
    }

    private func addDatabaseTeardown(at path: String) {
        addTeardownBlock {
            try? FileManager.default.removeItem(atPath: path)
            try? FileManager.default.removeItem(atPath: path + "-shm")
            try? FileManager.default.removeItem(atPath: path + "-wal")
        }
    }

    private func execute(_ sql: String, at url: URL) throws {
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
        guard let database else {
            return
        }
        defer { sqlite3_close(database) }
        var errorMessage: UnsafeMutablePointer<CChar>?
        XCTAssertEqual(sqlite3_exec(database, sql, nil, nil, &errorMessage), SQLITE_OK)
        if let errorMessage {
            defer { sqlite3_free(errorMessage) }
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: String(cString: errorMessage)])
        }
    }

    private func assertNoLegacy(
        in defaults: UserDefaults,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        [
            LegacyConsentStorageKey.userIdKey,
            LegacyConsentStorageKey.consentsKey,
            LegacyConsentStorageKey.consentsVersionIdKey,
            LegacyConsentStorageKey.consentsInSyncKey,
        ].forEach {
            XCTAssertNil(defaults.object(forKey: $0), file: file, line: line)
        }
    }

    private func submission(
        solutionID: String = "solution",
        version: String = "version",
        values: [UserConsentValue],
        purposes: [ProcessingPurpose] = [],
        customData: [String: String]? = nil
    ) -> ConsentSubmissionValue {
        ConsentSubmissionValue(
            consentSolutionId: solutionID,
            consentSolutionVersionId: version,
            processingPurposes: purposes,
            customData: customData,
            userConsents: values
        )
    }

    private func encodeLegacy(_ values: [UserConsentValue]) throws -> [String: Data] {
        var encodedValues = [String: Data]()
        for value in values {
            encodedValues[value.consentItem.id] = try JSONEncoder().encode(value)
        }
        return encodedValues
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

private actor ConsentStoreSaveBarrier {
    private let participantCount: Int
    private var arrivedCount = 0
    private var waiters = [CheckedContinuation<Void, Never>]()

    init(participantCount: Int) {
        self.participantCount = participantCount
    }

    func wait() async {
        arrivedCount += 1
        if arrivedCount == participantCount {
            let waiters = waiters
            self.waiters.removeAll()
            waiters.forEach { $0.resume() }
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }
}