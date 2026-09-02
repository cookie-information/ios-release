import Foundation
import SQLite3
import XCTest
@testable import MobileConsentsSDK

final class ConsentDatabaseTests: XCTestCase {
    private struct StoredDecisionChoice: Equatable {
        let universalID: String
        let accepted: Bool
    }

    private struct StoredLegacyResolution: Equatable {
        let kind: String
        let solutionID: String?
        let clientID: String?
        let configurationDigest: Data?
    }

    func testInitializeBootstrapsEmptyVersionZeroDatabaseToVersionTwoCoreSchema() throws {
        let url = temporaryDatabaseURL()
        addDatabaseTeardown(for: url)
        try execute("PRAGMA user_version = 0;", at: url)

        try ConsentDatabase(path: url.path).initialize()

        XCTAssertEqual(try queryValue("PRAGMA user_version;", at: url), "2")
        XCTAssertTrue(
            try tableNames(at: url).isSuperset(
                of: [
                    "consent_configuration",
                    "consent_profile",
                    "consent_decision",
                    "consent_decision_choice",
                    "consent_legacy_resolution",
                    "consent_solution_version",
                    "consent_latest_solution",
                    "consent_solution_item",
                    "consent_solution_item_translation",
                ]
            )
        )
        XCTAssertEqual(
            try SQLiteDatabaseIntegrityInspection.inspect(databaseURL: url),
            .valid
        )
    }

    func testIntegrityInspectionDetectsForeignKeyViolation() throws {
        let (_, url) = try makeDatabaseWithURL()
        try execute(
            """
            PRAGMA foreign_keys = OFF;
            INSERT INTO consent_decision_choice (decision_id, position, universal_id, accepted)
            VALUES (1, 0, 'orphaned', 0);
            """,
            at: url
        )

        let inspection = try SQLiteDatabaseIntegrityInspection.inspect(databaseURL: url)
        XCTAssertEqual(inspection.foreignKeyViolations, ["consent_decision_choice"])
        XCTAssertEqual(inspection.integrityCheckMessages, ["ok"])
    }

    func testSecondInitializeLeavesSchemaValid() throws {
        let (database, url) = try makeDatabaseWithURL()

        try database.initialize()

        XCTAssertEqual(try queryValue("PRAGMA user_version;", at: url), "2")
        XCTAssertTrue(try tableNames(at: url).contains("consent_decision"))
    }

    func testInitializationPreparesProductionStatementCatalog() throws {
        try makeDatabase().initialize()
    }

    func testInitializeUsesDeleteJournalMode() throws {
        let url = temporaryDatabaseURL()
        addDatabaseTeardown(for: url)

        try ConsentDatabase(path: url.path).initialize()

        XCTAssertEqual(try queryValue("PRAGMA journal_mode;", at: url), "delete")
    }

    func testInitializeRejectsExistingWalDatabaseWithoutChangingItsMode() throws {
        let url = temporaryDatabaseURL()
        addDatabaseTeardown(for: url)
        var rawDatabase: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &rawDatabase), SQLITE_OK)
        let database = try XCTUnwrap(rawDatabase)
        XCTAssertEqual(sqlite3_exec(database, "PRAGMA journal_mode = WAL;", nil, nil, nil), SQLITE_OK)
        sqlite3_close(database)

        XCTAssertThrowsError(try ConsentDatabase(path: url.path).initialize()) { error in
            XCTAssertEqual(error as? ConsentDatabaseError, .incompatibleJournalMode("wal"))
        }
        XCTAssertEqual(try queryValue("PRAGMA journal_mode;", at: url), "wal")
    }

    func testInitializePreservesCurrentVersionTwoDecision() throws {
        let database = try makeDatabase()
        let partition = ConsentPartitionID(solutionID: "solution", clientID: "client", clientSecret: "secret")
        _ = try database.store(
            submission: submission(solutionID: "solution", version: "preserved"),
            synchronizationState: .pending,
            partition: partition
        )

        try database.initialize()

        XCTAssertEqual(try database.snapshot(partition: partition).versionId, "preserved")
    }

    func testInitializeRejectsEmptyFutureVersionWithoutChangingIt() throws {
        let url = temporaryDatabaseURL()
        addDatabaseTeardown(for: url)
        try execute("PRAGMA user_version = 7;", at: url)

        let database = ConsentDatabase(path: url.path)

        XCTAssertThrowsError(try database.initialize()) { error in
            XCTAssertEqual(error as? ConsentDatabaseError, .incompatibleSchema(version: 7))
        }
        XCTAssertEqual(try queryValue("PRAGMA user_version;", at: url), "7")
        XCTAssertTrue(try tableNames(at: url).isEmpty)
        XCTAssertFalse(try tableNames(at: url).contains("consent_decision"))
    }

    func testInitializeRejectsEmptyVersionOneDatabaseWithoutChangingIt() throws {
        let url = temporaryDatabaseURL()
        addDatabaseTeardown(for: url)
        try execute("PRAGMA user_version = 1;", at: url)

        let database = ConsentDatabase(path: url.path)

        XCTAssertThrowsError(try database.initialize()) { error in
            XCTAssertEqual(error as? ConsentDatabaseError, .incompatibleSchema(version: 1))
        }
        XCTAssertEqual(try queryValue("PRAGMA user_version;", at: url), "1")
        XCTAssertTrue(try tableNames(at: url).isEmpty)
    }

    func testInitializeRejectsNonEmptyVersionZeroDatabaseWithoutChangingIt() throws {
        let url = temporaryDatabaseURL()
        addDatabaseTeardown(for: url)
        try execute(
            "CREATE TABLE sentinel (value TEXT NOT NULL); INSERT INTO sentinel VALUES ('preserved'); PRAGMA user_version = 0;",
            at: url
        )

        XCTAssertThrowsError(try ConsentDatabase(path: url.path).initialize()) { error in
            XCTAssertEqual(error as? ConsentDatabaseError, .incompatibleSchema(version: 0))
        }
        XCTAssertEqual(try queryValue("PRAGMA user_version;", at: url), "0")
        XCTAssertEqual(try tableNames(at: url), ["sentinel"])
        XCTAssertEqual(
            try tableDefinition(named: "sentinel", at: url),
            "CREATE TABLE sentinel (value TEXT NOT NULL)"
        )
        XCTAssertEqual(try queryValue("SELECT value FROM sentinel;", at: url), "preserved")
    }

    func testInitializeLeavesUnknownVersionTwoDecisionSchemaUnchangedAndThrowsIncompatibleSchema() throws {
        let url = temporaryDatabaseURL()
        addDatabaseTeardown(for: url)
        try execute(
            "CREATE TABLE consent_decision (profile_id TEXT NOT NULL); INSERT INTO consent_decision VALUES ('sentinel'); PRAGMA user_version = 2;",
            at: url
        )

        let database = ConsentDatabase(path: url.path)

        XCTAssertThrowsError(try database.initialize()) { error in
            XCTAssertEqual(error as? ConsentDatabaseError, .incompatibleSchema(version: 2))
        }
        XCTAssertEqual(try queryValue("PRAGMA user_version;", at: url), "2")
        XCTAssertEqual(
            try tableDefinition(named: "consent_decision", at: url),
            "CREATE TABLE consent_decision (profile_id TEXT NOT NULL)"
        )
        XCTAssertEqual(try queryValue("SELECT profile_id FROM consent_decision;", at: url), "sentinel")
    }

    func testInitializeRejectsVersionTwoSchemaWithRequiredIndexMissing() throws {
        let url = temporaryDatabaseURL()
        addDatabaseTeardown(for: url)
        let database = ConsentDatabase(path: url.path)
        try database.initialize()
        try execute("DROP INDEX consent_decision_latest;", at: url)

        XCTAssertThrowsError(try database.initialize()) { error in
            XCTAssertEqual(error as? ConsentDatabaseError, .incompatibleSchema(version: 2))
        }
    }

    func testDecisionSchemaUsesDigestWithoutPlaintextSecretColumn() throws {
        let (_, url) = try makeDatabaseWithURL()
        let definition = try XCTUnwrap(
            tableDefinition(named: "consent_configuration", at: url)
        )

        XCTAssertTrue(definition.contains("configuration_digest BLOB NOT NULL CHECK (length(configuration_digest) = 32)"))
        XCTAssertFalse(definition.lowercased().contains("secret"))
    }

    func testConcurrentInitializationSucceedsForSharedAndDistinctPaths() async throws {
        let sharedURL = temporaryDatabaseURL()
        let distinctURLs = (0..<32).map { _ in temporaryDatabaseURL() }
        addTeardownBlock {
            for url in [sharedURL] + distinctURLs {
                try? FileManager.default.removeItem(at: url)
                try? FileManager.default.removeItem(atPath: url.path + "-shm")
                try? FileManager.default.removeItem(atPath: url.path + "-wal")
            }
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<32 {
                group.addTask {
                    try ConsentDatabase(path: sharedURL.path).initialize()
                }
            }
            for url in distinctURLs {
                group.addTask {
                    try ConsentDatabase(path: url.path).initialize()
                }
            }
            try await group.waitForAll()
        }

        XCTAssertEqual(try queryValue("PRAGMA user_version;", at: sharedURL), "2")
        for url in distinctURLs {
            XCTAssertEqual(try queryValue("PRAGMA user_version;", at: url), "2")
        }
    }

    func testRepeatedSimultaneousFirstInitializationHasNoFailures() async {
        let urls = (0..<32).map { _ in temporaryDatabaseURL() }
        addTeardownBlock {
            for url in urls {
                try? FileManager.default.removeItem(at: url)
            }
        }
        let startedAt = Date()
        var failureCount = 0

        await withTaskGroup(of: Bool.self) { group in
            for url in urls {
                for _ in 0..<16 {
                    group.addTask(name: "MobileConsentsSDKTests.initializeDatabase") {
                        do {
                            try ConsentDatabase(path: url.path).initialize()
                            return true
                        } catch {
                            return false
                        }
                    }
                }
            }
            for await succeeded in group where !succeeded {
                failureCount += 1
            }
        }

        XCTAssertEqual(failureCount, 0)
        XCTAssertGreaterThan(Date().timeIntervalSince(startedAt), 0)
    }

    func testConnectionWaitsForBusyTimeoutAndSucceedsAfterContentionEnds() throws {
        let url = temporaryDatabaseURL()
        addDatabaseTeardown(for: url)
        let database = ConsentDatabase(path: url.path)
        try database.initialize()
        var rawHolder: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &rawHolder), SQLITE_OK)
        let holder = try XCTUnwrap(rawHolder)
        defer { sqlite3_close(holder) }
        XCTAssertEqual(sqlite3_exec(holder, "BEGIN IMMEDIATE;", nil, nil, nil), SQLITE_OK)
        let startedAt = ProcessInfo.processInfo.systemUptime

        XCTAssertThrowsError(try database.userID()) { error in
            guard case let ConsentDatabaseError.statementFailed(code, _) = error else {
                return XCTFail("Expected SQLite statement failure, got \(error)")
            }
            XCTAssertEqual(code, SQLITE_BUSY)
        }
        XCTAssertGreaterThanOrEqual(
            ProcessInfo.processInfo.systemUptime - startedAt,
            4.5
        )

        XCTAssertEqual(sqlite3_exec(holder, "COMMIT;", nil, nil, nil), SQLITE_OK)

        XCTAssertFalse(try database.userID().isEmpty)
    }

    func testConcurrentConnectionsClaimPendingRevisionOnce() async throws {
        let (database, url) = try makeDatabaseWithURL()
        let partition = ConsentPartitionID(
            solutionID: "solution",
            clientID: "client",
            clientSecret: "secret"
        )
        let expectedUserID = try database.userID()
        let expectedSubmission = submission(solutionID: "solution", version: "version")
        try database.store(
            submission: expectedSubmission,
            synchronizationState: .pending,
            partition: partition
        )
        let claimedAt = Date(timeIntervalSince1970: 1_000)
        let barrier = ConsentDatabaseClaimBarrier(participantCount: 2)

        let claims = try await withThrowingTaskGroup(
            of: ConsentSynchronizationClaim?.self,
            returning: [ConsentSynchronizationClaim].self
        ) { group in
            for index in 0..<2 {
                group.addTask(
                    name: "ConsentDatabaseTests.concurrentClaim.\(index)"
                ) {
                    await barrier.wait()
                    return try ConsentDatabase(path: url.path).claimPendingSynchronization(
                        partition: partition,
                        at: claimedAt
                    )
                }
            }
            var claims = [ConsentSynchronizationClaim]()
            for try await claim in group {
                if let claim {
                    claims.append(claim)
                }
            }
            return claims
        }

        XCTAssertEqual(claims.count, 1)
        let claim = try XCTUnwrap(claims.first)
        XCTAssertEqual(claim.userID, expectedUserID)
        XCTAssertEqual(claim.solutionVersionID, "version")
        XCTAssertEqual(claim.submission, expectedSubmission)
        XCTAssertEqual(claim.claimedAt, claimedAt)
    }

    func testActiveClaimBlocksOtherVersionsUntilItIsOlderThanSixtySeconds() throws {
        let database = try makeDatabase()
        let partition = ConsentPartitionID(
            solutionID: "solution",
            clientID: "client",
            clientSecret: "secret"
        )
        try database.store(
            submission: submission(solutionID: "solution", version: "first"),
            synchronizationState: .pending,
            partition: partition
        )
        _ = try database.store(
            submission: submission(solutionID: "solution", version: "second"),
            synchronizationState: .pending,
            partition: partition
        )
        let firstClaimedAt = Date(timeIntervalSince1970: 1_000)
        let firstClaim = try XCTUnwrap(
            database.claimPendingSynchronization(
                partition: partition,
                at: firstClaimedAt
            )
        )

        XCTAssertNil(
            try database.claimPendingSynchronization(
                partition: partition,
                at: Date(timeIntervalSince1970: 1_059)
            )
        )
        XCTAssertNil(
            try database.claimPendingSynchronization(
                partition: partition,
                at: Date(timeIntervalSince1970: 1_060)
            )
        )

        let reclaimedAt = Date(timeIntervalSince1970: 1_060.001)
        let reclaimedClaim = try XCTUnwrap(
            database.claimPendingSynchronization(
                partition: partition,
                at: reclaimedAt
            )
        )
        XCTAssertEqual(reclaimedClaim.revisionID, firstClaim.revisionID)
        XCTAssertEqual(reclaimedClaim.claimedAt, reclaimedAt)
    }

    func testActiveClaimDoesNotBlockAnotherConfiguration() throws {
        let database = try makeDatabase()
        let firstPartition = ConsentPartitionID(
            solutionID: "solution",
            clientID: "client",
            clientSecret: "secret-a"
        )
        let secondPartition = ConsentPartitionID(
            solutionID: "solution",
            clientID: "client",
            clientSecret: "secret-b"
        )
        _ = try database.store(
            submission: submission(solutionID: "solution", version: "first"),
            synchronizationState: .pending,
            partition: firstPartition
        )
        _ = try database.store(
            submission: submission(solutionID: "solution", version: "second"),
            synchronizationState: .pending,
            partition: secondPartition
        )
        let claimedAt = Date(timeIntervalSince1970: 1_000)

        let firstClaim = try database.claimPendingSynchronization(
            partition: firstPartition,
            at: claimedAt
        )
        let secondClaim = try database.claimPendingSynchronization(
            partition: secondPartition,
            at: claimedAt
        )

        XCTAssertNotNil(firstClaim)
        XCTAssertNotNil(secondClaim)
    }

    func testStaleClaimCannotCompleteOrReleaseAfterReclaim() throws {
        let database = try makeDatabase()
        let partition = ConsentPartitionID(
            solutionID: "solution",
            clientID: "client",
            clientSecret: "secret"
        )
        _ = try database.store(
            submission: submission(solutionID: "solution", version: "version"),
            synchronizationState: .pending,
            partition: partition
        )
        let staleClaim = try XCTUnwrap(
            database.claimPendingSynchronization(
                partition: partition,
                at: Date(timeIntervalSince1970: 1_000)
            )
        )
        let currentClaim = try XCTUnwrap(
            database.claimPendingSynchronization(
                partition: partition,
                at: Date(timeIntervalSince1970: 1_061)
            )
        )

        XCTAssertFalse(
            try database.isSynchronizationClaimCurrent(
                partition: partition,
                claim: staleClaim
            )
        )
        XCTAssertTrue(
            try database.isSynchronizationClaimCurrent(
                partition: partition,
                claim: currentClaim
            )
        )
        XCTAssertFalse(
            try database.completeSynchronizationClaim(staleClaim, partition: partition)
        )
        XCTAssertFalse(
            try database.releaseSynchronizationClaim(staleClaim, partition: partition)
        )
        XCTAssertTrue(
            try database.completeSynchronizationClaim(currentClaim, partition: partition)
        )
    }

    func testReleasedClaimIsImmediatelyClaimableAgain() throws {
        let database = try makeDatabase()
        let partition = ConsentPartitionID(
            solutionID: "solution",
            clientID: "client",
            clientSecret: "secret"
        )
        try database.store(
            submission: submission(solutionID: "solution", version: "version"),
            synchronizationState: .pending,
            partition: partition
        )
        let claim = try XCTUnwrap(
            database.claimPendingSynchronization(
                partition: partition,
                at: Date(timeIntervalSince1970: 1_000)
            )
        )

        XCTAssertTrue(
            try database.releaseSynchronizationClaim(claim, partition: partition)
        )
        let nextClaim = try XCTUnwrap(
            database.claimPendingSynchronization(
                partition: partition,
                at: Date(timeIntervalSince1970: 1_001)
            )
        )
        XCTAssertEqual(nextClaim.revisionID, claim.revisionID)
    }

    func testSuccessfulClaimSynchronizesOnlyItsVersion() throws {
        let (database, url) = try makeDatabaseWithURL()
        let partition = ConsentPartitionID(
            solutionID: "solution",
            clientID: "client",
            clientSecret: "secret"
        )
        _ = try database.store(
            submission: submission(solutionID: "solution", version: "older"),
            synchronizationState: .pending,
            partition: partition
        )
        _ = try database.store(
            submission: submission(solutionID: "solution", version: "newer"),
            synchronizationState: .pending,
            partition: partition
        )
        let claim = try XCTUnwrap(
            database.claimPendingSynchronization(
                partition: partition,
                at: Date(timeIntervalSince1970: 1_000)
            )
        )

        XCTAssertEqual(claim.solutionVersionID, "older")
        XCTAssertTrue(
            try database.completeSynchronizationClaim(claim, partition: partition)
        )
        XCTAssertEqual(
            try decisionSynchronizationState(
                partition: partition,
                versionID: "older",
                at: url
            ),
            SynchronizationState.synchronized.rawValue
        )
        XCTAssertEqual(
            try decisionSynchronizationState(
                partition: partition,
                versionID: "newer",
                at: url
            ),
            SynchronizationState.pending.rawValue
        )
        let nextClaim = try XCTUnwrap(
            database.claimPendingSynchronization(
                partition: partition,
                at: Date(timeIntervalSince1970: 1_001)
            )
        )
        XCTAssertEqual(nextClaim.solutionVersionID, "newer")
    }

    func testReplacingClaimedVersionMakesOldClaimStale() throws {
        let database = try makeDatabase()
        let partition = ConsentPartitionID(
            solutionID: "solution",
            clientID: "client",
            clientSecret: "secret"
        )
        let originalSubmission = submission(solutionID: "solution", version: "version")
        _ = try database.store(
            submission: originalSubmission,
            synchronizationState: .pending,
            partition: partition
        )
        let staleClaim = try XCTUnwrap(
            database.claimPendingSynchronization(
                partition: partition,
                at: Date(timeIntervalSince1970: 1_000)
            )
        )
        let replacementSubmission = submission(
            solutionID: "solution",
            version: "version",
            choices: [("replacement", true)]
        )
        try database.store(
            submission: replacementSubmission,
            synchronizationState: .pending,
            partition: partition
        )

        XCTAssertFalse(
            try database.isSynchronizationClaimCurrent(
                partition: partition,
                claim: staleClaim
            )
        )
        XCTAssertTrue(
            try database.completeSynchronizationClaim(staleClaim, partition: partition)
        )
        let replacementClaim = try XCTUnwrap(
            database.claimPendingSynchronization(
                partition: partition,
                at: Date(timeIntervalSince1970: 1_001)
            )
        )
        XCTAssertNotEqual(replacementClaim.revisionID, staleClaim.revisionID)
        XCTAssertEqual(replacementClaim.submission, replacementSubmission)
    }

    func testReplacingActiveOlderVersionMakesReplacementLatestSavedDecision() throws {
        let database = try makeDatabase()
        let partition = ConsentPartitionID(
            solutionID: "solution",
            clientID: "client",
            clientSecret: "secret"
        )
        _ = try database.store(
            submission: submission(solutionID: "solution", version: "A"),
            synchronizationState: .pending,
            partition: partition
        )
        let activeClaim = try XCTUnwrap(
            database.claimPendingSynchronization(
                partition: partition,
                at: Date(timeIntervalSince1970: 1_000)
            )
        )
        _ = try database.store(
            submission: submission(solutionID: "solution", version: "B"),
            synchronizationState: .pending,
            partition: partition
        )
        _ = try database.store(
            submission: submission(
                solutionID: "solution",
                version: "A",
                choices: [("second", false), ("first", true)]
            ),
            synchronizationState: .pending,
            partition: partition
        )

        let latest = try database.snapshot(partition: partition)
        XCTAssertEqual(latest.versionId, "A")
        XCTAssertEqual(Set(latest.values.keys), ["first", "second"])
        XCTAssertEqual(latest.values["second"]?.isSelected, false)
        XCTAssertTrue(
            try database.completeSynchronizationClaim(
                activeClaim,
                partition: partition
            )
        )
        let nextClaim = try XCTUnwrap(
            database.claimPendingSynchronization(
                partition: partition,
                at: Date(timeIntervalSince1970: 1_001)
            )
        )
        XCTAssertEqual(nextClaim.solutionVersionID, "B")
    }

    func testDecisionsKeepVersionsIndependentAndLatestSaveWinsSnapshot() throws {
        let (database, url) = try makeDatabaseWithURL()
        let firstPartition = ConsentPartitionID(solutionID: "solution-a", clientID: "client-a", clientSecret: "secret-a")
        let secondPartition = ConsentPartitionID(solutionID: "solution-b", clientID: "client-b", clientSecret: "secret-b")
        try database.store(
            submission: submission(solutionID: "solution-a", version: "old"),
            synchronizationState: .pending,
            partition: firstPartition
        )
        _ = try database.store(
            submission: submission(solutionID: "solution-a", version: "latest"),
            synchronizationState: .pending,
            partition: firstPartition
        )
        _ = try database.store(
            submission: submission(solutionID: "solution-b", version: "independent"),
            synchronizationState: .pending,
            partition: secondPartition
        )

        let claim = try XCTUnwrap(
            database.claimPendingSynchronization(
                partition: firstPartition,
                at: Date(timeIntervalSince1970: 1_000)
            )
        )
        XCTAssertEqual(claim.solutionVersionID, "old")
        XCTAssertTrue(
            try database.completeSynchronizationClaim(
                claim,
                partition: firstPartition
            )
        )

        XCTAssertEqual(try database.snapshot(partition: firstPartition).versionId, "latest")
        XCTAssertFalse(
            try ConsentPersistenceInspection.read(
                databaseURL: url,
                partition: firstPartition
            ).consentsInSync
        )
        XCTAssertEqual(
            try decisionSynchronizationState(
                partition: firstPartition,
                versionID: "old",
                at: url
            ),
            SynchronizationState.synchronized.rawValue
        )
        XCTAssertEqual(try database.snapshot(partition: secondPartition).versionId, "independent")
        XCTAssertTrue(
            try database.isSynchronizationClaimCurrent(
                partition: firstPartition,
                claim: try XCTUnwrap(
                    database.claimPendingSynchronization(
                        partition: firstPartition,
                        at: Date(timeIntervalSince1970: 1_001)
                    )
                )
            )
        )
    }

    func testDecisionStoresChoicesRelationallyAndReplacesOnlyTheSameVersion() throws {
        let (database, url) = try makeDatabaseWithURL()
        let partition = ConsentPartitionID(solutionID: "solution", clientID: "client", clientSecret: "secret")
        _ = try database.store(
            submission: submission(solutionID: "solution", version: "version-a", choices: [("analytics", true)]),
            synchronizationState: .synchronized,
            partition: partition
        )
        _ = try database.store(
            submission: submission(solutionID: "solution", version: "version-b", choices: [("marketing", true)]),
            synchronizationState: .pending,
            partition: partition
        )
        _ = try database.store(
            submission: submission(
                solutionID: "solution",
                version: "version-a",
                choices: [("analytics", false), ("custom", true)]
            ),
            synchronizationState: .pending,
            partition: partition
        )

        XCTAssertEqual(
            try decisionChoices(partition: partition, versionID: "version-a", at: url),
            [
                StoredDecisionChoice(universalID: "analytics", accepted: false),
                StoredDecisionChoice(universalID: "custom", accepted: true),
            ]
        )
        XCTAssertEqual(
            try decisionChoices(partition: partition, versionID: "version-b", at: url),
            [StoredDecisionChoice(universalID: "marketing", accepted: true)]
        )
        XCTAssertEqual(
            try decisionSynchronizationState(partition: partition, versionID: "version-a", at: url),
            SynchronizationState.pending.rawValue
        )
        XCTAssertEqual(
            try decisionSynchronizationState(partition: partition, versionID: "version-b", at: url),
            SynchronizationState.pending.rawValue
        )
    }

    func testCachesAllSolutionVersionsIdempotentlyAndReconstructsLatestWithRequestedLanguage() throws {
        let (database, url) = try makeDatabaseWithURL()
        let partition = ConsentPartitionID(solutionID: "solution", clientID: "client", clientSecret: "secret")
        let fixture = try fixtureSolution(primaryLanguage: "EN")
        let first = ConsentSolutionValue(
            id: "returned-solution",
            versionId: "version-a",
            templateTexts: fixture.templateTexts,
            consentItems: fixture.consentItems
        )
        let second = ConsentSolutionValue(
            id: "returned-solution",
            versionId: "version-b",
            templateTexts: fixture.templateTexts,
            consentItems: (0..<5).map { index in
                ConsentItem(
                    id: "custom-\(index)",
                    required: false,
                    type: .custom,
                    translations: Translated(
                        translations: [
                            ConsentTranslation(language: "EN", shortText: "EN \(index)", longText: "EN details \(index)"),
                            ConsentTranslation(language: "PL", shortText: "PL \(index)", longText: "PL details \(index)"),
                        ],
                        primaryLanguage: "EN"
                    )
                )
            }
        )

        try database.cacheConsentSolution(first, partition: partition)
        try database.cacheConsentSolution(second, partition: partition)
        try database.cacheConsentSolution(second, partition: partition)

        XCTAssertEqual(
            try cachedSolutionVersionIDs(partition: partition, at: url),
            ["version-a", "version-b"]
        )
        let loaded = try XCTUnwrap(
            database.latestConsentSolution(partition: partition, primaryLanguage: "PL")
        )
        XCTAssertEqual(loaded.id, "returned-solution")
        XCTAssertEqual(loaded.versionId, "version-b")
        XCTAssertEqual(loaded.consentItems.map(\.type), Array(repeating: .custom, count: 5))
        XCTAssertEqual(loaded.consentItems.map(\.translations.primaryLanguage), Array(repeating: "PL", count: 5))
        XCTAssertEqual(loaded.consentItems[3].translations.primaryTranslation().shortText, "PL 3")
        XCTAssertEqual(loaded.templateTexts.readMoreButton.primaryLanguage, "PL")
    }

    func testIntegrityCheckPassesForCachedSolutionTranslationsAndDecisionChoices() throws {
        let (database, url) = try makeDatabaseWithURL()
        let partition = ConsentPartitionID(
            solutionID: "solution",
            clientID: "client",
            clientSecret: "secret"
        )
        let fixture = try fixtureSolution(primaryLanguage: "EN")
        try database.cacheConsentSolution(fixture, partition: partition)
        try database.store(
            submission: submission(
                solutionID: fixture.id,
                version: fixture.versionId,
                choices: [("analytics", true), ("marketing", false)]
            ),
            synchronizationState: .pending,
            partition: partition
        )

        XCTAssertEqual(
            try SQLiteDatabaseIntegrityInspection.inspect(databaseURL: url),
            .valid
        )
    }

    func testProfileClearRemovesDecisionsAcrossConfigurationsAndPreservesSolutionCaches() throws {
        let (database, url) = try makeDatabaseWithURL()
        let firstPartition = ConsentPartitionID(solutionID: "solution", clientID: "client", clientSecret: "secret-a")
        let secondPartition = ConsentPartitionID(solutionID: "solution", clientID: "client", clientSecret: "secret-b")
        let fixture = try fixtureSolution(primaryLanguage: "EN")
        let first = ConsentSolutionValue(
            id: fixture.id,
            versionId: "first",
            templateTexts: fixture.templateTexts,
            consentItems: fixture.consentItems
        )
        let second = ConsentSolutionValue(
            id: fixture.id,
            versionId: "second",
            templateTexts: fixture.templateTexts,
            consentItems: fixture.consentItems
        )
        try database.cacheConsentSolution(first, partition: firstPartition)
        try database.cacheConsentSolution(second, partition: secondPartition)
        _ = try database.store(
            submission: submission(solutionID: "solution", version: "first"),
            synchronizationState: .pending,
            partition: firstPartition
        )
        _ = try database.store(
            submission: submission(solutionID: "solution", version: "second"),
            synchronizationState: .pending,
            partition: secondPartition
        )

        try database.clearProfile()

        XCTAssertNil(
            try ConsentPersistenceInspection.read(
                databaseURL: url,
                partition: firstPartition
            ).userId
        )
        XCTAssertNil(
            try ConsentPersistenceInspection.read(
                databaseURL: url,
                partition: secondPartition
            ).userId
        )
        XCTAssertEqual(
            try database.latestConsentSolution(partition: firstPartition, primaryLanguage: "EN")?.versionId,
            "first"
        )
        XCTAssertEqual(
            try database.latestConsentSolution(partition: secondPartition, primaryLanguage: "EN")?.versionId,
            "second"
        )
        XCTAssertEqual(
            try SQLiteDatabaseIntegrityInspection.inspect(databaseURL: url),
            .valid
        )
    }

    func testDecisionWriteRollsBackJSONAndChoicesWhenChoiceInsertFails() throws {
        let url = temporaryDatabaseURL()
        addDatabaseTeardown(for: url)
        let database = ConsentDatabase(path: url.path)
        try database.initialize()
        let partition = ConsentPartitionID(solutionID: "solution", clientID: "client", clientSecret: "secret")
        let original = submission(
            solutionID: "solution",
            version: "version",
            choices: [("analytics", true)]
        )
        _ = try database.store(
            submission: original,
            synchronizationState: .synchronized,
            partition: partition
        )
        try execute(
            """
            CREATE TRIGGER reject_failing_choice
            BEFORE INSERT ON consent_decision_choice
            WHEN NEW.universal_id = 'fail'
            BEGIN
                SELECT RAISE(ABORT, 'rejected choice');
            END;
            """,
            at: url
        )

        XCTAssertThrowsError(
            try database.store(
                submission: submission(
                    solutionID: "solution",
                    version: "version",
                    choices: [("fail", false)]
                ),
                synchronizationState: .pending,
                partition: partition
            )
        )

        let inspection = try ConsentPersistenceInspection.read(
            databaseURL: url,
            partition: partition
        )
        XCTAssertEqual(inspection.submission, original)
        XCTAssertEqual(
            try decisionChoices(partition: partition, versionID: "version", at: url),
            [StoredDecisionChoice(universalID: "analytics", accepted: true)]
        )
        XCTAssertTrue(inspection.consentsInSync)
        XCTAssertEqual(
            try SQLiteDatabaseIntegrityInspection.inspect(databaseURL: url),
            .valid
        )
    }

    func testLegacyImportWritesDecisionAndMarkerAndBlocksSecondPartition() throws {
        let (database, url) = try makeDatabaseWithURL()
        let partition = ConsentPartitionID(solutionID: "legacy-solution", clientID: "client", clientSecret: "secret")
        try database.importLegacyIfNeeded(
            userID: "legacy-user",
            submission: submission(solutionID: "legacy-solution", version: "legacy"),
            synchronizationState: .pending,
            partition: partition
        )
        let resolution = try legacyResolution(at: url)
        XCTAssertEqual(
            resolution,
            StoredLegacyResolution(
                kind: "imported",
                solutionID: "legacy-solution",
                clientID: "client",
                configurationDigest: partition.fingerprint.digest
            )
        )
        XCTAssertEqual(try legacyResolution(at: url), resolution)

        let secondPartition = ConsentPartitionID(solutionID: "other", clientID: "partition", clientSecret: "secret")
        try database.importLegacyIfNeeded(
            userID: "other-user",
            submission: submission(solutionID: "other", version: "other"),
            synchronizationState: .synchronized,
            partition: secondPartition
        )

        let snapshot = try ConsentPersistenceInspection.read(
            databaseURL: url,
            partition: partition
        )
        XCTAssertEqual(snapshot.userId, "legacy-user")
        XCTAssertEqual(snapshot.versionId, "legacy")
        XCTAssertFalse(snapshot.consentsInSync)
        XCTAssertEqual(try legacyResolution(at: url), resolution)
        XCTAssertNil(try database.snapshot(partition: secondPartition).versionId)
    }

    func testClearTombstoneRejectsStaleLegacyImportAndSurvivesNewInstance() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MobileConsentsSDK.\(UUID().uuidString).sqlite3")
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(atPath: url.path + "-shm")
            try? FileManager.default.removeItem(atPath: url.path + "-wal")
        }
        let database = ConsentDatabase(path: url.path)
        try database.initialize()
        let partition = ConsentPartitionID(solutionID: "solution", clientID: "client", clientSecret: "secret")

        try database.clearProfile()
        let reopened = ConsentDatabase(path: url.path)
        try reopened.initialize()
        try reopened.importLegacyIfNeeded(
            userID: "stale-user",
            submission: submission(solutionID: "solution", version: "stale"),
            synchronizationState: .pending,
            partition: partition
        )

        XCTAssertEqual(try legacyResolution(at: url)?.kind, "cleared")
        XCTAssertNil(
            try ConsentPersistenceInspection.read(
                databaseURL: url,
                partition: partition
            ).userId
        )
    }

    func testSameSolutionAndClientWithDifferentSecretsHaveIndependentDecisions() throws {
        let database = try makeDatabase()
        let first = ConsentPartitionID(solutionID: "solution", clientID: "client", clientSecret: "secret-a")
        let second = ConsentPartitionID(solutionID: "solution", clientID: "client", clientSecret: "secret-b")

        _ = try database.store(submission: submission(solutionID: "solution", version: "first"), synchronizationState: .pending, partition: first)
        _ = try database.store(submission: submission(solutionID: "solution", version: "second"), synchronizationState: .pending, partition: second)

        XCTAssertEqual(try database.snapshot(partition: first).versionId, "first")
        XCTAssertEqual(try database.snapshot(partition: second).versionId, "second")
    }

    func testEveryConfigurationIdentityComponentPartitionsCachesAndClaims() throws {
        let database = try makeDatabase()
        let fixture = try fixtureSolution(primaryLanguage: "EN")
        let configurations = [
            ConsentPartitionID(solutionID: "solution", clientID: "client", clientSecret: "secret"),
            ConsentPartitionID(solutionID: "solution-a", clientID: "client", clientSecret: "secret"),
            ConsentPartitionID(solutionID: "solution", clientID: "client-a", clientSecret: "secret"),
            ConsentPartitionID(solutionID: "solution", clientID: "client", clientSecret: "secret-a"),
        ]

        for (index, partition) in configurations.enumerated() {
            let version = "version-\(index)"
            try database.cacheConsentSolution(
                ConsentSolutionValue(
                    id: partition.solutionID,
                    versionId: version,
                    templateTexts: fixture.templateTexts,
                    consentItems: fixture.consentItems
                ),
                partition: partition
            )
            try database.store(
                submission: submission(solutionID: partition.solutionID, version: version),
                synchronizationState: .pending,
                partition: partition
            )
        }

        for (index, partition) in configurations.enumerated() {
            let version = "version-\(index)"
            XCTAssertEqual(try database.snapshot(partition: partition).versionId, version)
            XCTAssertEqual(
                try database.latestConsentSolution(
                    partition: partition,
                    primaryLanguage: "EN"
                )?.versionId,
                version
            )
            XCTAssertEqual(
                try database.claimPendingSynchronization(
                    partition: partition,
                    at: Date(timeIntervalSince1970: 1_000)
                )?.solutionVersionID,
                version
            )
        }
    }

    func testFingerprintHasFixedLengthAndLengthPrefixAvoidsAmbiguousTuples() {
        let first = ConfigurationFingerprint(solutionID: "ab", clientID: "c", clientSecret: "d")
        let second = ConfigurationFingerprint(solutionID: "a", clientID: "bc", clientSecret: "d")

        XCTAssertEqual(first.digest.count, 32)
        XCTAssertNotEqual(first, second)
    }

    func testSameTripleHasSamePartitionRegardlessOfSolutionVersion() {
        let first = ConsentPartitionID(solutionID: "solution", clientID: "client", clientSecret: "secret")
        let second = ConsentPartitionID(solutionID: "solution", clientID: "client", clientSecret: "secret")

        XCTAssertEqual(first, second)
    }

    private func makeDatabase() throws -> ConsentDatabase {
        try makeDatabaseWithURL().database
    }

    private func makeDatabaseWithURL() throws -> (database: ConsentDatabase, url: URL) {
        let url = temporaryDatabaseURL()
        addDatabaseTeardown(for: url)
        let database = ConsentDatabase(path: url.path)
        try database.initialize()
        return (database, url)
    }

    private func addDatabaseTeardown(for url: URL) {
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(atPath: url.path + "-shm")
            try? FileManager.default.removeItem(atPath: url.path + "-wal")
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

    private func cachedSolutionVersionIDs(
        partition: ConsentPartitionID,
        at url: URL
    ) throws -> [String] {
        var versionIDs = [String]()
        try forEachPartitionRow(
            sql: """
            SELECT version.version_id
            FROM consent_solution_version AS version
            JOIN consent_configuration AS configuration
                ON configuration.id = version.configuration_id
            WHERE configuration.solution_id = ?
                AND configuration.client_id = ?
                AND configuration.configuration_digest = ?
            ORDER BY version.id;
            """,
            partition: partition,
            at: url
        ) { statement in
            if let value = sqlite3_column_text(statement, 0) {
                versionIDs.append(String(cString: value))
            }
        }
        return versionIDs
    }

    private func decisionChoices(
        partition: ConsentPartitionID,
        versionID: String,
        at url: URL
    ) throws -> [StoredDecisionChoice] {
        var choices = [StoredDecisionChoice]()
        try forEachPartitionRow(
            sql: """
            SELECT choice.universal_id, choice.accepted
            FROM consent_decision_choice AS choice
            JOIN consent_decision AS decision ON decision.id = choice.decision_id
            JOIN consent_configuration AS configuration
                ON configuration.id = decision.configuration_id
            WHERE configuration.solution_id = ?
                AND configuration.client_id = ?
                AND configuration.configuration_digest = ?
                AND decision.solution_version_id = ?
            ORDER BY choice.position;
            """,
            partition: partition,
            versionID: versionID,
            at: url
        ) { statement in
            if let universalID = sqlite3_column_text(statement, 0) {
                choices.append(
                    StoredDecisionChoice(
                        universalID: String(cString: universalID),
                        accepted: sqlite3_column_int(statement, 1) != 0
                    )
                )
            }
        }
        return choices
    }

    private func decisionSynchronizationState(
        partition: ConsentPartitionID,
        versionID: String,
        at url: URL
    ) throws -> String? {
        var synchronizationState: String?
        try forEachPartitionRow(
            sql: """
            SELECT decision.synchronization_state
            FROM consent_decision AS decision
            JOIN consent_configuration AS configuration
                ON configuration.id = decision.configuration_id
            WHERE configuration.solution_id = ?
                AND configuration.client_id = ?
                AND configuration.configuration_digest = ?
                AND decision.solution_version_id = ?
            LIMIT 1;
            """,
            partition: partition,
            versionID: versionID,
            at: url
        ) { statement in
            if let value = sqlite3_column_text(statement, 0) {
                synchronizationState = String(cString: value)
            }
        }
        return synchronizationState
    }

    private func forEachPartitionRow(
        sql: String,
        partition: ConsentPartitionID,
        versionID: String? = nil,
        at url: URL,
        row: (OpaquePointer) -> Void
    ) throws {
        var rawDatabase: OpaquePointer?
        try requireSQLiteSuccess(sqlite3_open(url.path, &rawDatabase), database: rawDatabase)
        guard let database = rawDatabase else {
            return
        }
        defer { sqlite3_close(database) }

        var rawStatement: OpaquePointer?
        try requireSQLiteSuccess(
            sqlite3_prepare_v2(database, sql, -1, &rawStatement, nil),
            database: database
        )
        guard let statement = rawStatement else {
            return
        }
        defer { sqlite3_finalize(statement) }

        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        try requireSQLiteSuccess(
            sqlite3_bind_text(statement, 1, partition.solutionID, -1, transient),
            database: database
        )
        try requireSQLiteSuccess(
            sqlite3_bind_text(statement, 2, partition.clientID, -1, transient),
            database: database
        )
        try partition.fingerprint.digest.withUnsafeBytes { bytes in
            try requireSQLiteSuccess(
                sqlite3_bind_blob(statement, 3, bytes.baseAddress, Int32(bytes.count), transient),
                database: database
            )
        }
        if let versionID {
            try requireSQLiteSuccess(
                sqlite3_bind_text(statement, 4, versionID, -1, transient),
                database: database
            )
        }

        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            row(statement)
            result = sqlite3_step(statement)
        }
        try requireSQLiteSuccess(result, expected: SQLITE_DONE, database: database)
    }

    private func requireSQLiteSuccess(
        _ result: Int32,
        expected: Int32 = SQLITE_OK,
        database: OpaquePointer?
    ) throws {
        guard result == expected else {
            throw NSError(
                domain: "SQLite",
                code: Int(result),
                userInfo: [
                    NSLocalizedDescriptionKey: database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite error",
                ]
            )
        }
    }

    private func queryValue(_ sql: String, at url: URL) throws -> String? {
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
        guard let database else {
            return nil
        }
        defer { sqlite3_close(database) }
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(database, sql, -1, &statement, nil), SQLITE_OK)
        guard let statement else {
            return nil
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let value = sqlite3_column_text(statement, 0) else {
            return nil
        }
        return String(cString: value)
    }

    private func tableNames(at url: URL) throws -> Set<String> {
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
        guard let database else {
            return []
        }
        defer { sqlite3_close(database) }
        var statement: OpaquePointer?
        XCTAssertEqual(
            sqlite3_prepare_v2(
                database,
                "SELECT name FROM sqlite_master WHERE type = 'table';",
                -1,
                &statement,
                nil
            ),
            SQLITE_OK
        )
        guard let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }
        var names = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            if let name = sqlite3_column_text(statement, 0) {
                names.insert(String(cString: name))
            }
        }
        return names
    }

    private func tableDefinition(named name: String, at url: URL) throws -> String? {
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
        guard let database else {
            return nil
        }
        defer { sqlite3_close(database) }
        var statement: OpaquePointer?
        XCTAssertEqual(
            sqlite3_prepare_v2(
                database,
                "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?;",
                -1,
                &statement,
                nil
            ),
            SQLITE_OK
        )
        guard let statement else {
            return nil
        }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        XCTAssertEqual(sqlite3_bind_text(statement, 1, name, -1, transient), SQLITE_OK)
        guard sqlite3_step(statement) == SQLITE_ROW,
              let definition = sqlite3_column_text(statement, 0) else {
            return nil
        }
        return String(cString: definition)
    }

    private func legacyResolution(at url: URL) throws -> StoredLegacyResolution? {
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
        guard let database else {
            return nil
        }
        defer { sqlite3_close(database) }
        var statement: OpaquePointer?
        XCTAssertEqual(
            sqlite3_prepare_v2(
                database,
                """
                SELECT resolution.kind, configuration.solution_id, configuration.client_id,
                    configuration.configuration_digest
                FROM consent_legacy_resolution AS resolution
                LEFT JOIN consent_configuration AS configuration
                    ON configuration.id = resolution.configuration_id
                WHERE resolution.id = 1;
                """,
                -1,
                &statement,
                nil
            ),
            SQLITE_OK
        )
        guard let statement else {
            return nil
        }
        defer { sqlite3_finalize(statement) }
          guard sqlite3_step(statement) == SQLITE_ROW,
              let rawKind = sqlite3_column_text(statement, 0) else {
            return nil
        }
          let kind = String(cString: rawKind)
        let solutionID = sqlite3_column_text(statement, 1).map(String.init(cString:))
        let clientID = sqlite3_column_text(statement, 2).map(String.init(cString:))
        let configurationDigest: Data?
        if let bytes = sqlite3_column_blob(statement, 3) {
            configurationDigest = Data(
                bytes: bytes,
                count: Int(sqlite3_column_bytes(statement, 3))
            )
        } else {
            configurationDigest = nil
        }
        return StoredLegacyResolution(
            kind: kind,
            solutionID: solutionID,
            clientID: clientID,
            configurationDigest: configurationDigest
        )
    }

    private func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MobileConsentsSDK.\(UUID().uuidString).sqlite3")
    }

    private func submission(
        solutionID: String,
        version: String,
        choices: [(String, Bool)] = []
    ) -> ConsentSubmissionValue {
        ConsentSubmissionValue(
            consentSolutionId: solutionID,
            consentSolutionVersionId: version,
            processingPurposes: [],
            customData: nil,
            userConsents: choices.map { id, accepted in
                UserConsentValue(
                    consentItem: ConsentItem(
                        id: id,
                        required: false,
                        type: .custom,
                        translations: Translated(
                            translations: [ConsentTranslation(language: "EN", shortText: id, longText: id)],
                            primaryLanguage: "EN"
                        )
                    ),
                    isSelected: accepted
                )
            }
        )
    }

    private func fixtureSolution(primaryLanguage: String) throws -> ConsentSolutionValue {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "ConsentSolution", withExtension: "json"))
        let decoder = JSONDecoder()
        decoder.userInfo[primaryLanguageCodingUserInfoKey] = primaryLanguage
        return try decoder.decode(ConsentSolutionValue.self, from: Data(contentsOf: url))
    }
}

private actor ConsentDatabaseClaimBarrier {
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