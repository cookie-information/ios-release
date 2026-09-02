import Foundation

/// Network endpoints used by a Mobile Consents backend environment.
enum NetworkEnvironment: Sendable {
    case production
    case staging

    /// Base URL used to fetch consent solutions.
    var consentSolutionBaseURL: URL {
        switch self {
        case .production:
            URL(string: "https://cdnapi.app.cookieinformation.com/v1/")!
        case .staging:
            URL(string: "https://cdnapi-staging.azureedge.net/v1/")!
        }
    }

    /// URL used to obtain an authorization token.
    var authorizationURL: URL {
        switch self {
        case .production:
            URL(string: "https://consent-api.app.cookieinformation.com/oauth2/token")!
        case .staging:
            URL(string: "https://consent-api-staging.app.cookieinformation.com/oauth2/token")!
        }
    }

    /// URL used to submit consent decisions.
    var consentSubmissionURL: URL {
        switch self {
        case .production:
            URL(string: "https://consent-api.app.cookieinformation.com/v1")!
        case .staging:
            URL(string: "https://consent-api-staging.app.cookieinformation.com/v1")!
        }
    }
}
