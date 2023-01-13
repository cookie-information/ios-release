public protocol Translation {
    var language: String { get }
}

let primaryLanguageCodingUserInfoKey = CodingUserInfoKey(rawValue: "primaryLanguage")!

public struct Translated<T: Translation & Codable & Equatable>: Codable, Equatable {
    public let translations: [T]

    let primaryLanguage: String
    
    init(translations: [T], primaryLanguage: String?) {
        self.translations = translations
        self.primaryLanguage = primaryLanguage ?? "EN"
    }
    
    public init(from decoder: Decoder) throws {
        self.translations = try [T](from: decoder)
        self.primaryLanguage = decoder.userInfo[primaryLanguageCodingUserInfoKey] as? String ?? "EN"
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.translations)
    }
    
    public func translation(with languageCode: String) -> T? {
        translations.first { $0.language.uppercased() == languageCode.uppercased() }
        
    }
    
    public func primaryTranslation() -> T {
        translation(with: primaryLanguage) ?? translations.first!
    }
}
