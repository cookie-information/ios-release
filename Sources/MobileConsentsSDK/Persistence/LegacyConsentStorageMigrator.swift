import Foundation

struct LegacyConsentStorageMigrator: Sendable {
    private let database: ConsentDatabase
    private let domain: ConsentStorageDomain
    private let partition: ConsentPartitionID

    init(
        database: ConsentDatabase,
        domain: ConsentStorageDomain,
        partition: ConsentPartitionID
    ) {
        self.database = database
        self.domain = domain
        self.partition = partition
    }

    func initializeAndMigrate() throws {
        try database.initialize()
        guard let userDefaults = domain.makeLegacyUserDefaults() else {
            throw ConsentStoreError.persistenceFailed
        }
        let userID = userDefaults.string(forKey: LegacyConsentStorageKey.userIdKey)
        let versionID = userDefaults.string(forKey: LegacyConsentStorageKey.consentsVersionIdKey)
        let values = try LegacyConsentStorageCodec.strictDecode(
            userDefaults.object(forKey: LegacyConsentStorageKey.consentsKey)
        )
        let submission: ConsentSubmissionValue?
        if userID != nil, let versionID {
            submission = Consent(
                consentSolutionId: partition.solutionID,
                consentSolutionVersionId: versionID,
                customData: nil,
                userConsents: values.values.map(UserConsent.init)
            ).submissionValue
        } else {
            submission = nil
        }
        try database.importLegacyIfNeeded(
            userID: userID,
            submission: submission,
            synchronizationState: userDefaults.object(
                forKey: LegacyConsentStorageKey.consentsInSyncKey
            ) as? Bool == false ? .pending : .synchronized,
            partition: partition
        )
        removeLegacyValues()
    }

    func removeLegacyValues() {
        guard let userDefaults = domain.makeLegacyUserDefaults() else {
            return
        }
        userDefaults.removeObject(forKey: LegacyConsentStorageKey.userIdKey)
        userDefaults.removeObject(forKey: LegacyConsentStorageKey.consentsVersionIdKey)
        userDefaults.removeObject(forKey: LegacyConsentStorageKey.consentsKey)
        userDefaults.removeObject(forKey: LegacyConsentStorageKey.consentsInSyncKey)
    }
}
