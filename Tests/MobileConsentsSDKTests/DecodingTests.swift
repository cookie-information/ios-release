import XCTest
@testable import MobileConsentsSDK

final class DecodingTests: XCTestCase {
    func testConsentSolutionIsCorrectlyDecoded() throws {
        let data = try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: "ConsentSolution", withExtension: "json")))

        let decoder = JSONDecoder()
        decoder.userInfo[primaryLanguageCodingUserInfoKey] = primaryLanguage

        let consentSolution = try decoder.decode(ConsentSolution.self, from: data)

        XCTAssertEqual(consentSolution.id, "9187d0f0-9e25-469b-9125-6a63b1b22b12")
        XCTAssertEqual(consentSolution.versionId, "00000000-0000-4000-8000-000000000000")
        XCTAssertEqual(consentSolution.consentItems, expectedConsentItems)

        // TemplateTexts is a reference type without value equality, so compare field by field
        let templateTexts = consentSolution.templateTexts
        XCTAssertEqual(templateTexts.readMoreButton, translated("Privacy center button title"))
        XCTAssertEqual(templateTexts.rejectAllButton, translated("Reject all button title"))
        XCTAssertEqual(templateTexts.acceptAllButton, translated("Accept all button title"))
        XCTAssertEqual(templateTexts.acceptSelectedButton, translated("Accept selected button title"))
        XCTAssertEqual(templateTexts.savePreferencesButton, translated("Save preferences button title"))
        XCTAssertEqual(templateTexts.privacyCenterTitle, translated("Privacy center title"))
        XCTAssertEqual(templateTexts.privacyPreferencesTabLabel, translated("Privacy preferences tab"))
        XCTAssertEqual(templateTexts.poweredByCoiLabel, translated("Powered by Cookie Information"))
        XCTAssertEqual(templateTexts.consentPreferencesLabel, translated("Consent preferences label"))
        XCTAssertNil(templateTexts.readMoreScreenHeader)
        XCTAssertNil(templateTexts.optionalTableSectionHeader)
        XCTAssertNil(templateTexts.requiredTableSectionHeader)
    }
}

private let primaryLanguage = "PL"

// Convenience over the shared builder: everything decoded in this test file
// carries the "PL" primary language injected through the decoder's userInfo.
private func translated(_ text: String) -> Translated<TemplateTranslation> {
    translated(text, primaryLanguage: primaryLanguage)
}

private let expectedConsentItems = [
    ConsentItem(
        id: "a10853b5-85b8-4541-a9ab-fd203176bdce",
        required: true,
        type: .necessary,
        translations: Translated(
            translations: [
                ConsentTranslation(
                    language: "EN",
                    shortText: "First consent item short text",
                    longText: "First consent item long text"
                )
            ],
            primaryLanguage: primaryLanguage
        )
    ),
    ConsentItem(
        id: "ef7d8f35-fc1a-4369-ada2-c00cc0eecc4b",
        required: false,
        type: .functional,
        translations: Translated(
            translations: [
                ConsentTranslation(
                    language: "EN",
                    shortText: "Second consent item short text",
                    longText: "Second consent item long text"
                )
            ],
            primaryLanguage: primaryLanguage
        )
    ),
    ConsentItem(
        id: "7d477dbf-5f88-420f-8dfc-2506907ebe07",
        required: true,
        type: .privacyPolicy,
        translations: Translated(
            translations: [
                ConsentTranslation(
                    language: "EN",
                    shortText: "Third consent item short text",
                    longText: "Third consent item long text"
                )
            ],
            primaryLanguage: primaryLanguage
        )
    ),
    ConsentItem(
        id: "1d5920c7-c5d1-4c08-93cc-4238457d7a1f",
        required: true,
        type: .marketing,
        translations: Translated(
            translations: [
                ConsentTranslation(
                    language: "EN",
                    shortText: "Fourth consent item short text",
                    longText: "Fourth consent item long text"
                )
            ],
            primaryLanguage: primaryLanguage
        )
    )
]
