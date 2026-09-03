import Foundation
import SQLite3

extension ConsentDatabase {
    func cacheConsentSolution(
        _ solution: ConsentSolutionValue,
        partition: ConsentPartitionID
    ) throws {
        try withConnection { database in
            try transaction(on: database) {
                let configurationID = try ensureConfigurationID(for: partition, on: database)
                let version = try insertSolutionVersion(
                    solution,
                    configurationID: configurationID,
                    on: database
                )
                if version.wasInserted {
                    try insertConsentItems(
                        solution.consentItems,
                        solutionVersionRowID: version.id,
                        on: database
                    )
                }
                let latest = try ConsentDatabaseStatement(
                    database: database,
                     sql: ConsentDatabaseSQL.insertLatestSolution.sql
                )
                try latest.bind(configurationID, to: ":configurationID")
                try latest.bind(version.id, to: ":solutionVersionRowID")
                try latest.execute()
            }
        }
    }

    func latestConsentSolution(
        partition: ConsentPartitionID,
        primaryLanguage: String
    ) throws -> ConsentSolutionValue? {
        try withConnection { database in
            try readTransaction(on: database) {
                let version = try ConsentDatabaseStatement(
                    database: database,
                     sql: ConsentDatabaseSQL.selectLatestSolution.sql
                )
                try version.bind(partition.solutionID, to: ":solutionID")
                try version.bind(partition.clientID, to: ":clientID")
                try version.bind(partition.fingerprint.digest, to: ":configurationDigest")
                guard try version.step() else {
                    return Optional<ConsentSolutionValue>.none
                }
                let decoder = JSONDecoder()
                decoder.userInfo[primaryLanguageCodingUserInfoKey] = primaryLanguage
                return ConsentSolutionValue(
                    id: try version.string(named: "solution_id"),
                    versionId: try version.string(named: "version_id"),
                    templateTexts: try decoder.decode(
                        TemplateTextsValue.self,
                        from: version.data(named: "template_texts")
                    ),
                    consentItems: try consentItems(
                        solutionVersionRowID: try version.int64(named: "id"),
                        primaryLanguage: primaryLanguage,
                        on: database
                    )
                )
            }
        }
    }

    private func insertSolutionVersion(
        _ solution: ConsentSolutionValue,
        configurationID: Int64,
        on database: OpaquePointer
    ) throws -> (id: Int64, wasInserted: Bool) {
        let insert = try ConsentDatabaseStatement(
            database: database,
             sql: ConsentDatabaseSQL.insertSolutionVersion.sql
        )
        try insert.bind(configurationID, to: ":configurationID")
        try insert.bind(solution.id, to: ":solutionID")
        try insert.bind(solution.versionId, to: ":versionID")
        try insert.bind(JSONEncoder().encode(solution.templateTexts), to: ":templateTexts")
        try insert.execute()
        let wasInserted = sqlite3_changes(database) == 1

        let select = try ConsentDatabaseStatement(
            database: database,
             sql: ConsentDatabaseSQL.selectSolutionVersionID.sql
        )
        try select.bind(configurationID, to: ":configurationID")
        try select.bind(solution.versionId, to: ":versionID")
        guard try select.step() else {
            throw statementFailure(on: database)
        }
        return (try select.int64(named: "id"), wasInserted)
    }

    private func insertConsentItems(
        _ consentItems: [ConsentItem],
        solutionVersionRowID: Int64,
        on database: OpaquePointer
    ) throws {
        for (position, consentItem) in consentItems.enumerated() {
            let item = try ConsentDatabaseStatement(
                database: database,
                 sql: ConsentDatabaseSQL.insertSolutionItem.sql
            )
            try item.bind(solutionVersionRowID, to: ":solutionVersionRowID")
            try item.bind(consentItem.id, to: ":universalID")
            try item.bind(Int64(position), to: ":position")
            try item.bind(Int32(consentItem.required ? 1 : 0), to: ":required")
            try item.bind(consentItem.type.rawValue, to: ":type")
            try item.execute()
            let itemRowID = sqlite3_last_insert_rowid(database)

            for (translationPosition, translation) in consentItem.translations.translations.enumerated() {
                let statement = try ConsentDatabaseStatement(
                    database: database,
                     sql: ConsentDatabaseSQL.insertSolutionItemTranslation.sql
                )
                try statement.bind(itemRowID, to: ":consentItemRowID")
                try statement.bind(translation.language, to: ":language")
                try statement.bind(Int64(translationPosition), to: ":position")
                try statement.bind(translation.shortText, to: ":shortText")
                try statement.bind(translation.longText, to: ":longText")
                try statement.execute()
            }
        }
    }

    private func consentItems(
        solutionVersionRowID: Int64,
        primaryLanguage: String,
        on database: OpaquePointer
    ) throws -> [ConsentItem] {
        let items = try ConsentDatabaseStatement(
            database: database,
             sql: ConsentDatabaseSQL.selectSolutionItems.sql
        )
        try items.bind(solutionVersionRowID, to: ":solutionVersionRowID")
        var values = [ConsentItem]()
        while try items.step() {
            guard let type = ConsentItemType(rawValue: try items.string(named: "type")) else {
                throw statementFailure(on: database)
            }
            values.append(
                ConsentItem(
                    id: try items.string(named: "universal_id"),
                    required: try items.int32(named: "required") != 0,
                    type: type,
                    translations: Translated(
                        translations: try consentTranslations(
                            consentItemRowID: try items.int64(named: "id"),
                            on: database
                        ),
                        primaryLanguage: primaryLanguage
                    )
                )
            )
        }
        return values
    }

    private func consentTranslations(
        consentItemRowID: Int64,
        on database: OpaquePointer
    ) throws -> [ConsentTranslation] {
        let statement = try ConsentDatabaseStatement(
            database: database,
             sql: ConsentDatabaseSQL.selectSolutionItemTranslations.sql
        )
        try statement.bind(consentItemRowID, to: ":consentItemRowID")
        var translations = [ConsentTranslation]()
        while try statement.step() {
            translations.append(
                ConsentTranslation(
                    language: try statement.string(named: "language"),
                    shortText: try statement.string(named: "short_text"),
                    longText: try statement.string(named: "long_text")
                )
            )
        }
        return translations
    }

    private func readTransaction<Result>(
        on database: OpaquePointer,
        _ operation: () throws -> Result
    ) throws -> Result {
        try execute(ConsentDatabaseSQL.begin.sql, on: database)
        do {
            let result = try operation()
            try execute(ConsentDatabaseSQL.commit.sql, on: database)
            return result
        } catch {
            try? execute(ConsentDatabaseSQL.rollback.sql, on: database)
            throw error
        }
    }
}
