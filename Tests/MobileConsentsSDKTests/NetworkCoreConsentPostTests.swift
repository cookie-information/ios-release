import Foundation
import XCTest
@testable import MobileConsentsSDK

final class NetworkCoreConsentPostTests: XCTestCase {
    func testPostConsentBuildsExactRequestAndBodyWithoutUserConsents() async throws {
        let submission = makeSubmission(customData: ["custom-key": "custom-value"])
        let platformInformation = ["platform": "iOS"]
        let transport = ConsentPostHTTPTransportSpy(response: response(statusCode: 200))

        try await makeSUT(transport: transport).postConsent(
            submission,
            userID: "user-id",
            platformInformation: platformInformation,
            token: token()
        )

        let snapshots = await transport.recordedSnapshots()
        XCTAssertEqual(snapshots.count, 1)
        let snapshot = try XCTUnwrap(snapshots.first)
        XCTAssertEqual(
            snapshot,
            HTTPRequestSnapshot(
                url: URL(string: "https://consent-api.app.cookieinformation.com/v1")!,
                method: .post,
                headers: [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer access-token",
                ],
                body: snapshot.body,
                timeoutInterval: 10,
                cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
            )
        )

        let body = try XCTUnwrap(snapshot.body)
        let actualJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        var expectedJSON = Consent(submission).JSONRepresentation()
        expectedJSON["userId"] = "user-id"
        expectedJSON["platformInformation"] = platformInformation
        XCTAssertEqual(NSDictionary(dictionary: actualJSON), NSDictionary(dictionary: expectedJSON))
        XCTAssertNil(actualJSON["userConsents"])
    }

    func testPostConsentEncodesNilCustomDataAsEmptyArray() async throws {
        let transport = ConsentPostHTTPTransportSpy(response: response(statusCode: 200))

        try await makeSUT(transport: transport).postConsent(
            makeSubmission(customData: nil),
            userID: "user-id",
            platformInformation: [:],
            token: token()
        )

        let snapshots = await transport.recordedSnapshots()
        let snapshot = try XCTUnwrap(snapshots.first)
        let body = try XCTUnwrap(snapshot.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let customData = try XCTUnwrap(json["customData"] as? [Any])
        XCTAssertTrue(customData.isEmpty)
    }

    func testPostConsentAccepts299WithoutResponseBody() async throws {
        let transport = ConsentPostHTTPTransportSpy(response: response(statusCode: 299))

        try await makeSUT(transport: transport).postConsent(
            makeSubmission(),
            userID: "user-id",
            platformInformation: [:],
            token: token()
        )
    }

    func testPostConsentMaps300ToUnsuccessfulStatusCode() async {
        await assertFailure(statusCode: 300, body: nil, expected: .unsuccessfulStatusCode(300))
    }

    func testPostConsentDecodes400ServerError() async {
        let serverError = ConsentPostServerErrorValue(
            statusCode: 400,
            message: "Bad request",
            error: "invalid_consent"
        )
        await assertFailure(
            statusCode: 400,
            body: #"{"statusCode":400,"message":"Bad request","error":"invalid_consent"}"#,
            expected: .consentPostFailed(statusCode: 400, serverError: serverError)
        )
    }

    func testPostConsentMaps401WithMalformedBodyToErrorWithoutServerError() async {
        await assertFailure(
            statusCode: 401,
            body: "{not-json",
            expected: .consentPostFailed(statusCode: 401, serverError: nil)
        )
    }

    func testPostConsentMaps401WithEmptyBodyToErrorWithoutServerError() async {
        await assertFailure(
            statusCode: 401,
            body: nil,
            expected: .consentPostFailed(statusCode: 401, serverError: nil)
        )
    }

    func testPostConsentPreserves500ServerError() async {
        let serverError = ConsentPostServerErrorValue(
            statusCode: 500,
            message: "Server error",
            error: "internal_error"
        )
        await assertFailure(
            statusCode: 500,
            body: #"{"statusCode":500,"message":"Server error","error":"internal_error"}"#,
            expected: .consentPostFailed(statusCode: 500, serverError: serverError)
        )
    }

    func testPostConsentMaps600ToUnsuccessfulStatusCode() async {
        await assertFailure(statusCode: 600, body: nil, expected: .unsuccessfulStatusCode(600))
    }

    func testPostConsentPropagatesTransportErrorUnchanged() async {
        let transport = ConsentPostHTTPTransportSpy(error: .transportFailed)

        do {
            try await makeSUT(transport: transport).postConsent(
                makeSubmission(),
                userID: "user-id",
                platformInformation: [:],
                token: token()
            )
            XCTFail("Expected transport error")
        } catch let error as ConsentPostTransportError {
            XCTAssertEqual(error, .transportFailed)
        } catch {
            XCTFail("Expected transport error, got \(error)")
        }
    }

    private func makeSUT(transport: any HTTPTransport) -> NetworkCore {
        NetworkCore(transport: transport, primaryLanguage: "EN")
    }

    private func makeSubmission(customData: [String: String]? = [:]) -> ConsentSubmissionValue {
        ConsentSubmissionValue(
            consentSolutionId: "solution-id",
            consentSolutionVersionId: "solution-version-id",
            processingPurposes: [
                ProcessingPurpose(
                    consentItemId: "purpose-id",
                    consentGiven: true,
                    language: "en"
                ),
            ],
            customData: customData,
            userConsents: []
        )
    }

    private func token() -> AuthorizationTokenValue {
        AuthorizationTokenValue(accessToken: "access-token", expiresAt: .distantPast)
    }

    private func response(statusCode: Int, body: Data? = nil) -> HTTPResponseSnapshot {
        HTTPResponseSnapshot(url: nil, statusCode: statusCode, body: body)
    }

    private func assertFailure(
        statusCode: Int,
        body: String?,
        expected: NetworkCoreError
    ) async {
        let transport = ConsentPostHTTPTransportSpy(
            response: response(statusCode: statusCode, body: body.map { Data($0.utf8) })
        )

        do {
            try await makeSUT(transport: transport).postConsent(
                makeSubmission(),
                userID: "user-id",
                platformInformation: [:],
                token: token()
            )
            XCTFail("Expected \(expected)")
        } catch let error as NetworkCoreError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Expected \(expected), got \(error)")
        }
    }
}

private enum ConsentPostTransportError: Error, Equatable, Sendable {
    case transportFailed
}

private actor ConsentPostHTTPTransportSpy: HTTPTransport {
    private let result: Result<HTTPResponseSnapshot, ConsentPostTransportError>
    private var snapshots: [HTTPRequestSnapshot] = []

    init(response: HTTPResponseSnapshot) {
        result = .success(response)
    }

    init(error: ConsentPostTransportError) {
        result = .failure(error)
    }

    func start(
        snapshot: HTTPRequestSnapshot,
        id: HTTPRequestID
    ) async throws -> HTTPTransportOperation {
        snapshots.append(snapshot)
        let result = result
        let task = Task<HTTPResponseSnapshot, Error>(
            name: "NetworkCoreConsentPostTests.ConsentPostHTTPTransportSpy.operation"
        ) {
            try result.get()
        }
        return HTTPTransportOperation(task: task)
    }

    func recordedSnapshots() -> [HTTPRequestSnapshot] {
        snapshots
    }
}
