/// An immutable, concurrency-safe snapshot of a consent submission.
struct ConsentSubmissionValue: Codable, Equatable, Sendable {
    let consentSolutionId: String
    let consentSolutionVersionId: String
    let processingPurposes: [ProcessingPurpose]
    let customData: [String: String]?
    let userConsents: [UserConsentValue]

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.consentSolutionId == rhs.consentSolutionId &&
        lhs.consentSolutionVersionId == rhs.consentSolutionVersionId &&
        lhs.processingPurposes.elementsEqual(rhs.processingPurposes) { lhsPurpose, rhsPurpose in
            lhsPurpose.consentItemId == rhsPurpose.consentItemId &&
            lhsPurpose.consentGiven == rhsPurpose.consentGiven &&
            lhsPurpose.language == rhsPurpose.language
        } &&
        lhs.customData == rhs.customData &&
        lhs.userConsents == rhs.userConsents
    }
}

extension ConsentSubmissionValue {
    /// Creates a value snapshot of the consent's current submission state.
    init(_ consent: Consent) {
        self.init(
            consentSolutionId: consent.consentSolutionId,
            consentSolutionVersionId: consent.consentSolutionVersionId,
            processingPurposes: consent.processingPurposes,
            customData: consent.customData,
            userConsents: consent.userConsents.map(UserConsentValue.init)
        )
    }
}

extension Consent {
    /// Creates a consent from a submission snapshot while retaining its current purposes.
    init(_ value: ConsentSubmissionValue) {
        self.init(
            consentSolutionId: value.consentSolutionId,
            consentSolutionVersionId: value.consentSolutionVersionId,
            customData: value.customData,
            userConsents: value.userConsents.map { UserConsent($0) }
        )
        self.processingPurposes = value.processingPurposes
    }

    /// Returns a value snapshot of this consent's current submission state.
    var submissionValue: ConsentSubmissionValue {
        ConsentSubmissionValue(self)
    }
}
