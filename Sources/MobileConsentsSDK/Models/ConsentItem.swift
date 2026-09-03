public enum ConsentItemType: String,  Codable, Equatable, Sendable {
    case functional
    case necessary
    case statistical
    case marketing
    case privacyPolicy = "privacy policy"
    case custom
    
    public var description: String {
        String(describing: self)
    }
}

public struct ConsentItem: Codable, Equatable, Sendable {
    public let id: String
    public let required: Bool
    public let type: ConsentItemType
    public let translations: Translated<ConsentTranslation>
    
    enum CodingKeys: String, CodingKey {
        case id = "universalConsentItemId"
        case translations
        case required
        case type
    }
}
