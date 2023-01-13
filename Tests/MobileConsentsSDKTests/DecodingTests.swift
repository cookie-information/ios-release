import XCTest

final class DecodingTests: XCTestCase {
    func testConsentSolutionIsCorrectlyDecoded() throws {
        let bundle = Bundle(for: Self.self)
        let data = try Data(contentsOf: bundle.url(forResource: "ConsentSolution", withExtension: "json")!)
        
        let decoder = JSONDecoder()
        decoder.userInfo[primaryLanguageCodingUserInfoKey] = primaryLanguage
        
        let consentSolution = try decoder.decode(ConsentSolution.self, from: data)
        
        XCTAssertEqual(consentSolution, expectedConsentSolution)
    }
}

private let primaryLanguage = "PL"

private let expectedConsentSolution = ConsentSolution(
    id: "9187d0f0-9e25-469b-9125-6a63b1b22b12",
    versionId: "00000000-0000-4000-8000-000000000000",
    title: Translated(
        translations: [
            TemplateTranslation(language: "EN", text: "Privacy title")
        ],
        primaryLanguage: primaryLanguage
    ),
    description: Translated(
        translations: [
            TemplateTranslation(language: "EN", text: "Privacy description")
        ],
        primaryLanguage: primaryLanguage
    ),
    templateTexts: TemplateTexts(
        readMoreButton: Translated(
            translations: [
                TemplateTranslation(language: "EN", text: "Privacy center button title")
            ],
            primaryLanguage: primaryLanguage
        ),
        rejectAllButton: Translated(
            translations: [
                TemplateTranslation(language: "EN", text: "Reject all button title")
            ],
            primaryLanguage: primaryLanguage
        ),
        acceptAllButton: Translated(
            translations: [
                TemplateTranslation(language: "EN", text: "Accept all button title")
            ],
            primaryLanguage: primaryLanguage
        ),
        acceptSelectedButton: Translated(
            translations: [
                TemplateTranslation(language: "EN", text: "Accept selected button title")
            ],
            primaryLanguage: primaryLanguage
        ),
        savePreferencesButton: Translated(
            translations: [
                TemplateTranslation(language: "EN", text: "Save preferences button title")
            ],
            primaryLanguage: primaryLanguage
        ),
        privacyCenterTitle: Translated(
            translations: [
                TemplateTranslation(language: "EN", text: "Privacy center title")
            ],
            primaryLanguage: primaryLanguage
        ),
        privacyPreferencesTabLabel: Translated(
            translations: [
                TemplateTranslation(language: "EN", text: "Privacy preferences tab")
            ],
            primaryLanguage: primaryLanguage
        ),
        poweredByCoiLabel: Translated(
            translations: [
                TemplateTranslation(language: "EN", text: "Powered by Cookie Information")
            ],
            primaryLanguage: primaryLanguage
        ),
        consentPreferencesLabel: Translated(
            translations: [
                TemplateTranslation(language: "EN", text: "Consent preferences label")
            ],
            primaryLanguage: primaryLanguage
        )
    ),
    consentItems: [
        ConsentItem(
            id: "a10853b5-85b8-4541-a9ab-fd203176bdce",
            required: true,
            type: .setting,
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
            type: .setting,
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
            type: .info,
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
            type: .info,
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
)
