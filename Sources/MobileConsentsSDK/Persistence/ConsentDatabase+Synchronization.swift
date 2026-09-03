import Foundation
import SQLite3

extension ConsentDatabase {
    func claimPendingSynchronization(
        partition: ConsentPartitionID,
        at date: Date
    ) throws -> ConsentSynchronizationClaim? {
        let claimedAt = date.timeIntervalSince1970
        let abandonedBefore = claimedAt - 60
        return try withConnection { database in
            let statement = try ConsentDatabaseStatement(
                database: database,
                   sql: ConsentDatabaseSQL.claimPendingSynchronization.sql
            )
            try statement.bind(partition.solutionID, to: ":solutionID")
            try statement.bind(partition.clientID, to: ":clientID")
            try statement.bind(partition.fingerprint.digest, to: ":configurationDigest")
            try statement.bind(abandonedBefore, to: ":abandonedBefore")
            try statement.bind(claimedAt, to: ":claimedAt")
            guard try statement.step() else {
                return nil
            }
            guard let revisionID = UUID(uuidString: try statement.string(named: "revision_id")) else {
                throw ConsentDatabaseError.statementFailed(
                    code: SQLITE_CORRUPT,
                    message: "Invalid consent revision ID"
                )
            }
            return ConsentSynchronizationClaim(
                userID: try statement.string(named: "profile_id"),
                revisionID: revisionID,
                solutionVersionID: try statement.string(named: "solution_version_id"),
                submission: try JSONDecoder().decode(
                    ConsentSubmissionValue.self,
                    from: statement.data(named: "submission")
                ),
                claimedAt: Date(timeIntervalSince1970: try statement.double(named: "claimed_at"))
            )
        }
    }

    func hasPendingSynchronization(
        partition: ConsentPartitionID
    ) throws -> Bool {
        try withConnection { database in
            let statement = try ConsentDatabaseStatement(
                database: database,
                   sql: ConsentDatabaseSQL.hasPendingSynchronization.sql
            )
            try statement.bind(partition.solutionID, to: ":solutionID")
            try statement.bind(partition.clientID, to: ":clientID")
            try statement.bind(partition.fingerprint.digest, to: ":configurationDigest")
            return try statement.step()
        }
    }

    func completeSynchronizationClaim(
        _ claim: ConsentSynchronizationClaim,
        partition: ConsentPartitionID
    ) throws -> Bool {
        try transitionSynchronizationClaim(
            claim,
            to: .synchronized,
            partition: partition
        )
    }

    func releaseSynchronizationClaim(
        _ claim: ConsentSynchronizationClaim,
        partition: ConsentPartitionID
    ) throws -> Bool {
        try transitionSynchronizationClaim(
            claim,
            to: .pending,
            partition: partition
        )
    }

    func isSynchronizationClaimCurrent(
        partition: ConsentPartitionID,
        claim: ConsentSynchronizationClaim
    ) throws -> Bool {
        try withConnection { database in
            let statement = try ConsentDatabaseStatement(
                database: database,
                   sql: ConsentDatabaseSQL.isSynchronizationClaimCurrent.sql
            )
            try statement.bind(claim.userID, to: ":profileID")
            try statement.bind(partition.solutionID, to: ":solutionID")
            try statement.bind(partition.clientID, to: ":clientID")
            try statement.bind(partition.fingerprint.digest, to: ":configurationDigest")
            try statement.bind(claim.solutionVersionID, to: ":solutionVersionID")
            try statement.bind(claim.revisionID.uuidString, to: ":revisionID")
            try statement.bind(claim.claimedAt.timeIntervalSince1970, to: ":claimedAt")
            return try statement.step()
        }
    }

    private func transitionSynchronizationClaim(
        _ claim: ConsentSynchronizationClaim,
        to state: SynchronizationState,
        partition: ConsentPartitionID
    ) throws -> Bool {
        try withConnection { database in
            let statement = try ConsentDatabaseStatement(
                database: database,
                   sql: ConsentDatabaseSQL.transitionSynchronizationClaim.sql
            )
            try statement.bind(claim.revisionID.uuidString, to: ":revisionID")
            try statement.bind(state.rawValue, to: ":state")
            try statement.bind(claim.userID, to: ":profileID")
            try statement.bind(partition.solutionID, to: ":solutionID")
            try statement.bind(partition.clientID, to: ":clientID")
            try statement.bind(partition.fingerprint.digest, to: ":configurationDigest")
            try statement.bind(claim.solutionVersionID, to: ":solutionVersionID")
            try statement.bind(claim.claimedAt.timeIntervalSince1970, to: ":claimedAt")
            return try statement.step()
        }
    }
}
