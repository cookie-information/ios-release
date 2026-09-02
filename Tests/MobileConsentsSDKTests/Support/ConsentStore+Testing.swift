import Foundation
@testable import MobileConsentsSDK

extension ConsentStorageDomain {
    static func suite(_ name: String) -> ConsentStorageDomain {
        let fileName = Data(name.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return ConsentStorageDomain(
            legacyUserDefaultsSuiteName: name,
            consentDatabasePath: FileManager.default.temporaryDirectory
                .appendingPathComponent("MobileConsentsSDK-\(fileName).sqlite3")
                .path
        )
    }
}

extension ConsentStore {
    init?(
        suiteName: String,
        solutionID: String,
        clientID: String,
        clientSecret: String
    ) {
        let domain = ConsentStorageDomain.suite(suiteName)
        guard domain.makeLegacyUserDefaults() != nil else {
            return nil
        }
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

    func recordPostResult(
        consents: [UserConsentValue],
        versionId: String,
        isInSync: Bool,
        solutionID: String = "solution"
    ) {
        let submission = Consent(
            consentSolutionId: solutionID,
            consentSolutionVersionId: versionId,
            customData: nil,
            userConsents: consents.map(UserConsent.init)
        ).submissionValue
        recordPostResult(
            submission: submission,
            isInSync: isInSync
        )
    }

    func recordPostResult(
        submission: ConsentSubmissionValue,
        isInSync: Bool
    ) {
        do {
            try savePending(submission: submission)
            if isInSync {
                guard let claim = try claimPendingSynchronization(),
                      try completeSynchronizationClaim(claim) else {
                    return
                }
            }
        } catch {
            return
        }
    }
}
