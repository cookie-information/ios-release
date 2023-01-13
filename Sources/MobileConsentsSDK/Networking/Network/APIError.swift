import Foundation

struct APIError: LocalizedError, Decodable {
    let statusCode: Int
    let message: String
    let error: String
    
    var errorDescription: String? {
        "\(error): \(message)"
    }
}
