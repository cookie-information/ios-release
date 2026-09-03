import Foundation

enum NetworkResponseError: LocalizedError {
    case badRequest
    case outdated
    case failed
    case noData
    case noProperResponse
    case invalidClientCredentials(String?)

    var errorDescription: String? {
        switch self {
        case .badRequest: return "Bad request"
        case .outdated: return "The url you requested is outdated."
        case .failed: return "Network request failed."
        case .noData: return "Response returned with no data to decode."
        case .noProperResponse: return "No proper response."
        case .invalidClientCredentials(let serverMessage):
            let details = serverMessage.map { " (\($0))" } ?? ""
            return "Authorization failed — check that the clientID and clientSecret configured in MobileConsentsSDK are correct\(details)."
        }
    }
}
