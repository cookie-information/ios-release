struct ConsentPostServerErrorValue: Decodable, Equatable, Sendable {
    let statusCode: Int
    let message: String
    let error: String
}
