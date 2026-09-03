import Foundation
@testable import MobileConsentsSDK

// Shared fixture builders and mocks for the test target, so model/initializer
// changes only need to be applied in one place.

func translated(_ text: String, primaryLanguage: String? = nil) -> Translated<TemplateTranslation> {
    Translated(
        translations: [TemplateTranslation(language: "EN", text: text)],
        primaryLanguage: primaryLanguage
    )
}

func userConsent(consentItemId: String, isSelected: Bool) -> UserConsent {
    UserConsent(
        consentItem: ConsentItem(
            id: consentItemId,
            required: false,
            type: .functional,
            translations: Translated(
                translations: [
                    ConsentTranslation(
                        language: "EN",
                        shortText: "Consent",
                        longText: "Consent details"
                    )
                ],
                primaryLanguage: nil
            )
        ),
        isSelected: isSelected
    )
}

func consentSolution(consentItemConfigs: [(Bool, ConsentItemType)]) -> ConsentSolution {
    let consentItems = consentItemConfigs.enumerated().map { index, config in
        ConsentItem(
            id: "\(index)",
            required: config.0,
            type: config.1,
            translations: Translated(
                translations: [
                    ConsentTranslation(language: "EN", shortText: "Consent short text", longText: "Consent long text")
                ],
                primaryLanguage: nil
            )
        )
    }

    return ConsentSolution(
        id: "1",
        versionId: "1",
        templateTexts: TemplateTexts(
            readMoreButton: translated("Read more button title"),
            rejectAllButton: translated("Reject all button title"),
            acceptAllButton: translated("Accept all button title"),
            acceptSelectedButton: translated("Accept selected button title"),
            savePreferencesButton: translated("Save preferences button title"),
            privacyCenterTitle: translated("Privacy center title"),
            privacyPreferencesTabLabel: translated("Privacy preferences tab"),
            poweredByCoiLabel: translated("Powered by Cookie Information"),
            consentPreferencesLabel: translated("Consent preferences label"),
            readMoreScreenHeader: nil,
            optionalTableSectionHeader: nil,
            requiredTableSectionHeader: nil
        ),
        consentItems: consentItems
    )
}

class ConsentItemProviderMock: ConsentItemProvider {
    var consentItemSelections = [String: Bool]()
    var requiredConsentItemIds = Set<String>()

    func isConsentItemSelected(id: String) -> Bool {
        consentItemSelections[id, default: false]
    }

    func isConsentItemRequired(id: String) -> Bool {
        requiredConsentItemIds.contains(id)
    }

    func markConsentItem(id: String, asSelected selected: Bool) {
        consentItemSelections[id] = selected
    }
}
