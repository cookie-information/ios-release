import Foundation

final class MobileConsentsMock: MobileConsentsProtocol {
    func fetchConsentSolution(completion: @escaping (Result<ConsentSolution, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(.success(mockConsentSolution))
        }
    }
    
    func postConsent(_ consent: Consent, completion: @escaping (Error?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(nil)
        }
    }
    
    func getSavedConsents() -> [UserConsent] {
        []
    }
}

private let languageCode = "EN"

private let mockConsentSolution = ConsentSolution(
    id: "9187d0f0-9e25-469b-9125-6a63b1b22b12",
    versionId: "00000000-0000-4000-8000-000000000000",
    templateTexts: TemplateTexts(
        readMoreButton: Translated(
            translations: [
                TemplateTranslation(language: "EN", text: "Privacy center button title")
            ],
            primaryLanguage: languageCode
        ),
        rejectAllButton: Translated(
            translations: [
                TemplateTranslation(language: "EN", text: "Reject all button title")
            ],
            primaryLanguage: languageCode
        ),
        acceptAllButton: Translated(
            translations: [
                TemplateTranslation(language: "EN", text: "Accept all button title")
            ],
            primaryLanguage: languageCode
        ),
        acceptSelectedButton: Translated(
            translations: [
                TemplateTranslation(language: "EN", text: "Accept selected button title")
            ],
            primaryLanguage: languageCode
        ),
        savePreferencesButton: Translated(
            translations: [
                TemplateTranslation(language: "EN", text: "Accept")
            ],
            primaryLanguage: languageCode
        ),
        privacyCenterTitle: Translated(
            translations: [
                TemplateTranslation(language: "EN", text: "Privacy center title")
            ],
            primaryLanguage: languageCode
        ),
        privacyPreferencesTabLabel: Translated(
            translations: [
                TemplateTranslation(language: "EN", text: "Privacy preferences tab")
            ],
            primaryLanguage: languageCode
        ),
        poweredByCoiLabel: Translated(
            translations: [
                TemplateTranslation(language: "EN", text: "Powered by Cookie Information")
            ],
            primaryLanguage: languageCode
        ),
        consentPreferencesLabel: Translated(
            translations: [
                TemplateTranslation(language: "EN", text: "Consent preferences label")
            ],
            primaryLanguage: languageCode
        )
    ),
    consentItems: [
        ConsentItem(
            id: "a10853b5-85b8-4541-a9ab-fd203176bdce",
            required: true,
            type: .necessary,
            translations: Translated(
                translations: [
                    ConsentTranslation(
                        language: "EN",
                        shortText: "First consent item short text 1",
                        longText: "First consent item long text"
                    )
                ],
                primaryLanguage: languageCode
            )
        ),
        ConsentItem(
            id: "ef7d8f35-fc1a-4369-ada2-c00cc0eecc4b1",
            required: false,
            type: .functional,
            translations: Translated(
                translations: [
                    ConsentTranslation(
                        language: "EN",
                        shortText: """
                        Example html capabilities<br>
                        Lists:<br>
                        <ul>
                        <li><b>Bold text</b></li>
                        <li><em>Emphasized text</em></li>
                        <li><b><i>Bold and emphasized text</i></b></li>
                        <li><a href=\"https://apple.com\">Link to website</a></li>
                        <li><span style=\"color:red\">Text with custom color</span></li>
                        </ul>
                        """,
                        longText: """
                        Example html capabilities<br>
                        Lists:<br>
                        <ul>
                        <li><b>Bold text</b></li>
                        <li><em>Emphasized text</em></li>
                        <li><b><i>Bold and emphasized text</i></b></li>
                        <li><a href=\"https://apple.com\">Link to website</a></li>
                        <li><span style=\"color:red\">Text with custom color</span></li>
                        </ul>
                        """
                    )
                ],
                primaryLanguage: languageCode
            )
        ),
        ConsentItem(
            id: "ef7d8f35-fc1a-4369-ada2-c00cc0eecc4b2",
            required: false,
            type: .necessary,
            translations: Translated(
                translations: [
                    ConsentTranslation(
                        language: "EN",
                        shortText: """
                        Example html capabilities<br>
                        Lists:<br>
                        <ul>
                        <li><b>Bold text</b></li>
                        <li><em>Emphasized text</em></li>
                        <li><b><i>Bold and emphasized text</i></b></li>
                        <li><a href=\"https://apple.com\">Link to website</a></li>
                        <li><span style=\"color:red\">Text with custom color</span></li>
                        </ul>
                        """,
                        longText: """
                        Example html capabilities<br>
                        Lists:<br>
                        <ul>
                        <li><b>Bold text</b></li>
                        <li><em>Emphasized text</em></li>
                        <li><b><i>Bold and emphasized text</i></b></li>
                        <li><a href=\"https://apple.com\">Link to website</a></li>
                        <li><span style=\"color:red\">Text with custom color</span></li>
                        </ul>
                        """
                    )
                ],
                primaryLanguage: languageCode
            )
        ),
        ConsentItem(
            id: "ef7d8f35-fc1a-4369-ada2-c00cc0eecc4b3",
            required: false,
            type: .functional,
            translations: Translated(
                translations: [
                    ConsentTranslation(
                        language: "EN",
                        shortText: """
                        Example html capabilities<br>
                        Lists:<br>
                        <ul>
                        <li><b>Bold text</b></li>
                        <li><em>Emphasized text</em></li>
                        <li><b><i>Bold and emphasized text</i></b></li>
                        <li><a href=\"https://apple.com\">Link to website</a></li>
                        <li><span style=\"color:red\">Text with custom color</span></li>
                        </ul>
                        """,
                        longText: """
                        Example html capabilities<br>
                        Lists:<br>
                        <ul>
                        <li><b>Bold text</b></li>
                        <li><em>Emphasized text</em></li>
                        <li><b><i>Bold and emphasized text</i></b></li>
                        <li><a href=\"https://apple.com\">Link to website</a></li>
                        <li><span style=\"color:red\">Text with custom color</span></li>
                        </ul>
                        """
                    )
                ],
                primaryLanguage: languageCode
            )
        ),
        ConsentItem(
            id: "ef7d8f35-fc1a-4369-ada2-c00cc0eecc4b4",
            required: false,
            type: .marketing,
            translations: Translated(
                translations: [
                    ConsentTranslation(
                        language: "EN",
                        shortText: """
                        Example html capabilities<br>
                        Lists:<br>
                        <ul>
                        <li><b>Bold text</b></li>
                        <li><em>Emphasized text</em></li>
                        <li><b><i>Bold and emphasized text</i></b></li>
                        <li><a href=\"https://apple.com\">Link to website</a></li>
                        <li><span style=\"color:red\">Text with custom color</span></li>
                        </ul>
                        """,
                        longText: """
                        Example html capabilities<br>
                        Lists:<br>
                        <ul>
                        <li><b>Bold text</b></li>
                        <li><em>Emphasized text</em></li>
                        <li><b><i>Bold and emphasized text</i></b></li>
                        <li><a href=\"https://apple.com\">Link to website</a></li>
                        <li><span style=\"color:red\">Text with custom color</span></li>
                        </ul>
                        """
                    )
                ],
                primaryLanguage: languageCode
            )
        ),
        ConsentItem(
            id: "a10853b5-85b8-4541-a9ab-fd203176bdce7",
            required: true,
            type: .statistical,
            translations: Translated(
                translations: [
                    ConsentTranslation(
                        language: "EN",
                        shortText: "Consent item short text 5",
                        longText: "First consent item long text"
                    )
                ],
                primaryLanguage: languageCode
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
                        longText: """
                        Example html capabilities<br>
                        Lists:<br>
                        <ul>
                        <li><b>Bold text</b></li>
                        <li><em>Emphasized text</em></li>
                        <li><b><i>Bold and emphasized text</i></b></li>
                        <li><a href=\"https://apple.com\">Link to website</a></li>
                        <li><span style=\"color:red\">Text with custom color</span></li>
                        </ul>
                        """
                    )
                ],
                primaryLanguage: languageCode
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
                        longText: """
                        Example html capabilities<br>
                        Lists:<br>
                        <ul>
                        <li><b>Bold text</b></li>
                        <li><em>Emphasized text</em></li>
                        <li><b><i>Bold and emphasized text</i></b></li>
                        <li><a href=\"https://apple.com\">Link to website</a></li>
                        <li><span style=\"color:red\">Text with custom color</span></li>
                        </ul>
                        """
                    )
                ],
                primaryLanguage: languageCode
            )
        ),
        ConsentItem(
            id: "1d5920c7-c5d1-4c08-93cc-4238457d7a1f",
            required: true,
            type: .privacyPolicy,
            translations: Translated(
                translations: [
                    ConsentTranslation(
                        language: "EN",
                        shortText: "Fourth consent item short text",
                        longText: "Fourth consent item long text"
                    )
                ],
                primaryLanguage: languageCode
            )
        )
    ]
)
