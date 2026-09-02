import Foundation
import XCTest
@testable import MobileConsentsSDK

@MainActor
final class NetworkCoreExecutorTests: XCTestCase {
    func testAuthorizeDoesNotInheritMainActorAcrossTransportAndResume() async throws {
        let recorder = NetworkCoreExecutorRecorder()
        let mainDate = Date(timeIntervalSince1970: 1_000)
        let concurrentDate = Date(timeIntervalSince1970: 2_000)
        let response = HTTPResponseSnapshot(
            url: nil,
            statusCode: 200,
            body: Data(#"{"access_token":"token","expires_in":3600}"#.utf8)
        )
        let core = NetworkCore(
            transport: NetworkCoreExecutorTransport(recorder: recorder, response: response),
            primaryLanguage: "EN",
            now: {
                networkCoreExecutorIsMainThread() ? mainDate : concurrentDate
            }
        )

        let token = try await core.authorize(clientID: "client", clientSecret: "secret")

        let observed = await recorder.lastValue
        XCTAssertEqual(observed, false)
        XCTAssertEqual(token.expiresAt, concurrentDate.addingTimeInterval(3_600))
    }

    func testPostConsentDoesNotInheritMainActorAtTransportBoundary() async throws {
        let recorder = NetworkCoreExecutorRecorder()
        let response = HTTPResponseSnapshot(url: nil, statusCode: 204)
        let core = NetworkCore(
            transport: NetworkCoreExecutorTransport(recorder: recorder, response: response),
            primaryLanguage: "EN"
        )
        let submission = ConsentSubmissionValue(
            consentSolutionId: "solution",
            consentSolutionVersionId: "version",
            processingPurposes: [],
            customData: nil,
            userConsents: []
        )

        try await core.postConsent(
            submission,
            userID: "user",
            platformInformation: [:],
            token: AuthorizationTokenValue(accessToken: "token", expiresAt: .distantFuture)
        )

        let observed = await recorder.lastValue
        XCTAssertEqual(observed, false)
    }

    func testFetchConsentSolutionDoesNotInheritMainActorAtTransportBoundary() async throws {
        let recorder = NetworkCoreExecutorRecorder()
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(forResource: "ConsentSolution", withExtension: "json")
        )
        let response = HTTPResponseSnapshot(
            url: nil,
            statusCode: 200,
            body: try Data(contentsOf: fixtureURL)
        )
        let core = NetworkCore(
            transport: NetworkCoreExecutorTransport(recorder: recorder, response: response),
            primaryLanguage: "EN"
        )

        _ = try await core.fetchConsentSolution(solutionID: "solution")

        let observed = await recorder.lastValue
        XCTAssertEqual(observed, false)
    }
}

private actor NetworkCoreExecutorRecorder {
    private var values: [Bool] = []

    func record(_ value: Bool) {
        values.append(value)
    }

    var lastValue: Bool? {
        values.last
    }
}

private struct NetworkCoreExecutorTransport: HTTPTransport {
    let recorder: NetworkCoreExecutorRecorder
    let response: HTTPResponseSnapshot

    func start(
        snapshot _: HTTPRequestSnapshot,
        id _: HTTPRequestID
    ) async throws -> HTTPTransportOperation {
        let startsOnMainThread = networkCoreExecutorIsMainThread()
        await recorder.record(startsOnMainThread)
        let response = response
        return HTTPTransportOperation(
            task: Task<HTTPResponseSnapshot, Error>(
                name: "NetworkCoreExecutorTests.response"
            ) {
                response
            }
        )
    }
}

private func networkCoreExecutorIsMainThread() -> Bool {
    Thread.isMainThread
}
