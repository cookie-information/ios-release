public struct ConsentTranslation: Codable, Translation, Equatable {
    public let language: String
    public let shortText: String
    public let longText: String
}
