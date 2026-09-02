import Foundation

enum NetworkCoreError: Error, Equatable, Sendable {
    case unsuccessfulStatusCode(Int)
    case missingBody
    case authorizationFailed(String?)
    case consentPostFailed(statusCode: Int, serverError: ConsentPostServerErrorValue?)
}

struct NetworkCore: Sendable {
    private let transport: any HTTPTransport
    private let environment: NetworkEnvironment
    private let primaryLanguage: String
    private let now: @Sendable () -> Date

    init(
        transport: any HTTPTransport,
        primaryLanguage: String,
        environment: NetworkEnvironment = .production,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.transport = transport
        self.environment = environment
        self.primaryLanguage = primaryLanguage
        self.now = now
    }

    @concurrent
    func authorize(
        clientID: String,
        clientSecret: String
    ) async throws -> AuthorizationTokenValue {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try encoder.encode(
            AuthorizationRequest(clientID: clientID, clientSecret: clientSecret)
        )
        let snapshot = MobileConsentsEndpoint
            .authorization(body: body)
            .request(in: environment)
        let operation = try await transport.start(
            snapshot: snapshot,
            id: HTTPRequestID()
        )
        let response = try await operation.value

        guard let body = response.body else {
            throw NetworkCoreError.missingBody
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let authorizationResponse = try? decoder.decode(
            AuthorizationResponse.self,
            from: body
        )

        guard (200..<300).contains(response.statusCode) else {
            switch response.statusCode {
            case 400, 401, 403:
                throw NetworkCoreError.authorizationFailed(
                    authorizationResponse?.errorDescription ?? authorizationResponse?.error
                )
            default:
                throw NetworkCoreError.unsuccessfulStatusCode(response.statusCode)
            }
        }

        guard let authorizationResponse else {
            throw NetworkCoreError.authorizationFailed(nil)
        }

        let currentDate = now()
        let expiresAt = currentDate.addingTimeInterval(authorizationResponse.expiresIn)
        let token = AuthorizationTokenValue(
            accessToken: authorizationResponse.accessToken ?? "",
            expiresAt: expiresAt
        )
        guard authorizationResponse.error == nil, token.isValid(at: currentDate) else {
            throw NetworkCoreError.authorizationFailed(
                authorizationResponse.errorDescription ?? authorizationResponse.error
            )
        }
        return token
    }

    @concurrent
    func postConsent(
        _ submission: ConsentSubmissionValue,
        userID: String,
        platformInformation: [String: String],
        token: AuthorizationTokenValue
    ) async throws {
        let body = try JSONEncoder().encode(
            ConsentPostRequest(
                submission: submission,
                userID: userID,
                platformInformation: platformInformation
            )
        )
        let snapshot = MobileConsentsEndpoint
            .consentSubmission(body: body, accessToken: token.accessToken)
            .request(in: environment)
        let operation = try await transport.start(
            snapshot: snapshot,
            id: HTTPRequestID()
        )
        let response = try await operation.value

        guard !(200..<300).contains(response.statusCode) else {
            return
        }
        guard (400...599).contains(response.statusCode) else {
            throw NetworkCoreError.unsuccessfulStatusCode(response.statusCode)
        }

        let serverError = response.body.flatMap {
            try? JSONDecoder().decode(ConsentPostServerErrorValue.self, from: $0)
        }
        throw NetworkCoreError.consentPostFailed(
            statusCode: response.statusCode,
            serverError: serverError
        )
    }

    @concurrent
    func fetchConsentSolution(
        solutionID: String
    ) async throws -> ConsentSolutionValue {
        let snapshot = MobileConsentsEndpoint
            .consentSolution(solutionID: solutionID)
            .request(in: environment)
        let operation = try await transport.start(
            snapshot: snapshot,
            id: HTTPRequestID()
        )
        let response = try await operation.value

        guard (200..<300).contains(response.statusCode) else {
            throw NetworkCoreError.unsuccessfulStatusCode(response.statusCode)
        }
        guard let body = response.body else {
            throw NetworkCoreError.missingBody
        }

        let decoder = JSONDecoder()
        decoder.userInfo[primaryLanguageCodingUserInfoKey] = primaryLanguage
        return try decoder.decode(ConsentSolutionValue.self, from: body)
    }
}

private struct AuthorizationRequest: Encodable {
    let clientID: String
    let clientSecret: String
    let grantType = "client_credentials"
}

private struct AuthorizationResponse: Decodable {
    let accessToken: String?
    let expiresIn: TimeInterval
    let errorDescription: String?
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case accessToken
        case expiresIn
        case errorDescription
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try? container.decode(String?.self, forKey: .accessToken)
        expiresIn = (try? container.decode(TimeInterval.self, forKey: .expiresIn)) ?? -1
        errorDescription = try? container.decode(String?.self, forKey: .errorDescription)
        error = try? container.decode(String?.self, forKey: .error)
    }
}

private struct ConsentPostRequest: Encodable {
    let universalConsentSolutionId: String
    let universalConsentSolutionVersionId: String
    let customData: [ConsentPostCustomData]
    let processingPurposes: [ProcessingPurpose]
    let userId: String
    let platformInformation: [String: String]

    init(
        submission: ConsentSubmissionValue,
        userID: String,
        platformInformation: [String: String]
    ) {
        universalConsentSolutionId = submission.consentSolutionId
        universalConsentSolutionVersionId = submission.consentSolutionVersionId
        customData = (submission.customData ?? [:]).map {
            ConsentPostCustomData(fieldName: $0.key, fieldValue: $0.value)
        }
        processingPurposes = submission.processingPurposes
        userId = userID
        self.platformInformation = platformInformation
    }
}

private struct ConsentPostCustomData: Encodable {
    let fieldName: String
    let fieldValue: String
}
