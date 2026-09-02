import Foundation
import SQLite3
import XCTest
@testable import MobileConsentsSDK

final class ConsentDatabaseStatementTests: XCTestCase {
    func testBindUnknownNamedParameterThrowsUnknownParameter() throws {
        try withDatabase { database in
            let statement = try ConsentDatabaseStatement(
                database: database,
                sql: "SELECT :known;"
            )

            XCTAssertThrowsError(try statement.bind("value", to: ":unknown")) { error in
                XCTAssertEqual(
                    error as? ConsentDatabaseError,
                    .unknownParameter(":unknown")
                )
            }
        }
    }

    func testReadUnknownNamedColumnThrowsUnknownColumn() throws {
        try withDatabase { database in
            let statement = try ConsentDatabaseStatement(
                database: database,
                sql: "SELECT 'value' AS known;"
            )
            XCTAssertTrue(try statement.step())

            XCTAssertThrowsError(try statement.string(named: "unknown")) { error in
                XCTAssertEqual(
                    error as? ConsentDatabaseError,
                    .unknownColumn("unknown")
                )
            }
        }
    }

    func testReadNullNamedColumnThrowsUnexpectedNull() throws {
        try withDatabase { database in
            let statement = try ConsentDatabaseStatement(
                database: database,
                sql: "SELECT NULL AS value;"
            )
            XCTAssertTrue(try statement.step())

            XCTAssertThrowsError(try statement.string(named: "value")) { error in
                XCTAssertEqual(
                    error as? ConsentDatabaseError,
                    .unexpectedNull(column: "value")
                )
            }
        }
    }

    func testStringReaderRejectsIntegerStorageType() throws {
        try withDatabase { database in
            let statement = try preparedRow("SELECT 1 AS value;", on: database)

            XCTAssertThrowsError(try statement.string(named: "value")) { error in
                XCTAssertEqual(
                    error as? ConsentDatabaseError,
                    .unexpectedType(column: "value", expected: "TEXT", actual: SQLITE_INTEGER)
                )
            }
        }
    }

    func testDataReaderRejectsTextStorageType() throws {
        try withDatabase { database in
            let statement = try preparedRow("SELECT 'value' AS value;", on: database)

            XCTAssertThrowsError(try statement.data(named: "value")) { error in
                XCTAssertEqual(
                    error as? ConsentDatabaseError,
                    .unexpectedType(column: "value", expected: "BLOB", actual: SQLITE_TEXT)
                )
            }
        }
    }

    func testDoubleReaderRejectsIntegerStorageType() throws {
        try withDatabase { database in
            let statement = try preparedRow("SELECT 1 AS value;", on: database)

            XCTAssertThrowsError(try statement.double(named: "value")) { error in
                XCTAssertEqual(
                    error as? ConsentDatabaseError,
                    .unexpectedType(column: "value", expected: "FLOAT", actual: SQLITE_INTEGER)
                )
            }
        }
    }

    func testIntegerReadersRejectFloatStorageType() throws {
        try withDatabase { database in
            let int32Statement = try preparedRow("SELECT 1.5 AS value;", on: database)
            XCTAssertThrowsError(try int32Statement.int32(named: "value")) { error in
                XCTAssertEqual(
                    error as? ConsentDatabaseError,
                    .unexpectedType(column: "value", expected: "INTEGER", actual: SQLITE_FLOAT)
                )
            }

            let int64Statement = try preparedRow("SELECT 1.5 AS value;", on: database)
            XCTAssertThrowsError(try int64Statement.int64(named: "value")) { error in
                XCTAssertEqual(
                    error as? ConsentDatabaseError,
                    .unexpectedType(column: "value", expected: "INTEGER", actual: SQLITE_FLOAT)
                )
            }
        }
    }

    private func preparedRow(_ sql: String, on database: OpaquePointer) throws -> ConsentDatabaseStatement {
        let statement = try ConsentDatabaseStatement(database: database, sql: sql)
        XCTAssertTrue(try statement.step())
        return statement
    }

    private func withDatabase(_ operation: (OpaquePointer) throws -> Void) throws {
        var rawDatabase: OpaquePointer?
        XCTAssertEqual(sqlite3_open(":memory:", &rawDatabase), SQLITE_OK)
        let database = try XCTUnwrap(rawDatabase)
        defer { sqlite3_close(database) }
        try operation(database)
    }
}
