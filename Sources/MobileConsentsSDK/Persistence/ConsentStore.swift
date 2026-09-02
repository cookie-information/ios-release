import Foundation

struct ConsentStoreSnapshot: Sendable {
    let versionId: String?
    let values: [String: UserConsentValue]
}

enum ConsentStoreError: Error, Equatable, Sendable {
    case readFailed
    case persistenceFailed
    case solutionMismatch
}

enum SynchronizationState: String, Equatable, Sendable {
    case pending
    case synchronized
}

struct ConsentSynchronizationClaim: Equatable, Sendable {
    let userID: String
    let revisionID: UUID
    let solutionVersionID: String
    let submission: ConsentSubmissionValue
    let claimedAt: Date
}

extension ConsentSubmissionValue {
    var userConsentsByID: [String: UserConsentValue] {
        Dictionary(userConsents.map { ($0.consentItem.id, $0) }, uniquingKeysWith: { _, latest in latest })
    }
}
struct ConsentStore: Sendable {
    private let database: ConsentDatabase
    private let domain: ConsentStorageDomain
    private let partition: ConsentPartitionID
    private let now: @Sendable () -> Date

    private var legacyMigrator: LegacyConsentStorageMigrator {
        LegacyConsentStorageMigrator(
            database: database,
            domain: domain,
            partition: partition
        )
    }

    init(solutionID: String, clientID: String, clientSecret: String) {
        let domain = ConsentStorageDomain.standard
        self.init(
            database: ConsentDatabase(path: domain.consentDatabasePath),
            domain: domain,
            partition: ConsentPartitionID(
                solutionID: solutionID,
                clientID: clientID,
                clientSecret: clientSecret
            )
        )
    }

    init(
        database: ConsentDatabase,
        domain: ConsentStorageDomain,
        partition: ConsentPartitionID,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.database = database
        self.domain = domain
        self.partition = partition
        self.now = now
    }

    static func defaultUserID() -> String {
        let domain = ConsentStorageDomain.standard
        do {
            let database = ConsentDatabase(path: domain.consentDatabasePath)
            try database.initialize()
            return try database.userID()
        } catch {
            return ""
        }
    }

    var userId: String {
        (try? userID()) ?? ""
    }

    var consents: [String: UserConsentValue] {
        (try? readSnapshot().values) ?? [:]
    }

    func userID() throws -> String {
        do {
            try legacyMigrator.initializeAndMigrate()
            return try database.userID()
        } catch {
            if error is ConsentStoreError {
                throw error
            }
            throw ConsentStoreError.persistenceFailed
        }
    }

    func readSnapshot() throws -> ConsentStoreSnapshot {
        do {
            try legacyMigrator.initializeAndMigrate()
            return try database.snapshot(partition: partition)
        } catch {
            if error is ConsentStoreError {
                throw error
            }
            throw ConsentStoreError.readFailed
        }
    }

    func cacheConsentSolution(_ solution: ConsentSolutionValue) throws {
        do {
            try legacyMigrator.initializeAndMigrate()
            try database.cacheConsentSolution(solution, partition: partition)
        } catch {
            if let error = error as? ConsentStoreError {
                throw error
            }
            throw ConsentStoreError.persistenceFailed
        }
    }

    func savePending(submission: ConsentSubmissionValue) throws {
        guard submission.consentSolutionId == partition.solutionID else {
            throw ConsentStoreError.solutionMismatch
        }

        do {
            try legacyMigrator.initializeAndMigrate()
            try database.store(
                submission: submission,
                synchronizationState: .pending,
                partition: partition
            )
        } catch {
            if let error = error as? ConsentStoreError {
                throw error
            }
            throw ConsentStoreError.persistenceFailed
        }
    }

    func claimPendingSynchronization() throws -> ConsentSynchronizationClaim? {
        do {
            try legacyMigrator.initializeAndMigrate()
            return try database.claimPendingSynchronization(
                partition: partition,
                at: now()
            )
        } catch {
            if error is ConsentStoreError {
                throw error
            }
            throw ConsentStoreError.persistenceFailed
        }
    }

    func hasPendingSynchronization() throws -> Bool {
        do {
            try legacyMigrator.initializeAndMigrate()
            return try database.hasPendingSynchronization(partition: partition)
        } catch {
            if error is ConsentStoreError {
                throw error
            }
            throw ConsentStoreError.readFailed
        }
    }

    func completeSynchronizationClaim(
        _ claim: ConsentSynchronizationClaim
    ) throws -> Bool {
        do {
            try legacyMigrator.initializeAndMigrate()
            return try database.completeSynchronizationClaim(
                claim,
                partition: partition
            )
        } catch {
            if error is ConsentStoreError {
                throw error
            }
            throw ConsentStoreError.persistenceFailed
        }
    }

    func releaseSynchronizationClaim(
        _ claim: ConsentSynchronizationClaim
    ) throws -> Bool {
        do {
            try legacyMigrator.initializeAndMigrate()
            return try database.releaseSynchronizationClaim(
                claim,
                partition: partition
            )
        } catch {
            if error is ConsentStoreError {
                throw error
            }
            throw ConsentStoreError.persistenceFailed
        }
    }

    func isSynchronizationClaimCurrent(
        _ claim: ConsentSynchronizationClaim
    ) throws -> Bool {
        do {
            try legacyMigrator.initializeAndMigrate()
            return try database.isSynchronizationClaimCurrent(
                partition: partition,
                claim: claim
            )
        } catch {
            if error is ConsentStoreError {
                throw error
            }
            throw ConsentStoreError.readFailed
        }
    }

    func clearAll() throws {
        do {
            try database.initialize()
            try database.clearProfile()
            legacyMigrator.removeLegacyValues()
        } catch {
            if error is ConsentStoreError {
                throw error
            }
            throw ConsentStoreError.persistenceFailed
        }
    }
}
