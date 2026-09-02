import Foundation

/// An immutable, concurrency-safe representation of a legacy user consent.
struct UserConsentValue: Codable, Equatable, Sendable {
    let consentItem: ConsentItem
    let isSelected: Bool
}

extension UserConsentValue {
    /// Creates a value snapshot from a legacy user consent.
    init(_ userConsent: UserConsent) {
        self.init(
            consentItem: userConsent.consentItem,
            isSelected: userConsent.isSelected
        )
    }
}

extension UserConsent {
    /// Creates a legacy user consent from a value snapshot.
    convenience init(_ value: UserConsentValue) {
        self.init(consentItem: value.consentItem, isSelected: value.isSelected)
    }

}
