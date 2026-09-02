import Foundation
import SQLite3
@testable import MobileConsentsSDK

struct ConsentPersistenceInspection: Equatable {
    let userId: String?
    let versionId: String?
    let submission: ConsentSubmissionValue?
    let synchronizationState: String?

    var values: [String: UserConsentValue] {
        submission?.userConsentsByID ?? [:]
    }

    var consentsInSync: Bool {
        synchronizationState == nil
            || synchronizationState == SynchronizationState.synchronized.rawValue
    }
}

extension ConsentStore {
    func persistenceInspection(
        suiteName: String,
        solutionID: String = "solution",
        clientID: String = "id",
        clientSecret: String = "secret"
    ) throws -> ConsentPersistenceInspection {
        let domain = ConsentStorageDomain.suite(suiteName)
        guard FileManager.default.fileExists(atPath: domain.consentDatabasePath) else {
            return ConsentPersistenceInspection(
                userId: nil,
                versionId: nil,
                submission: nil,
                synchronizationState: nil
            )
        }
        return try ConsentPersistenceInspection.read(
            databaseURL: URL(fileURLWithPath: domain.consentDatabasePath),
            partition: ConsentPartitionID(
                solutionID: solutionID,
                clientID: clientID,
                clientSecret: clientSecret
            )
        )
    }

    func hasPendingPersistence(
        suiteName: String,
        solutionID: String = "solution",
        clientID: String = "id",
        clientSecret: String = "secret"
    ) throws -> Bool {
        let domain = ConsentStorageDomain.suite(suiteName)
        guard FileManager.default.fileExists(atPath: domain.consentDatabasePath) else {
            return false
        }
        return try ConsentPersistenceInspection.hasPendingSynchronization(
            databaseURL: URL(fileURLWithPath: domain.consentDatabasePath),
            partition: ConsentPartitionID(
                solutionID: solutionID,
                clientID: clientID,
                clientSecret: clientSecret
            )
        )
    }
}

extension ConsentPersistenceInspection {
    static func hasPendingSynchronization(
        databaseURL: URL,
        partition: ConsentPartitionID
    ) throws -> Bool {
        var rawDatabase: OpaquePointer?
        try requireSQLiteSuccess(
            sqlite3_open_v2(databaseURL.path, &rawDatabase, SQLITE_OPEN_READONLY, nil),
            database: rawDatabase
        )
        guard let database = rawDatabase else {
            throw sqliteError(SQLITE_CANTOPEN, database: nil)
        }
        defer { sqlite3_close(database) }
        try requireSQLiteSuccess(sqlite3_busy_timeout(database, 5_000), database: database)

        var rawStatement: OpaquePointer?
        try requireSQLiteSuccess(
            sqlite3_prepare_v2(
                database,
                """
                SELECT 1
                FROM consent_decision AS decision
                JOIN consent_configuration AS configuration
                    ON configuration.id = decision.configuration_id
                WHERE configuration.solution_id = ?
                    AND configuration.client_id = ?
                    AND configuration.configuration_digest = ?
                    AND decision.synchronization_state IN ('pending', 'in_progress')
                LIMIT 1;
                """,
                -1,
                &rawStatement,
                nil
            ),
            database: database
        )
        guard let statement = rawStatement else {
            throw sqliteError(SQLITE_ERROR, database: database)
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
        let result = sqlite3_step(statement)
        guard result != SQLITE_ROW else {
            return true
        }
        try requireSQLiteSuccess(result, expected: SQLITE_DONE, database: database)
        return false
    }

    static func read(
        databaseURL: URL,
        partition: ConsentPartitionID
    ) throws -> ConsentPersistenceInspection {
        var rawDatabase: OpaquePointer?
        try requireSQLiteSuccess(
            sqlite3_open_v2(databaseURL.path, &rawDatabase, SQLITE_OPEN_READONLY, nil),
            database: rawDatabase
        )
        guard let database = rawDatabase else {
            throw sqliteError(SQLITE_CANTOPEN, database: nil)
        }
        defer { sqlite3_close(database) }
        try requireSQLiteSuccess(sqlite3_busy_timeout(database, 5_000), database: database)

        let userID = try optionalString(
            sql: "SELECT id FROM consent_profile WHERE external_user_id IS NULL LIMIT 1;",
            database: database
        )
        guard let userID else {
            return ConsentPersistenceInspection(
                userId: nil,
                versionId: nil,
                submission: nil,
                synchronizationState: nil
            )
        }

        var rawStatement: OpaquePointer?
        try requireSQLiteSuccess(
            sqlite3_prepare_v2(
                database,
                """
                SELECT decision.solution_version_id, decision.submission,
                    decision.synchronization_state
                FROM consent_decision AS decision
                JOIN consent_configuration AS configuration
                    ON configuration.id = decision.configuration_id
                WHERE decision.profile_id = ?
                    AND configuration.solution_id = ?
                    AND configuration.client_id = ?
                    AND configuration.configuration_digest = ?
                ORDER BY decision.id DESC
                LIMIT 1;
                """,
                -1,
                &rawStatement,
                nil
            ),
            database: database
        )
        guard let statement = rawStatement else {
            throw sqliteError(SQLITE_ERROR, database: database)
        }
        defer { sqlite3_finalize(statement) }

        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        try requireSQLiteSuccess(
            sqlite3_bind_text(statement, 1, userID, -1, transient),
            database: database
        )
        try requireSQLiteSuccess(
            sqlite3_bind_text(statement, 2, partition.solutionID, -1, transient),
            database: database
        )
        try requireSQLiteSuccess(
            sqlite3_bind_text(statement, 3, partition.clientID, -1, transient),
            database: database
        )
        try partition.fingerprint.digest.withUnsafeBytes { bytes in
            try requireSQLiteSuccess(
                sqlite3_bind_blob(statement, 4, bytes.baseAddress, Int32(bytes.count), transient),
                database: database
            )
        }

        let result = sqlite3_step(statement)
        guard result == SQLITE_ROW else {
            try requireSQLiteSuccess(result, expected: SQLITE_DONE, database: database)
            return ConsentPersistenceInspection(
                userId: userID,
                versionId: nil,
                submission: nil,
                synchronizationState: nil
            )
        }
        let submission = try JSONDecoder().decode(
            ConsentSubmissionValue.self,
            from: Data(
                bytes: sqlite3_column_blob(statement, 1),
                count: Int(sqlite3_column_bytes(statement, 1))
            )
        )
        return ConsentPersistenceInspection(
            userId: userID,
            versionId: String(cString: sqlite3_column_text(statement, 0)),
            submission: submission,
            synchronizationState: String(cString: sqlite3_column_text(statement, 2))
        )
    }

    private static func optionalString(
        sql: String,
        database: OpaquePointer
    ) throws -> String? {
        var rawStatement: OpaquePointer?
        try requireSQLiteSuccess(
            sqlite3_prepare_v2(database, sql, -1, &rawStatement, nil),
            database: database
        )
        guard let statement = rawStatement else {
            throw sqliteError(SQLITE_ERROR, database: database)
        }
        defer { sqlite3_finalize(statement) }
        let result = sqlite3_step(statement)
        guard result == SQLITE_ROW else {
            try requireSQLiteSuccess(result, expected: SQLITE_DONE, database: database)
            return nil
        }
        guard let value = sqlite3_column_text(statement, 0) else {
            return nil
        }
        return String(cString: value)
    }

    private static func requireSQLiteSuccess(
        _ result: Int32,
        expected: Int32 = SQLITE_OK,
        database: OpaquePointer?
    ) throws {
        guard result == expected else {
            throw sqliteError(result, database: database)
        }
    }

    private static func sqliteError(
        _ result: Int32,
        database: OpaquePointer?
    ) -> NSError {
        NSError(
            domain: "SQLite",
            code: Int(result),
            userInfo: [
                NSLocalizedDescriptionKey: database.map {
                    String(cString: sqlite3_errmsg($0))
                } ?? "SQLite error",
            ]
        )
    }
}