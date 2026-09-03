import Foundation
import SQLite3

private enum LegacyResolutionKind: String {
    case imported
    case none
    case cleared
}

extension ConsentDatabase {
    func snapshot(
        partition: ConsentPartitionID
    ) throws -> ConsentStoreSnapshot {
        try withConnection { database in
            guard let userID = try anonymousUserID(on: database) else {
                return ConsentStoreSnapshot(
                    versionId: nil,
                    values: [:]
                )
            }
            let statement = try ConsentDatabaseStatement(
                database: database,
                sql: ConsentDatabaseSQL.selectLatestDecision.sql
            )
            try statement.bind(userID, to: ":profileID")
            try statement.bind(partition.solutionID, to: ":solutionID")
            try statement.bind(partition.clientID, to: ":clientID")
            try statement.bind(partition.fingerprint.digest, to: ":configurationDigest")
            guard try statement.step() else {
                return ConsentStoreSnapshot(
                    versionId: nil,
                    values: [:]
                )
            }
            let submission = try JSONDecoder().decode(
                ConsentSubmissionValue.self,
                from: statement.data(named: "submission")
            )
            return ConsentStoreSnapshot(
                versionId: try statement.string(named: "solution_version_id"),
                values: submission.userConsentsByID
            )
        }
    }

    func store(
        submission: ConsentSubmissionValue,
        synchronizationState: SynchronizationState,
        partition: ConsentPartitionID
    ) throws {
        try withConnection { database in
            try transaction(on: database) {
                let userID: String
                if let existing = try anonymousUserID(on: database) {
                    userID = existing
                } else {
                    userID = UUID().uuidString
                    let profile = try ConsentDatabaseStatement(
                        database: database,
                        sql: ConsentDatabaseSQL.insertProfile.sql
                    )
                    try profile.bind(userID, to: ":id")
                    try profile.execute()
                }

                try insertDecision(
                    submission: submission,
                    synchronizationState: synchronizationState,
                    partition: partition,
                    userID: userID,
                    on: database
                )
            }
        }
    }

    /// The first caller resolves the domain-wide 1.x state because it has no partition metadata.
    func importLegacyIfNeeded(
        userID: String?,
        submission: ConsentSubmissionValue?,
        synchronizationState: SynchronizationState,
        partition: ConsentPartitionID
    ) throws {
        try withConnection { database in
            if try hasLegacyResolution(on: database) {
                return
            }
            try transaction(on: database) {
                if try hasLegacyResolution(on: database) {
                    return
                }
                guard let userID else {
                    try writeLegacyResolution(.none, partition: nil, on: database)
                    return
                }
                guard try anonymousUserID(on: database) == nil else {
                    try writeLegacyResolution(.none, partition: nil, on: database)
                    return
                }
                let profile = try ConsentDatabaseStatement(
                    database: database,
                    sql: ConsentDatabaseSQL.insertProfile.sql
                )
                try profile.bind(userID, to: ":id")
                try profile.execute()
                if let submission {
                    try insertDecision(
                        submission: submission,
                        synchronizationState: synchronizationState,
                        partition: partition,
                        userID: userID,
                        on: database
                    )
                }
                try writeLegacyResolution(.imported, partition: partition, on: database)
            }
        }
    }

    func clearProfile() throws {
        try withConnection { database in
            try transaction(on: database) {
                try execute(ConsentDatabaseSQL.deleteProfile.sql, on: database)
                try writeLegacyResolution(.cleared, partition: nil, on: database)
            }
        }
    }

    private func hasLegacyResolution(on database: OpaquePointer) throws -> Bool {
        let statement = try ConsentDatabaseStatement(
            database: database,
            sql: ConsentDatabaseSQL.selectLegacyResolution.sql
        )
        return try statement.step()
    }

    private func writeLegacyResolution(
        _ kind: LegacyResolutionKind,
        partition: ConsentPartitionID?,
        on database: OpaquePointer
    ) throws {
        let configurationID = try partition.map {
            try ensureConfigurationID(for: $0, on: database)
        }
        let statement = try ConsentDatabaseStatement(
            database: database,
            sql: ConsentDatabaseSQL.insertLegacyResolution.sql
        )
        try statement.bind(kind.rawValue, to: ":kind")
        try statement.bind(configurationID, to: ":configurationID")
        try statement.execute()
    }

    private func insertDecision(
        submission: ConsentSubmissionValue,
        synchronizationState: SynchronizationState,
        partition: ConsentPartitionID,
        userID: String,
        on database: OpaquePointer
    ) throws {
        let configurationID = try ensureConfigurationID(for: partition, on: database)
        let existing = try ConsentDatabaseStatement(
            database: database,
            sql: ConsentDatabaseSQL.selectDecisionForInsert.sql
        )
        try existing.bind(userID, to: ":profileID")
        try existing.bind(configurationID, to: ":configurationID")
        try existing.bind(submission.consentSolutionVersionId, to: ":solutionVersionID")
        let preservesActiveClaim = try existing.step()
            && (try existing.string(named: "synchronization_state")) == "in_progress"
            && synchronizationState == .pending
        let claimedAt = preservesActiveClaim ? try existing.double(named: "claimed_at") : nil

        let delete = try ConsentDatabaseStatement(
            database: database,
            sql: ConsentDatabaseSQL.deleteDecision.sql
        )
        try delete.bind(userID, to: ":profileID")
        try delete.bind(configurationID, to: ":configurationID")
        try delete.bind(submission.consentSolutionVersionId, to: ":solutionVersionID")
        try delete.execute()

        let revisionID = UUID()
        let decision = try ConsentDatabaseStatement(
            database: database,
            sql: ConsentDatabaseSQL.insertDecision.sql
        )
        try decision.bind(userID, to: ":profileID")
        try decision.bind(configurationID, to: ":configurationID")
        try decision.bind(submission.consentSolutionVersionId, to: ":solutionVersionID")
        try decision.bind(revisionID.uuidString, to: ":revisionID")
        try decision.bind(JSONEncoder().encode(submission), to: ":submission")
        try decision.bind(
            preservesActiveClaim ? "in_progress" : synchronizationState.rawValue,
            to: ":synchronizationState"
        )
        try decision.bind(claimedAt, to: ":claimedAt")
        guard try decision.step() else {
            throw statementFailure(on: database)
        }
        let decisionID = try decision.int64(named: "id")

        for (position, choice) in submission.userConsents.enumerated() {
            let statement = try ConsentDatabaseStatement(
                database: database,
                sql: ConsentDatabaseSQL.insertDecisionChoice.sql
            )
            try statement.bind(decisionID, to: ":decisionID")
            try statement.bind(Int64(position), to: ":position")
            try statement.bind(choice.consentItem.id, to: ":universalID")
            try statement.bind(Int32(choice.isSelected ? 1 : 0), to: ":accepted")
            try statement.execute()
        }
    }
}