import Foundation
import SQLite3

struct SQLiteDatabaseIntegrityInspection: Equatable {
    let foreignKeyViolations: [String]
    let integrityCheckMessages: [String]

    static let valid = SQLiteDatabaseIntegrityInspection(
        foreignKeyViolations: [],
        integrityCheckMessages: ["ok"]
    )

    static func inspect(databaseURL: URL) throws -> SQLiteDatabaseIntegrityInspection {
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

        return SQLiteDatabaseIntegrityInspection(
            foreignKeyViolations: try messages(from: "PRAGMA foreign_key_check;", database: database),
            integrityCheckMessages: try messages(from: "PRAGMA integrity_check;", database: database)
        )
    }

    private static func messages(
        from sql: String,
        database: OpaquePointer
    ) throws -> [String] {
        var rawStatement: OpaquePointer?
        try requireSQLiteSuccess(
            sqlite3_prepare_v2(database, sql, -1, &rawStatement, nil),
            database: database
        )
        guard let statement = rawStatement else {
            throw sqliteError(SQLITE_ERROR, database: database)
        }
        defer { sqlite3_finalize(statement) }

        var messages = [String]()
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            messages.append(
                sqlite3_column_text(statement, 0).map(String.init(cString:)) ?? "NULL"
            )
            result = sqlite3_step(statement)
        }
        try requireSQLiteSuccess(result, expected: SQLITE_DONE, database: database)
        return messages
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