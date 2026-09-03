import Foundation
import XCTest
@testable import MobileConsentsSDK

final class NetworkCoreAuthorizationTests: XCTestCase {
    private let fixedNow = Date(timeIntervalSinceReferenceDate: 1_000)

    func testAuthorizeBuildsExactRequestAndReturnsValidToken() async throws {
        let transport = AuthorizationHTTPTransportSpy(
            response: .init(
                url: nil,
                statusCode: 200,
                body: Data(#"{"access_token":"token","expires_in":3600}"#.utf8)
            )
        )
        let sut = makeSUT(transport: transport)

        let token = try await sut.authorize(clientID: "client-id", clientSecret: "client-secret")

        let snapshots = await transport.recordedSnapshots()
        XCTAssertEqual(snapshots.count, 1)
        let snapshot = try XCTUnwrap(snapshots.first)
        XCTAssertEqual(
            snapshot,
            HTTPRequestSnapshot(
                url: URL(string: "https://consent-api.app.cookieinformation.com/oauth2/token")!,
                method: .post,
                headers: ["Content-Type": "application/json"],
                body: snapshot.body,
                timeoutInterval: 10,
                cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
            )
        )
        let body = try XCTUnwrap(snapshot.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(
            json,
            [
                "client_id": "client-id",
                "client_secret": "client-secret",
                "grant_type": "client_credentials",
            ]
        )
        XCTAssertEqual(token, AuthorizationTokenValue(accessToken: "token", expiresAt: fixedNow.addingTimeInterval(3600)))
    }

    func testAuthorizeMaps400ToAuthorizationFailedWithErrorDescription() async {
        await assertAuthorizationFailure(
            statusCode: 400,
            body: #"{"error":"invalid_client","error_description":"Bad credentials"}"#,
            expected: .authorizationFailed("Bad credentials")
        )
    }

    func testAuthorizeMaps401ToAuthorizationFailedWithErrorDescription() async {
        await assertAuthorizationFailure(
            statusCode: 401,
            body: #"{"error":"invalid_client","error_description":"Bad credentials"}"#,
            expected: .authorizationFailed("Bad credentials")
        )
    }

    func testAuthorizePreservesOAuthErrorWhenAccessTokenHasWrongType() async {
        await assertAuthorizationFailure(
            statusCode: 401,
            body: #"{"access_token":42,"expires_in":3600,"error":"invalid_client","error_description":"Bad credentials"}"#,
            expected: .authorizationFailed("Bad credentials")
        )
    }

    func testAuthorizeUsesOAuthErrorWhenErrorDescriptionIsAbsent() async {
        await assertAuthorizationFailure(
            statusCode: 403,
            body: #"{"error":"invalid_client"}"#,
            expected: .authorizationFailed("invalid_client")
        )
    }

    func testAuthorizeMapsServerErrorToUnsuccessfulStatusCode() async {
        await assertAuthorizationFailure(
            statusCode: 500,
            body: #"{"error":"server_error"}"#,
            expected: .unsuccessfulStatusCode(500)
        )
    }

    func testAuthorizeRejectsMissingBody() async {
        let transport = AuthorizationHTTPTransportSpy(
            response: .init(url: nil, statusCode: 200, body: nil)
        )

        await assertAuthorizationFailure(
            sut: makeSUT(transport: transport),
            expected: .missingBody
        )
    }

    func testAuthorizeRejectsMalformedSuccessfulJSON() async {
        await assertAuthorizationFailure(
            statusCode: 200,
            body: "{not-json",
            expected: .authorizationFailed(nil)
        )
    }

    func testAuthorizeRejectsEmptyAccessToken() async {
        await assertAuthorizationFailure(
            statusCode: 200,
            body: #"{"access_token":"","expires_in":3600}"#,
            expected: .authorizationFailed(nil)
        )
    }

    func testAuthorizeRejectsExpiredAccessToken() async {
        await assertAuthorizationFailure(
            statusCode: 200,
            body: #"{"access_token":"token","expires_in":0}"#,
            expected: .authorizationFailed(nil)
        )
    }

    func testAuthorizePropagatesTransportErrorUnchanged() async {
        let transport = AuthorizationHTTPTransportSpy(error: .transportFailed)
        let sut = makeSUT(transport: transport)

        do {
            _ = try await sut.authorize(clientID: "client-id", clientSecret: "client-secret")
            XCTFail("Expected transport error")
        } catch let error as AuthorizationTransportError {
            XCTAssertEqual(error, .transportFailed)
        } catch {
            XCTFail("Expected transport error, got \(error)")
        }
    }

    private func makeSUT(transport: any HTTPTransport) -> NetworkCore {
        let fixedNow = fixedNow
        return NetworkCore(transport: transport, primaryLanguage: "EN", now: { fixedNow })
    }

    private func assertAuthorizationFailure(
        statusCode: Int,
        body: String,
        expected: NetworkCoreError
    ) async {
        let transport = AuthorizationHTTPTransportSpy(
            response: .init(url: nil, statusCode: statusCode, body: Data(body.utf8))
        )
        await assertAuthorizationFailure(sut: makeSUT(transport: transport), expected: expected)
    }

    private func assertAuthorizationFailure(
        sut: NetworkCore,
        expected: NetworkCoreError
    ) async {
        do {
            _ = try await sut.authorize(clientID: "client-id", clientSecret: "client-secret")
            XCTFail("Expected \(expected)")
        } catch let error as NetworkCoreError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Expected \(expected), got \(error)")
        }
    }
}

private enum AuthorizationTransportError: Error, Equatable, Sendable {
    case transportFailed
}

private actor AuthorizationHTTPTransportSpy: HTTPTransport {
    private let result: Result<HTTPResponseSnapshot, AuthorizationTransportError>
    private var snapshots: [HTTPRequestSnapshot] = []

    init(response: HTTPResponseSnapshot) {
        result = .success(response)
    }

    init(error: AuthorizationTransportError) {
        result = .failure(error)
    }

    func start(
        snapshot: HTTPRequestSnapshot,
        id: HTTPRequestID
    ) async throws -> HTTPTransportOperation {
        snapshots.append(snapshot)
        let result = result
        let task = Task<HTTPResponseSnapshot, Error>(
            name: "NetworkCoreAuthorizationTests.AuthorizationHTTPTransportSpy.operation"
        ) {
            try result.get()
        }
        return HTTPTransportOperation(task: task)
    }

    func recordedSnapshots() -> [HTTPRequestSnapshot] {
        snapshots
    }
}
