import Foundation
@testable import MobileConsentsSDK
import XCTest

final class DomainValueCompatibilityTests: XCTestCase {
    func testValueModelsHaveSendableContracts() {
        requireSendable(UserConsentValue.self)
        requireSendable(TemplateTextsValue.self)
        requireSendable(ConsentSolutionValue.self)
        requireSendable(ConsentSubmissionValue.self)
    }

    func testConsentSolutionDecodesThroughBothGraphsAndBuildsLegacyModel() throws {
        let data = try fixtureData()
        let decoder = JSONDecoder()
        decoder.userInfo[primaryLanguageCodingUserInfoKey] = "PL"

        let legacy = try decoder.decode(ConsentSolution.self, from: data)
        let value = try decoder.decode(ConsentSolutionValue.self, from: data)

        XCTAssertEqual(value.id, legacy.id)
        XCTAssertEqual(value.versionId, legacy.versionId)
        XCTAssertEqual(value.consentItems, legacy.consentItems)

        let legacyTexts = legacy.templateTexts
        let valueTexts = value.templateTexts
        XCTAssertEqual(valueTexts.readMoreButton, legacyTexts.readMoreButton)
        XCTAssertEqual(valueTexts.rejectAllButton, legacyTexts.rejectAllButton)
        XCTAssertEqual(valueTexts.acceptAllButton, legacyTexts.acceptAllButton)
        XCTAssertEqual(valueTexts.acceptSelectedButton, legacyTexts.acceptSelectedButton)
        XCTAssertEqual(valueTexts.savePreferencesButton, legacyTexts.savePreferencesButton)
        XCTAssertEqual(valueTexts.privacyCenterTitle, legacyTexts.privacyCenterTitle)
        XCTAssertEqual(valueTexts.privacyPreferencesTabLabel, legacyTexts.privacyPreferencesTabLabel)
        XCTAssertEqual(valueTexts.poweredByCoiLabel, legacyTexts.poweredByCoiLabel)
        XCTAssertEqual(valueTexts.consentPreferencesLabel, legacyTexts.consentPreferencesLabel)
        XCTAssertEqual(valueTexts.requiredTableSectionHeader, legacyTexts.requiredTableSectionHeader)
        XCTAssertEqual(valueTexts.optionalTableSectionHeader, legacyTexts.optionalTableSectionHeader)
        XCTAssertEqual(valueTexts.readMoreScreenHeader, legacyTexts.readMoreScreenHeader)

        let restoredLegacy = ConsentSolution(value)

        XCTAssertEqual(restoredLegacy.id, legacy.id)
        XCTAssertEqual(restoredLegacy.versionId, legacy.versionId)
        XCTAssertEqual(restoredLegacy.consentItems, legacy.consentItems)
        XCTAssertEqual(restoredLegacy.templateTexts.readMoreButton, value.templateTexts.readMoreButton)
    }

    func testUserConsentValuePreservesLegacyCodableWireFormat() throws {
        let consentItem = ConsentItem(
            id: "item-id",
            required: false,
            type: .marketing,
            translations: Translated(
                translations: [
                    ConsentTranslation(
                        language: "EN",
                        shortText: "Marketing",
                        longText: "Marketing details"
                    )
                ],
                primaryLanguage: "EN"
            )
        )
        let legacy = UserConsent(consentItem: consentItem, isSelected: true)
        let value = UserConsentValue(legacy)

        let legacyData = try JSONEncoder().encode(legacy)
        let valueData = try JSONEncoder().encode(value)
        let legacyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: legacyData) as? NSDictionary)
        let valueObject = try XCTUnwrap(JSONSerialization.jsonObject(with: valueData) as? NSDictionary)

        XCTAssertTrue(legacyObject.isEqual(valueObject))

        let valueDecodedFromLegacyData = try JSONDecoder().decode(UserConsentValue.self, from: legacyData)
        let legacyDecodedFromValueData = try JSONDecoder().decode(UserConsent.self, from: valueData)

        XCTAssertEqual(valueDecodedFromLegacyData, value)
        XCTAssertEqual(legacyDecodedFromValueData.consentItem, legacy.consentItem)
        XCTAssertEqual(legacyDecodedFromValueData.isSelected, legacy.isSelected)
        XCTAssertEqual(UserConsentValue(legacyDecodedFromValueData), value)
    }

    func testConsentSubmissionValuePreservesCurrentConsentStateAndRoundTrips() {
        let privacyPolicy = makeConsentItem(id: "privacy-policy", type: .privacyPolicy)
        let functional = makeConsentItem(id: "functional", type: .functional)
        let consentSolutionId = "solution-id"
        let consentSolutionVersionId = "solution-version-id"

        var consent = Consent(
            consentSolutionId: consentSolutionId,
            consentSolutionVersionId: consentSolutionVersionId,
            customData: nil,
            userConsents: [
                UserConsent(consentItem: privacyPolicy, isSelected: true),
                UserConsent(consentItem: functional, isSelected: false)
            ]
        )
        consent.addProcessingPurpose(
            ProcessingPurpose(consentItemId: "added-purpose", consentGiven: true, language: "da")
        )

        XCTAssertEqual(consent.userConsents.map { $0.consentItem.id }, ["functional"])
        XCTAssertEqual(consent.processingPurposes.map(\.consentItemId), ["functional", "added-purpose"])

        let snapshot = ConsentSubmissionValue(consent)
        XCTAssertEqual(snapshot, consent.submissionValue)
        XCTAssertEqual(snapshot.consentSolutionId, consentSolutionId)
        XCTAssertEqual(snapshot.consentSolutionVersionId, consentSolutionVersionId)
        XCTAssertNil(snapshot.customData)
        XCTAssertEqual(snapshot.userConsents.map { $0.consentItem.id }, ["functional"])
        XCTAssertEqual(snapshot.userConsents.map(\.isSelected), [false])
        assertProcessingPurposesEqual(snapshot.processingPurposes, consent.processingPurposes)

        let roundTripped = Consent(snapshot)
        XCTAssertEqual(roundTripped.consentSolutionId, consentSolutionId)
        XCTAssertEqual(roundTripped.consentSolutionVersionId, consentSolutionVersionId)
        XCTAssertNil(roundTripped.customData)
        XCTAssertEqual(roundTripped.userConsents.map { $0.consentItem.id }, ["functional"])
        assertProcessingPurposesEqual(roundTripped.processingPurposes, consent.processingPurposes)
        XCTAssertEqual(ConsentSubmissionValue(roundTripped), snapshot)

        let emptyCustomDataConsent = Consent(
            consentSolutionId: consentSolutionId,
            consentSolutionVersionId: consentSolutionVersionId,
            customData: [:],
            userConsents: []
        )
        let emptyCustomDataSnapshot = ConsentSubmissionValue(emptyCustomDataConsent)
        XCTAssertEqual(emptyCustomDataSnapshot.customData, [:])
        XCTAssertEqual(Consent(emptyCustomDataSnapshot).customData, [:])
    }

    private func requireSendable<T: Sendable>(_: T.Type) {}

    private func fixtureData() throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "ConsentSolution", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func makeConsentItem(id: String, type: ConsentItemType) -> ConsentItem {
        ConsentItem(
            id: id,
            required: type == .privacyPolicy,
            type: type,
            translations: Translated(
                translations: [
                    ConsentTranslation(
                        language: "EN",
                        shortText: id,
                        longText: id + " details"
                    )
                ],
                primaryLanguage: "EN"
            )
        )
    }

    private func assertProcessingPurposesEqual(
        _ lhs: [ProcessingPurpose],
        _ rhs: [ProcessingPurpose],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(lhs.count, rhs.count, file: file, line: line)
        for (lhsPurpose, rhsPurpose) in zip(lhs, rhs) {
            XCTAssertEqual(lhsPurpose.consentItemId, rhsPurpose.consentItemId, file: file, line: line)
            XCTAssertEqual(lhsPurpose.consentGiven, rhsPurpose.consentGiven, file: file, line: line)
            XCTAssertEqual(lhsPurpose.language, rhsPurpose.language, file: file, line: line)
        }
    }
}
