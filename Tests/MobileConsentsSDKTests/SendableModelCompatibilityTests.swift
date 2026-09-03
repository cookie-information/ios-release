import XCTest
import MobileConsentsSDK

final class SendableModelCompatibilityTests: XCTestCase {
    func testLeafModelsHaveSendableContracts() {
        requireSendable(ProcessingPurpose.self)
        requireSendable(ConsentItemType.self)
        requireSendable(ConsentTranslation.self)
        requireSendable(TemplateTranslation.self)
        requireSendable(ConsentItem.self)
        requireSendable(SavedConsent.self)
        requireSendable(ConsentPurpose.self)
        requireSendable(Translated<ConsentTranslation>.self)
        requireSendable(Translated<TemplateTranslation>.self)

        // Keep this instantiation check to protect Translation from a blanket Sendable requirement;
        // it is not a negative Sendable compile assertion.
        let _: Translated<ExternalTranslation>.Type = Translated<ExternalTranslation>.self
    }

    private func requireSendable<T: Sendable>(_: T.Type) {}
}

private final class ExternalTranslationReference: Codable, Equatable {
    let value: String

    init(value: String) {
        self.value = value
    }

    static func == (lhs: ExternalTranslationReference, rhs: ExternalTranslationReference) -> Bool {
        lhs.value == rhs.value
    }
}

private struct ExternalTranslation: MobileConsentsSDK.Translation, Codable, Equatable {
    let language: String
    let reference: ExternalTranslationReference
}
