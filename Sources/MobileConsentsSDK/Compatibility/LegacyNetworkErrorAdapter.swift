import Foundation

enum LegacyNetworkErrorAdapter {
    static func adapt(_ error: Error) -> Error {
        if let error = error as? NetworkCoreError {
            switch error {
            case let .authorizationFailed(message):
                return NetworkResponseError.invalidClientCredentials(message)
            case .missingBody:
                return NetworkResponseError.noData
            case let .unsuccessfulStatusCode(statusCode):
                switch statusCode {
                case 400...599:
                    return NetworkResponseError.badRequest
                case 600:
                    return NetworkResponseError.outdated
                default:
                    return NetworkResponseError.failed
                }
            case let .consentPostFailed(_, serverError: serverError?):
                return APIError(
                    statusCode: serverError.statusCode,
                    message: serverError.message,
                    error: serverError.error
                )
            case .consentPostFailed:
                return NetworkResponseError.badRequest
            }
        }

        if let error = error as? HTTPTransportError {
            switch error {
            case .nonHTTPResponse:
                return NetworkResponseError.noProperResponse
            case .cancelled:
                return URLError(.cancelled)
            case .duplicateRequestID:
                return NetworkResponseError.failed
            }
        }

        if error is CancellationError {
            return URLError(.cancelled)
        }

        return error
    }
}
