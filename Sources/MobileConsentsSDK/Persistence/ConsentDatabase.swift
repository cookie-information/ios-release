import CryptoKit
import Foundation
import SQLite3

struct ConfigurationFingerprint: Equatable, Sendable {
    let digest: Data

    init(solutionID: String, clientID: String, clientSecret: String) {
        var encoded = Data("MobileConsentsSDK.ConfigurationFingerprint.v1\0".utf8)
        for value in [solutionID, clientID, clientSecret] {
            let valueBytes = Data(value.utf8)
            var length = UInt64(valueBytes.count).bigEndian
            withUnsafeBytes(of: &length) { encoded.append(contentsOf: $0) }
            encoded.append(valueBytes)
        }
        digest = Data(SHA256.hash(data: encoded))
    }

}

struct ConsentPartitionID: Equatable, Sendable {
    let solutionID: String
    let clientID: String
    let fingerprint: ConfigurationFingerprint

    init(solutionID: String, clientID: String, clientSecret: String) {
        self.solutionID = solutionID
        self.clientID = clientID
        fingerprint = ConfigurationFingerprint(
            solutionID: solutionID,
            clientID: clientID,
            clientSecret: clientSecret
        )
    }

}

enum ConsentDatabaseError: Error, Equatable, Sendable {
    case openFailed(code: Int32, message: String)
    case statementFailed(code: Int32, message: String)
    case unknownParameter(String)
    case unknownColumn(String)
    case unexpectedNull(column: String)
    case unexpectedType(column: String, expected: String, actual: Int32)
    case incompatibleSchema(version: Int32)
    case incompatibleJournalMode(String)
}

struct ConsentDatabase: Sendable {
    let path: String

    init(path: String) {
        self.path = path
    }

    func userID() throws -> String {
        try withConnection { database in
            return try transaction(on: database) {
                if let existing = try anonymousUserID(on: database) {
                    return existing
                }
                let generated = UUID().uuidString
                let statement = try ConsentDatabaseStatement(
                    database: database,
                    sql: ConsentDatabaseSQL.insertProfile.sql
                )
                try statement.bind(generated, to: ":id")
                try statement.execute()
                return generated
            }
        }
    }

    func ensureConfigurationID(
        for partition: ConsentPartitionID,
        on database: OpaquePointer
    ) throws -> Int64 {
        let insert = try ConsentDatabaseStatement(
            database: database,
            sql: ConsentDatabaseSQL.insertConfiguration.sql
        )
        try insert.bind(partition.solutionID, to: ":solutionID")
        try insert.bind(partition.clientID, to: ":clientID")
        try insert.bind(partition.fingerprint.digest, to: ":configurationDigest")
        try insert.execute()

        let select = try ConsentDatabaseStatement(
            database: database,
            sql: ConsentDatabaseSQL.selectConfigurationID.sql
        )
        try select.bind(partition.solutionID, to: ":solutionID")
        try select.bind(partition.clientID, to: ":clientID")
        try select.bind(partition.fingerprint.digest, to: ":configurationDigest")
        guard try select.step() else {
            throw statementFailure(on: database)
        }
        return try select.int64(named: "id")
    }

    func statementFailure(on database: OpaquePointer) -> ConsentDatabaseError {
        ConsentDatabaseError.statementFailed(
            code: sqlite3_errcode(database),
            message: String(cString: sqlite3_errmsg(database))
        )
    }

    func withConnection<Result>(
        _ operation: (OpaquePointer) throws -> Result
    ) throws -> Result {
        var database: OpaquePointer?
        let result = sqlite3_open_v2(
            path,
            &database,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE,
            nil
        )
        guard result == SQLITE_OK, let database else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open database"
            if let database {
                sqlite3_close(database)
            }
            throw ConsentDatabaseError.openFailed(code: result, message: message)
        }
        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 5_000)
        try execute(ConsentDatabaseSQL.foreignKeys.sql, on: database)
        return try operation(database)
    }

    func transaction<Result>(
        on database: OpaquePointer,
        _ operation: () throws -> Result
    ) throws -> Result {
        try execute(ConsentDatabaseSQL.beginImmediate.sql, on: database)
        do {
            let result = try operation()
            try execute(ConsentDatabaseSQL.commit.sql, on: database)
            return result
        } catch {
            try? execute(ConsentDatabaseSQL.rollback.sql, on: database)
            throw error
        }
    }

    func anonymousUserID(on database: OpaquePointer) throws -> String? {
        let statement = try ConsentDatabaseStatement(
            database: database,
            sql: ConsentDatabaseSQL.selectAnonymousUserID.sql
        )
        guard try statement.step() else {
            return nil
        }
        return statement.string(at: 0)
    }

    func execute(_ statement: String, on database: OpaquePointer) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(database, statement, nil, nil, &errorMessage)
        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(database))
            sqlite3_free(errorMessage)
            throw ConsentDatabaseError.statementFailed(code: result, message: message)
        }
    }

    func singleInt32(from query: String, on database: OpaquePointer) throws -> Int32 {
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(database, query, -1, &statement, nil)
        guard result == SQLITE_OK, let statement else {
            throw ConsentDatabaseError.statementFailed(
                code: result,
                message: String(cString: sqlite3_errmsg(database))
            )
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw ConsentDatabaseError.statementFailed(
                code: sqlite3_errcode(database),
                message: String(cString: sqlite3_errmsg(database))
            )
        }
        return sqlite3_column_int(statement, 0)
    }

    func singleString(from query: String, on database: OpaquePointer) throws -> String {
        let statement = try ConsentDatabaseStatement(database: database, sql: query)
        guard try statement.step() else {
            throw statementFailure(on: database)
        }
        return statement.string(at: 0)
    }
}
