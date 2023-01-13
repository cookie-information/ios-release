import Foundation

extension HTTPURLResponse {
    var result: NetworkResult<NetworkResponseError> {
        switch self.statusCode {
        case 200...299: return .success
        case 400...599: return .failure(.badRequest)
        case 600: return .failure(.outdated)
        default: return .failure(.failed)
        }
    }
}
