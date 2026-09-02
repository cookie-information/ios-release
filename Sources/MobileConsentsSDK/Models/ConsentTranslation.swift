public struct ConsentTranslation: Codable, Translation, Equatable, Sendable {
    public let language: String
    public let shortText: String
    public let longText: String
}
