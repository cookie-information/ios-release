import Foundation
import SQLite3

final class ConsentDatabaseStatement {
    private let database: OpaquePointer
    private let statement: OpaquePointer

    init(database: OpaquePointer, sql: String) throws {
        self.database = database
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
        guard result == SQLITE_OK, let statement else {
            throw ConsentDatabaseError.statementFailed(
                code: result,
                message: String(cString: sqlite3_errmsg(database))
            )
        }
        self.statement = statement
    }

    deinit {
        sqlite3_finalize(statement)
    }

    func bind(_ value: String, at index: Int32) throws {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        try check(sqlite3_bind_text(statement, index, value, -1, transient))
    }

    func bind(_ value: String, to parameter: String) throws {
        try bind(value, at: try parameterIndex(named: parameter))
    }

    func bind(_ value: Double, at index: Int32) throws {
        try check(sqlite3_bind_double(statement, index, value))
    }

    func bind(_ value: Double, to parameter: String) throws {
        try bind(value, at: try parameterIndex(named: parameter))
    }

    func bind(_ value: Double?, at index: Int32) throws {
        guard let value else {
            try check(sqlite3_bind_null(statement, index))
            return
        }
        try bind(value, at: index)
    }

    func bind(_ value: Double?, to parameter: String) throws {
        guard let value else {
            try check(sqlite3_bind_null(statement, try parameterIndex(named: parameter)))
            return
        }
        try bind(value, to: parameter)
    }

    func bind(_ value: Int64, at index: Int32) throws {
        try check(sqlite3_bind_int64(statement, index, value))
    }

    func bind(_ value: Int64, to parameter: String) throws {
        try bind(value, at: try parameterIndex(named: parameter))
    }

    func bind(_ value: Int32, at index: Int32) throws {
        try check(sqlite3_bind_int(statement, index, value))
    }

    func bind(_ value: Int32, to parameter: String) throws {
        try bind(value, at: try parameterIndex(named: parameter))
    }

    func bind(_ value: Int64?, at index: Int32) throws {
        guard let value else {
            try check(sqlite3_bind_null(statement, index))
            return
        }
        try bind(value, at: index)
    }

    func bind(_ value: Int64?, to parameter: String) throws {
        guard let value else {
            try check(sqlite3_bind_null(statement, try parameterIndex(named: parameter)))
            return
        }
        try bind(value, to: parameter)
    }

    func bind(_ value: Data, at index: Int32) throws {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let result = value.withUnsafeBytes { bytes in
            sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(bytes.count), transient)
        }
        try check(result)
    }

    func bind(_ value: Data, to parameter: String) throws {
        try bind(value, at: try parameterIndex(named: parameter))
    }

    func bind(_ value: Data?, at index: Int32) throws {
        guard let value else {
            try check(sqlite3_bind_null(statement, index))
            return
        }
        try bind(value, at: index)
    }

    func bind(_ value: Data?, to parameter: String) throws {
        guard let value else {
            try check(sqlite3_bind_null(statement, try parameterIndex(named: parameter)))
            return
        }
        try bind(value, to: parameter)
    }

    func bind(_ value: String?, at index: Int32) throws {
        guard let value else {
            try check(sqlite3_bind_null(statement, index))
            return
        }
        try bind(value, at: index)
    }

    func bind(_ value: String?, to parameter: String) throws {
        guard let value else {
            try check(sqlite3_bind_null(statement, try parameterIndex(named: parameter)))
            return
        }
        try bind(value, to: parameter)
    }

    func execute() throws {
        try check(sqlite3_step(statement), expected: SQLITE_DONE)
    }

    func step() throws -> Bool {
        let result = sqlite3_step(statement)
        if result == SQLITE_ROW {
            return true
        }
        try check(result, expected: SQLITE_DONE)
        return false
    }

    func string(at index: Int32) -> String {
        guard let value = sqlite3_column_text(statement, index) else {
            return ""
        }
        return String(cString: value)
    }

    func int32(at index: Int32) -> Int32 {
        sqlite3_column_int(statement, index)
    }

    func int64(at index: Int32) -> Int64 {
        sqlite3_column_int64(statement, index)
    }

    func double(at index: Int32) -> Double {
        sqlite3_column_double(statement, index)
    }

    func data(at index: Int32) -> Data {
        guard let bytes = sqlite3_column_blob(statement, index) else {
            return Data()
        }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, index)))
    }

    func string(named column: String) throws -> String {
        let index = try columnIndex(named: column)
        try requireType(SQLITE_TEXT, named: column, at: index)
        guard let value = sqlite3_column_text(statement, index) else {
            throw ConsentDatabaseError.unexpectedNull(column: column)
        }
        return String(cString: value)
    }

    func double(named column: String) throws -> Double {
        let index = try columnIndex(named: column)
        try requireType(SQLITE_FLOAT, named: column, at: index)
        return sqlite3_column_double(statement, index)
    }

    func data(named column: String) throws -> Data {
        let index = try columnIndex(named: column)
        try requireType(SQLITE_BLOB, named: column, at: index)
        guard let bytes = sqlite3_column_blob(statement, index) else {
            return Data()
        }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, index)))
    }

    func int32(named column: String) throws -> Int32 {
        let index = try columnIndex(named: column)
        try requireType(SQLITE_INTEGER, named: column, at: index)
        return sqlite3_column_int(statement, index)
    }

    func int64(named column: String) throws -> Int64 {
        let index = try columnIndex(named: column)
        try requireType(SQLITE_INTEGER, named: column, at: index)
        return sqlite3_column_int64(statement, index)
    }

    private func parameterIndex(named parameter: String) throws -> Int32 {
        let index = sqlite3_bind_parameter_index(statement, parameter)
        guard index > 0 else {
            throw ConsentDatabaseError.unknownParameter(parameter)
        }
        return index
    }

    private func columnIndex(named column: String) throws -> Int32 {
        for index in 0..<sqlite3_column_count(statement) {
            if String(cString: sqlite3_column_name(statement, index)) == column {
                return index
            }
        }
        throw ConsentDatabaseError.unknownColumn(column)
    }

    private func requireType(_ expected: Int32, named column: String, at index: Int32) throws {
        let actual = sqlite3_column_type(statement, index)
        if actual == SQLITE_NULL {
            throw ConsentDatabaseError.unexpectedNull(column: column)
        }
        guard actual == expected else {
            throw ConsentDatabaseError.unexpectedType(
                column: column,
                expected: sqliteTypeName(expected),
                actual: actual
            )
        }
    }

    private func sqliteTypeName(_ type: Int32) -> String {
        switch type {
        case SQLITE_INTEGER: "INTEGER"
        case SQLITE_FLOAT: "FLOAT"
        case SQLITE_TEXT: "TEXT"
        case SQLITE_BLOB: "BLOB"
        case SQLITE_NULL: "NULL"
        default: "UNKNOWN"
        }
    }

    private func check(_ result: Int32, expected: Int32 = SQLITE_OK) throws {
        guard result == expected else {
            throw ConsentDatabaseError.statementFailed(
                code: result,
                message: String(cString: sqlite3_errmsg(database))
            )
        }
    }
}