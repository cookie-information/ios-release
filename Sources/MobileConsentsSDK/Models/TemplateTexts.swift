import Foundation

public class TemplateTexts: NSObject, Decodable {
    public init(
        readMoreButton: Translated<TemplateTranslation>,
        rejectAllButton: Translated<TemplateTranslation>,
        acceptAllButton: Translated<TemplateTranslation>,
        acceptSelectedButton: Translated<TemplateTranslation>,
        savePreferencesButton: Translated<TemplateTranslation>,
        privacyCenterTitle: Translated<TemplateTranslation>,
        privacyPreferencesTabLabel: Translated<TemplateTranslation>,
        poweredByCoiLabel: Translated<TemplateTranslation>,
        consentPreferencesLabel: Translated<TemplateTranslation>,
        readMoreScreenHeader: Translated<TemplateTranslation>?,
        optionalTableSectionHeader: Translated<TemplateTranslation>?,
        requiredTableSectionHeader: Translated<TemplateTranslation>?
    ) {
        self.readMoreButton = readMoreButton
        self.rejectAllButton = rejectAllButton
        self.acceptAllButton = acceptAllButton
        self.acceptSelectedButton = acceptSelectedButton
        self.savePreferencesButton = savePreferencesButton
        self.privacyCenterTitle = privacyCenterTitle
        self.privacyPreferencesTabLabel = privacyPreferencesTabLabel
        self.poweredByCoiLabel = poweredByCoiLabel
        self.consentPreferencesLabel = consentPreferencesLabel
        self.requiredTableSectionHeader = requiredTableSectionHeader
        self.optionalTableSectionHeader = optionalTableSectionHeader
        self.readMoreScreenHeader = readMoreScreenHeader
    }
    
    public let readMoreButton: Translated<TemplateTranslation>
    public let rejectAllButton: Translated<TemplateTranslation>
    public let acceptAllButton: Translated<TemplateTranslation>
    public let acceptSelectedButton: Translated<TemplateTranslation>
    public let savePreferencesButton: Translated<TemplateTranslation>
    public let privacyCenterTitle: Translated<TemplateTranslation>
    public let privacyPreferencesTabLabel: Translated<TemplateTranslation>
    public let poweredByCoiLabel: Translated<TemplateTranslation>
    public let consentPreferencesLabel: Translated<TemplateTranslation>
    public let requiredTableSectionHeader: Translated<TemplateTranslation>?
    public let optionalTableSectionHeader: Translated<TemplateTranslation>?
    public let readMoreScreenHeader: Translated<TemplateTranslation>?
    
    public enum CodingKeys: String, CodingKey {
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
