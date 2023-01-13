public struct ConsentSolution: Decodable, Equatable {
    internal init(id: String, versionId: String, templateTexts: TemplateTexts, consentItems: [ConsentItem]) {
        self.id = id
        self.versionId = versionId
        self.templateTexts = templateTexts
        self.consentItems = consentItems
    }
    
    public let id: String
    public let versionId: String
    public let templateTexts: TemplateTexts
    public let consentItems: [ConsentItem]
    
    var primaryLanguage: String {
        consentItems.first?.translations.primaryLanguage ?? "EN"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(String.self, forKey: .id)
        self.versionId = try container.decode(String.self, forKey: .versionId)
        self.templateTexts = try container.decode(TemplateTexts.self, forKey: .templateTexts)
        self.consentItems = try container.decode([ConsentItem].self, forKey: .consentItems)
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "universalConsentSolutionId"
        case versionId = "universalConsentSolutionVersionId"
        case title
        case description
        case templateTexts
        case consentItems = "universalConsentItems"
    }
}
