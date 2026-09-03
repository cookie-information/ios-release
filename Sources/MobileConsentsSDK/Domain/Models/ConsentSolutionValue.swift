/// An immutable, concurrency-safe representation of a consent solution.
struct ConsentSolutionValue: Codable, Equatable, Sendable {
    let id: String
    let versionId: String
    let templateTexts: TemplateTextsValue
    let consentItems: [ConsentItem]

    enum CodingKeys: String, CodingKey {
        case id = "universalConsentSolutionId"
        case versionId = "universalConsentSolutionVersionId"
        case templateTexts
        case consentItems = "universalConsentItems"
    }
}

extension ConsentSolutionValue {
    /// Decodes the stored consent-solution fields using the legacy backend keys.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            id: try container.decode(String.self, forKey: .id),
            versionId: try container.decode(String.self, forKey: .versionId),
            templateTexts: try container.decode(TemplateTextsValue.self, forKey: .templateTexts),
            consentItems: try container.decode([ConsentItem].self, forKey: .consentItems)
        )
    }
}

extension ConsentSolution {
    /// Creates a legacy consent solution from a value snapshot.
    init(_ value: ConsentSolutionValue) {
        self.init(
            id: value.id,
            versionId: value.versionId,
            templateTexts: TemplateTexts(value.templateTexts),
            consentItems: value.consentItems
        )
    }
}
