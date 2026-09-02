import Foundation

/// A Mobile Consents API endpoint represented as an immutable request value.
enum MobileConsentsEndpoint: Sendable {
    case consentSolution(solutionID: String)
    case authorization(body: Data)
    case consentSubmission(body: Data, accessToken: String)

    func request(in environment: NetworkEnvironment) -> HTTPRequestSnapshot {
        HTTPRequestSnapshot(
            url: url(in: environment),
            method: method,
            headers: headers,
            body: body,
            timeoutInterval: 10,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
        )
    }

    private func url(in environment: NetworkEnvironment) -> URL {
        switch self {
        case let .consentSolution(solutionID):
            environment.consentSolutionBaseURL
                .appendingPathComponent(solutionID)
                .appendingPathComponent("consent-data.json")
        case .authorization:
            environment.authorizationURL
        case .consentSubmission:
            environment.consentSubmissionURL
        }
    }

    private var method: HTTPRequestMethod {
        switch self {
        case .consentSolution:
            .get
        case .authorization, .consentSubmission:
            .post
        }
    }

    private var headers: [String: String] {
        var headers = ["Content-Type": "application/json"]
        if case let .consentSubmission(_, accessToken) = self {
            headers["Authorization"] = "Bearer \(accessToken)"
        }
        return headers
    }

    private var body: Data? {
        switch self {
        case .consentSolution:
            nil
        case let .authorization(body), let .consentSubmission(body, _):
            body
        }
    }
}
