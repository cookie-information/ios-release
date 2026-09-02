import Foundation
import UIKit
import XCTest
import MobileConsentsSDK

final class PublicAPICompatibilityTests: XCTestCase {
    func testExternalClientCanInitializeFacadeAndReferenceCallbackMethodsWithoutNetworking() throws {
        let fontSet = FontSet(
            largeTitle: .systemFont(ofSize: 34),
            body: .systemFont(ofSize: 14),
            bold: .boldSystemFont(ofSize: 14)
        )
        let labels = LabelText(title: "Privacy")
        let client = MobileConsents(
            clientID: "client-id",
            clientSecret: "client-secret",
            solutionId: "solution-id",
            fontSet: fontSet,
            localizationOverride: [Locale(identifier: "en"): labels]
        )

        let fetchConsentSolution: (@escaping MobileConsents.ConsentSolutionCompletion) -> Void = client.fetchConsentSolution
        let postConsent: (Consent, @escaping (Error?) -> Void) -> Void = client.postConsent
        let getUserID: () -> String = { client.userId }
        let getSavedConsents: () -> [UserConsent] = client.getSavedConsents
        let removeStoredConsents: () -> Void = client.removeStoredConsents
        let showPrivacyPopUp: (
            PrivacyPopupProtocol.Type?,
            UIViewController?,
            Bool,
            (([UserConsent]) -> Void)?,
            ((Error) -> Void)?
        ) -> Void = client.showPrivacyPopUp
        let showPrivacyPopUpIfNeeded: (
            PrivacyPopupProtocol.Type?,
            UIViewController?,
            Bool,
            Bool,
            (([UserConsent]) -> Void)?,
            ((Error) -> Void)?
        ) -> Void = client.showPrivacyPopUpIfNeeded

        let callShowPrivacyPopUpWithDefaults: () -> Void = {
            client.showPrivacyPopUp()
        }
        let callShowPrivacyPopUpIfNeededWithDefaults: () -> Void = {
            client.showPrivacyPopUpIfNeeded()
        }

        XCTAssertNotNil(fetchConsentSolution)
        XCTAssertNotNil(postConsent)
        XCTAssertNotNil(getUserID)
        XCTAssertNotNil(getSavedConsents)
        XCTAssertNotNil(removeStoredConsents)
        XCTAssertNotNil(showPrivacyPopUp)
        XCTAssertNotNil(showPrivacyPopUpIfNeeded)
        XCTAssertNotNil(callShowPrivacyPopUpWithDefaults)
        XCTAssertNotNil(callShowPrivacyPopUpIfNeededWithDefaults)

        // These are compile-only checks. Neither selector invokes networking or UI.
        _ = #selector(MobileConsents.showPrivacyPopUp(
            customViewType:onViewController:animated:completion:errorHandler:
        ))
        _ = #selector(MobileConsents.showPrivacyPopUpIfNeeded(
            customViewType:onViewController:animated:ignoreVersionChanges:completion:errorHandler:
        ))
        _ = #selector(getter: MobileConsents.userId)
        _ = #selector(MobileConsents.getSavedConsents)
        _ = #selector(MobileConsents.removeStoredConsents)
    }

    func testExternalClientCanSelectNetworkLoggingMode() {
        let client = MobileConsents(
            clientID: "client-id",
            clientSecret: "client-secret",
            solutionId: "solution-id",
            networkLoggingMode: .redactedRequestsAndResponses
        )

        XCTAssertNotNil(client)
        XCTAssertEqual(NetworkLoggingMode.disabled.rawValue, 0)
        XCTAssertEqual(NetworkLoggingMode.metadata.rawValue, 1)
        XCTAssertEqual(NetworkLoggingMode.redactedRequestsAndResponses.rawValue, 2)
        XCTAssertEqual(NetworkLoggingMode.fullRequests.rawValue, 3)
        XCTAssertEqual(NetworkLoggingMode.fullRequestsAndResponses.rawValue, 4)
    }

    func testExternalClientCanStillUseDeprecatedNetworkLoggerFlag() {
        let client = MobileConsents(
            clientID: "client-id",
            clientSecret: "client-secret",
            solutionId: "solution-id",
            enableNetworkLogger: true
        )

        XCTAssertNotNil(client)
    }

    @MainActor
    func testExternalClientCanReferenceAsyncMethods() {
        let client = MobileConsents(
            clientID: "client-id",
            clientSecret: "client-secret",
            solutionId: "solution-id"
        )

        let fetch: () async throws -> ConsentSolution = client.fetchConsentSolution
        let post: (Consent) async throws -> Void = client.postConsent
        let userID: () async throws -> String = client.getUserId
        let savedConsents: () async throws -> [UserConsent] = client.loadSavedConsents
        let clearStoredConsents: () async throws -> Void = client.clearStoredConsents
        let show: (
            PrivacyPopupProtocol.Type?,
            UIViewController?,
            Bool
        ) async throws -> [UserConsent] = client.showPrivacyPopUp
        let showIfNeeded: (
            PrivacyPopupProtocol.Type?,
            UIViewController?,
            Bool,
            Bool
        ) async throws -> [UserConsent] = client.showPrivacyPopUpIfNeeded
        let synchronize: () async -> Bool = client.synchronizeIfNeeded
        let callShowWithDefaults: () async throws -> [UserConsent] = {
            try await client.showPrivacyPopUp()
        }
        let callShowIfNeededWithDefaults: () async throws -> [UserConsent] = {
            try await client.showPrivacyPopUpIfNeeded()
        }

        _ = fetch
        _ = post
        _ = userID
        _ = savedConsents
        _ = clearStoredConsents
        _ = show
        _ = showIfNeeded
        _ = synchronize
        _ = callShowWithDefaults
        _ = callShowIfNeededWithDefaults
    }

    func testExternalClientSeesNSObjectReferenceTypes() throws {
        let labels = LabelText(title: "Privacy")
        let sameLabels = labels
        let fontSet = FontSet(
            largeTitle: .systemFont(ofSize: 34),
            body: .systemFont(ofSize: 14),
            bold: .boldSystemFont(ofSize: 14)
        )
        let sameFontSet = fontSet

        let _: NSObject = labels
        let _: NSObject = fontSet
        XCTAssertTrue(labels === sameLabels)
        XCTAssertTrue(fontSet === sameFontSet)
        let _: NSObject.Type = TemplateTexts.self

        let userConsentJSON = Data(
            """
            {
              "consentItem": {
                "universalConsentItemId": "external-consent",
                "required": false,
                "type": "functional",
                "translations": [
                  { "language": "EN", "shortText": "Consent", "longText": "Consent details" }
                ]
              },
              "isSelected": true
            }
            """.utf8
        )
        let userConsent = try JSONDecoder().decode(UserConsent.self, from: userConsentJSON)
        let sameUserConsent = userConsent

        let _: NSObject = userConsent
        XCTAssertTrue(userConsent === sameUserConsent)
    }

    func testExternalTranslationDoesNotRequireSendable() throws {
        let _: Translated<ExternalTranslation>.Type = Translated<ExternalTranslation>.self
        let _: ConsentTranslation.Type = ConsentTranslation.self
        let _: TemplateTranslation.Type = TemplateTranslation.self

        let original = ExternalTranslation(
            language: "EN",
            reference: ExternalTranslationReference(value: "reference")
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ExternalTranslation.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testExternalClientCanUsePublicEncodingSurface() throws {
        let _: Parameters.Type = Parameters.self
        let _: JSONParameterEncoder.Type = JSONParameterEncoder.self
        let _: URLParameterEncoder.Type = URLParameterEncoder.self
        let _: ParameterEncoding = .urlAndJsonEncoding
    }

    func testExternalClientCanUseNetworkProviderCompletion() {
        let callback: NetworkProviderCompletion = { data, response, error in
            XCTAssertNil(data)
            XCTAssertNil(response)
            XCTAssertNil(error)
        }

        callback(nil, nil, nil)
    }

    func testPublicTypesUsedByExamplesRemainAvailable() throws {
        let _: MobileConsents.Type = MobileConsents.self
        let _: Consent.Type = Consent.self
        let _: ConsentItem.Type = ConsentItem.self
        let _: ConsentSolution.Type = ConsentSolution.self
        let _: ProcessingPurpose.Type = ProcessingPurpose.self
        let _: SavedConsent.Type = SavedConsent.self
        let _: Any.Type = PrivacyPopupProtocol.self
        let _: PrivacyPopUpViewModel.Type = PrivacyPopUpViewModel.self
        let _: Any.Type = SwitchCellViewModel.self
        let _: Any.Type = Section.self
        let _: FontSet.Type = FontSet.self
        let _: LabelText.Type = LabelText.self
        let _: UserConsent.Type = UserConsent.self
        let _: TemplateTexts.Type = TemplateTexts.self

        XCTAssertEqual(FontSet.standard.body.pointSize, 14)
    }
}

private final class ExternalTranslationReference {
    let value: String

    init(value: String) {
        self.value = value
    }
}

private struct ExternalTranslation: Translation, Codable, Equatable {
    let language: String
    let reference: ExternalTranslationReference

    private enum CodingKeys: String, CodingKey {
        case language
        case reference
    }

    init(language: String, reference: ExternalTranslationReference) {
        self.language = language
        self.reference = reference
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        language = try container.decode(String.self, forKey: .language)
        reference = ExternalTranslationReference(
            value: try container.decode(String.self, forKey: .reference)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(language, forKey: .language)
        try container.encode(reference.value, forKey: .reference)
    }

    static func == (lhs: ExternalTranslation, rhs: ExternalTranslation) -> Bool {
        lhs.language == rhs.language && lhs.reference.value == rhs.reference.value
    }
}
