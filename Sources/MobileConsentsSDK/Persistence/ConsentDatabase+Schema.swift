import Foundation
import SQLite3

extension ConsentDatabase {
    private struct SchemaColumn: Equatable {
        let name: String
        let type: String
        let isNotNull: Bool
        let primaryKeyPosition: Int32
    }

    private static let currentSchemaVersion: Int32 = 2

    private static let bootstrapSchemaV2 = """
    CREATE TABLE IF NOT EXISTS consent_profile (
        id TEXT PRIMARY KEY NOT NULL,
        external_user_id TEXT
    );

    CREATE UNIQUE INDEX IF NOT EXISTS consent_profile_external_user_id
        ON consent_profile (external_user_id);

    CREATE UNIQUE INDEX IF NOT EXISTS consent_profile_anonymous
        ON consent_profile ((1))
        WHERE external_user_id IS NULL;

    CREATE TABLE IF NOT EXISTS consent_configuration (
        id INTEGER PRIMARY KEY,
        solution_id TEXT NOT NULL,
        client_id TEXT NOT NULL,
        configuration_digest BLOB NOT NULL CHECK (length(configuration_digest) = 32),
        UNIQUE (solution_id, client_id, configuration_digest)
    );

    CREATE TABLE IF NOT EXISTS consent_solution_version (
        id INTEGER PRIMARY KEY,
        configuration_id INTEGER NOT NULL,
        solution_id TEXT NOT NULL,
        version_id TEXT NOT NULL,
        template_texts BLOB NOT NULL,
        UNIQUE (configuration_id, version_id),
        UNIQUE (id, configuration_id),
        FOREIGN KEY (configuration_id) REFERENCES consent_configuration(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS consent_latest_solution (
        configuration_id INTEGER PRIMARY KEY,
        solution_version_row_id INTEGER NOT NULL,
        FOREIGN KEY (configuration_id) REFERENCES consent_configuration(id) ON DELETE CASCADE,
        FOREIGN KEY (solution_version_row_id, configuration_id)
            REFERENCES consent_solution_version(id, configuration_id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS consent_solution_item (
        id INTEGER PRIMARY KEY,
        solution_version_row_id INTEGER NOT NULL,
        universal_id TEXT NOT NULL,
        position INTEGER NOT NULL CHECK (position >= 0),
        required INTEGER NOT NULL CHECK (required IN (0, 1)),
        type TEXT NOT NULL CHECK (
            type IN ('functional', 'necessary', 'statistical', 'marketing', 'privacy policy', 'custom')
        ),
        UNIQUE (solution_version_row_id, position),
        FOREIGN KEY (solution_version_row_id) REFERENCES consent_solution_version(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS consent_solution_item_translation (
        consent_item_row_id INTEGER NOT NULL,
        language TEXT NOT NULL,
        position INTEGER NOT NULL CHECK (position >= 0),
        short_text TEXT NOT NULL,
        long_text TEXT NOT NULL,
        PRIMARY KEY (consent_item_row_id, position),
        FOREIGN KEY (consent_item_row_id) REFERENCES consent_solution_item(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS consent_decision (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id TEXT NOT NULL,
        configuration_id INTEGER NOT NULL,
        solution_version_id TEXT NOT NULL,
        revision_id TEXT NOT NULL UNIQUE,
        submission BLOB NOT NULL,
        synchronization_state TEXT NOT NULL CHECK (
            synchronization_state IN ('pending', 'in_progress', 'synchronized')
        ),
        claimed_at REAL,
        UNIQUE (profile_id, configuration_id, solution_version_id),
        CHECK (
            (synchronization_state = 'in_progress' AND claimed_at IS NOT NULL)
            OR
            (synchronization_state != 'in_progress' AND claimed_at IS NULL)
        ),
        FOREIGN KEY (profile_id) REFERENCES consent_profile(id) ON DELETE CASCADE,
        FOREIGN KEY (configuration_id) REFERENCES consent_configuration(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS consent_decision_choice (
        decision_id INTEGER NOT NULL,
        position INTEGER NOT NULL CHECK (position >= 0),
        universal_id TEXT NOT NULL,
        accepted INTEGER NOT NULL CHECK (accepted IN (0, 1)),
        PRIMARY KEY (decision_id, position),
        FOREIGN KEY (decision_id) REFERENCES consent_decision(id) ON DELETE CASCADE
    );

    CREATE INDEX IF NOT EXISTS consent_decision_claimable
        ON consent_decision (configuration_id, synchronization_state, claimed_at, id)
        WHERE synchronization_state IN ('pending', 'in_progress');

    CREATE INDEX IF NOT EXISTS consent_decision_latest
        ON consent_decision (profile_id, configuration_id, id DESC);

    CREATE INDEX IF NOT EXISTS consent_decision_choice_lookup
        ON consent_decision_choice (decision_id, universal_id);

    CREATE TABLE IF NOT EXISTS consent_legacy_resolution (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        kind TEXT NOT NULL CHECK (kind IN ('imported', 'none', 'cleared')),
        configuration_id INTEGER,
        CHECK (
            (kind = 'imported' AND configuration_id IS NOT NULL)
            OR
            (kind IN ('none', 'cleared') AND configuration_id IS NULL)
        ),
        FOREIGN KEY (configuration_id) REFERENCES consent_configuration(id)
    );

    PRAGMA user_version = 2;
    """

    private static let currentTables: Set<String> = [
        "consent_configuration",
        "consent_decision",
        "consent_decision_choice",
        "consent_latest_solution",
        "consent_profile",
        "consent_legacy_resolution",
        "consent_solution_item",
        "consent_solution_item_translation",
        "consent_solution_version",
    ]

    private static let currentColumns: [String: [SchemaColumn]] = [
        "consent_profile": [
            SchemaColumn(name: "id", type: "TEXT", isNotNull: true, primaryKeyPosition: 1),
            SchemaColumn(name: "external_user_id", type: "TEXT", isNotNull: false, primaryKeyPosition: 0),
        ],
        "consent_configuration": [
            SchemaColumn(name: "id", type: "INTEGER", isNotNull: false, primaryKeyPosition: 1),
            SchemaColumn(name: "solution_id", type: "TEXT", isNotNull: true, primaryKeyPosition: 0),
            SchemaColumn(name: "client_id", type: "TEXT", isNotNull: true, primaryKeyPosition: 0),
            SchemaColumn(name: "configuration_digest", type: "BLOB", isNotNull: true, primaryKeyPosition: 0),
        ],
        "consent_solution_version": [
            SchemaColumn(name: "id", type: "INTEGER", isNotNull: false, primaryKeyPosition: 1),
            SchemaColumn(name: "configuration_id", type: "INTEGER", isNotNull: true, primaryKeyPosition: 0),
            SchemaColumn(name: "solution_id", type: "TEXT", isNotNull: true, primaryKeyPosition: 0),
            SchemaColumn(name: "version_id", type: "TEXT", isNotNull: true, primaryKeyPosition: 0),
            SchemaColumn(name: "template_texts", type: "BLOB", isNotNull: true, primaryKeyPosition: 0),
        ],
        "consent_latest_solution": [
            SchemaColumn(name: "configuration_id", type: "INTEGER", isNotNull: false, primaryKeyPosition: 1),
            SchemaColumn(name: "solution_version_row_id", type: "INTEGER", isNotNull: true, primaryKeyPosition: 0),
        ],
        "consent_solution_item": [
            SchemaColumn(name: "id", type: "INTEGER", isNotNull: false, primaryKeyPosition: 1),
            SchemaColumn(name: "solution_version_row_id", type: "INTEGER", isNotNull: true, primaryKeyPosition: 0),
            SchemaColumn(name: "universal_id", type: "TEXT", isNotNull: true, primaryKeyPosition: 0),
            SchemaColumn(name: "position", type: "INTEGER", isNotNull: true, primaryKeyPosition: 0),
            SchemaColumn(name: "required", type: "INTEGER", isNotNull: true, primaryKeyPosition: 0),
            SchemaColumn(name: "type", type: "TEXT", isNotNull: true, primaryKeyPosition: 0),
        ],
        "consent_solution_item_translation": [
            SchemaColumn(name: "consent_item_row_id", type: "INTEGER", isNotNull: true, primaryKeyPosition: 1),
            SchemaColumn(name: "language", type: "TEXT", isNotNull: true, primaryKeyPosition: 0),
            SchemaColumn(name: "position", type: "INTEGER", isNotNull: true, primaryKeyPosition: 2),
            SchemaColumn(name: "short_text", type: "TEXT", isNotNull: true, primaryKeyPosition: 0),
            SchemaColumn(name: "long_text", type: "TEXT", isNotNull: true, primaryKeyPosition: 0),
        ],
        "consent_decision": [
            SchemaColumn(name: "id", type: "INTEGER", isNotNull: false, primaryKeyPosition: 1),
            SchemaColumn(name: "profile_id", type: "TEXT", isNotNull: true, primaryKeyPosition: 0),
            SchemaColumn(name: "configuration_id", type: "INTEGER", isNotNull: true, primaryKeyPosition: 0),
            SchemaColumn(name: "solution_version_id", type: "TEXT", isNotNull: true, primaryKeyPosition: 0),
            SchemaColumn(name: "revision_id", type: "TEXT", isNotNull: true, primaryKeyPosition: 0),
            SchemaColumn(name: "submission", type: "BLOB", isNotNull: true, primaryKeyPosition: 0),
            SchemaColumn(name: "synchronization_state", type: "TEXT", isNotNull: true, primaryKeyPosition: 0),
            SchemaColumn(name: "claimed_at", type: "REAL", isNotNull: false, primaryKeyPosition: 0),
        ],
        "consent_decision_choice": [
            SchemaColumn(name: "decision_id", type: "INTEGER", isNotNull: true, primaryKeyPosition: 1),
            SchemaColumn(name: "position", type: "INTEGER", isNotNull: true, primaryKeyPosition: 2),
            SchemaColumn(name: "universal_id", type: "TEXT", isNotNull: true, primaryKeyPosition: 0),
            SchemaColumn(name: "accepted", type: "INTEGER", isNotNull: true, primaryKeyPosition: 0),
        ],
        "consent_legacy_resolution": [
            SchemaColumn(name: "id", type: "INTEGER", isNotNull: false, primaryKeyPosition: 1),
            SchemaColumn(name: "kind", type: "TEXT", isNotNull: true, primaryKeyPosition: 0),
            SchemaColumn(name: "configuration_id", type: "INTEGER", isNotNull: false, primaryKeyPosition: 0),
        ],
    ]

    func initialize() throws {
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try withConnection { database in
            try transaction(on: database) {
                let journalMode = try singleString(from: ConsentDatabaseSQL.journalMode.sql, on: database)
                guard journalMode.caseInsensitiveCompare("delete") == .orderedSame else {
                    throw ConsentDatabaseError.incompatibleJournalMode(journalMode)
                }
                let version = try singleInt32(from: ConsentDatabaseSQL.userVersion.sql, on: database)

                switch version {
                case 0:
                    guard try isEmpty(on: database) else {
                        throw ConsentDatabaseError.incompatibleSchema(version: version)
                    }
                    try execute(Self.bootstrapSchemaV2, on: database)
                case Self.currentSchemaVersion:
                    guard try matchesCurrentSchema(on: database) else {
                        throw ConsentDatabaseError.incompatibleSchema(version: version)
                    }
                default:
                    throw ConsentDatabaseError.incompatibleSchema(version: version)
                }
                try validateProductionStatements(on: database)
            }
        }
    }

    private func isEmpty(on database: OpaquePointer) throws -> Bool {
        let statement = try ConsentDatabaseStatement(database: database, sql: ConsentDatabaseSQL.selectEmptyDatabase.sql)
        return try !statement.step()
    }

    private func matchesCurrentSchema(on database: OpaquePointer) throws -> Bool {
        guard try userTableNames(on: database) == Self.currentTables else {
            return false
        }
        guard try Self.currentColumns.allSatisfy({ tableName, expectedColumns in
            try tableColumns(named: tableName, on: database) == expectedColumns
        }) else {
            return false
        }
        return try schemaDefinitions(on: database) == expectedSchemaDefinitions()
    }

    private func expectedSchemaDefinitions() throws -> [String: String] {
        var database: OpaquePointer?
        let result = sqlite3_open(":memory:", &database)
        guard result == SQLITE_OK, let database else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open database"
            if let database { sqlite3_close(database) }
            throw ConsentDatabaseError.openFailed(code: result, message: message)
        }
        defer { sqlite3_close(database) }
        try execute(Self.bootstrapSchemaV2, on: database)
        return try schemaDefinitions(on: database)
    }

    private func schemaDefinitions(on database: OpaquePointer) throws -> [String: String] {
        let statement = try ConsentDatabaseStatement(database: database, sql: ConsentDatabaseSQL.selectSchemaDefinitions.sql)
        var definitions = [String: String]()
        while try statement.step() {
            definitions["\(statement.string(at: 0)):\(statement.string(at: 1))"] = normalizedSchemaSQL(statement.string(at: 2))
        }
        return definitions
    }

    private func normalizedSchemaSQL(_ sql: String) -> String {
        sql.split(whereSeparator: \Character.isWhitespace).joined(separator: " ")
    }

    private func userTableNames(on database: OpaquePointer) throws -> Set<String> {
        let statement = try ConsentDatabaseStatement(database: database, sql: ConsentDatabaseSQL.selectUserTableNames.sql)
        var names = Set<String>()
        while try statement.step() { names.insert(statement.string(at: 0)) }
        return names
    }

    private func tableColumns(named tableName: String, on database: OpaquePointer) throws -> [SchemaColumn] {
        let statement = try ConsentDatabaseStatement(database: database, sql: tableInfo(tableName))
        var columns = [SchemaColumn]()
        while try statement.step() {
            columns.append(SchemaColumn(
                name: statement.string(at: 1),
                type: statement.string(at: 2),
                isNotNull: statement.int32(at: 3) != 0,
                primaryKeyPosition: statement.int32(at: 5)
            ))
        }
        return columns
    }

    private func validateProductionStatements(on database: OpaquePointer) throws {
        for sql in productionStatements {
            _ = try ConsentDatabaseStatement(database: database, sql: sql)
        }
    }

    private var productionStatements: [String] {
        ConsentDatabaseSQL.allCases.map(\.sql) + Self.currentTables.map(tableInfo).sorted()
    }

    private func tableInfo(_ table: String) -> String {
        "PRAGMA table_info(\(table));"
    }
}
