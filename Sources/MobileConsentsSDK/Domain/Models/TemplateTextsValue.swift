/// An immutable, concurrency-safe representation of template texts.
struct TemplateTextsValue: Codable, Equatable, Sendable {
    let readMoreButton: Translated<TemplateTranslation>
    let rejectAllButton: Translated<TemplateTranslation>
    let acceptAllButton: Translated<TemplateTranslation>
    let acceptSelectedButton: Translated<TemplateTranslation>
    let savePreferencesButton: Translated<TemplateTranslation>
    let privacyCenterTitle: Translated<TemplateTranslation>
    let privacyPreferencesTabLabel: Translated<TemplateTranslation>
    let poweredByCoiLabel: Translated<TemplateTranslation>
    let consentPreferencesLabel: Translated<TemplateTranslation>
    let requiredTableSectionHeader: Translated<TemplateTranslation>?
    let optionalTableSectionHeader: Translated<TemplateTranslation>?
    let readMoreScreenHeader: Translated<TemplateTranslation>?

    enum CodingKeys: String, CodingKey {
        case readMoreButton = "privacyCenterButton"
        case rejectAllButton,
             acceptAllButton,
             acceptSelectedButton,
             savePreferencesButton,
             privacyCenterTitle,
             privacyPreferencesTabLabel,
             poweredByCoiLabel,
             consentPreferencesLabel,
             requiredTableSectionHeader,
             optionalTableSectionHeader,
             readMoreScreenHeader
    }
}

extension TemplateTexts {
    /// Creates legacy template texts from a value snapshot.
    convenience init(_ value: TemplateTextsValue) {
        self.init(
            readMoreButton: value.readMoreButton,
            rejectAllButton: value.rejectAllButton,
            acceptAllButton: value.acceptAllButton,
            acceptSelectedButton: value.acceptSelectedButton,
            savePreferencesButton: value.savePreferencesButton,
            privacyCenterTitle: value.privacyCenterTitle,
            privacyPreferencesTabLabel: value.privacyPreferencesTabLabel,
            poweredByCoiLabel: value.poweredByCoiLabel,
            consentPreferencesLabel: value.consentPreferencesLabel,
            readMoreScreenHeader: value.readMoreScreenHeader,
            optionalTableSectionHeader: value.optionalTableSectionHeader,
            requiredTableSectionHeader: value.requiredTableSectionHeader
        )
    }

}
