import XCTest
@testable import MobileConsentsSDK

final class NetworkManagerTests: XCTestCase {
    private var session: URLSession!
    private var sut: NetworkManager!

    override func setUp() {
        super.setUp()

        MockURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: configuration)

        sut = NetworkManager(
            jsonDecoder: JSONDecoder(),
            localStorageManager: LocalStorageManager(userDefaults: testUserDefaults),
            platformInformationGenerator: StubPlatformInformationGenerator(),
            clientID: "client-id",
            clientSecret: "client-secret",
            solutionID: "solution-id",
            urlSession: session
        )
    }

    override func tearDown() {
        sut = nil
        session = nil
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testPostConsent_whenCredentialsAreInvalid_completesOnceWithInvalidClientCredentials() {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = Data(#"{"error":"invalid_client","error_description":"Bad credentials"}"#.utf8)
            return (response, data)
        }

        let expectation = expectation(description: "postConsent completes")
        var completionCount = 0
        var receivedError: Error?

        sut.postConsent(sampleConsent) { error in
            completionCount += 1
            receivedError = error
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2)
        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(MockURLProtocol.oauthRequestCount, 1)
        if case .invalidClientCredentials(let message)? = receivedError as? NetworkResponseError {
            XCTAssertEqual(message, "Bad credentials")
        } else {
            XCTFail("Expected invalidClientCredentials, got \(String(describing: receivedError))")
        }
    }

    /// Invalid credentials must not lock the manager permanently: after the credentials are
    /// fixed server-side (or the failure turns out to be transient), the next call should
    /// re-attempt authorization and succeed.
    func testPostConsent_whenCredentialsFailureIsTransient_recoversOnNextCall() {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = Data(#"{"error":"invalid_client","error_description":"Bad credentials"}"#.utf8)
            return (response, data)
        }

        let firstExpectation = expectation(description: "first postConsent completes")
        sut.postConsent(sampleConsent) { error in
            XCTAssertNotNil(error)
            firstExpectation.fulfill()
        }
        waitForExpectations(timeout: 2)

        // Credentials activated server-side: auth and consent endpoints behave normally.
        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/oauth2/token" {
                return (Self.response(for: request, statusCode: 200), Self.validTokenData)
            }
            return (Self.response(for: request, statusCode: 200), Data())
        }

        let secondExpectation = expectation(description: "second postConsent completes")
        var secondError: Error?
        sut.postConsent(sampleConsent) { error in
            secondError = error
            secondExpectation.fulfill()
        }
        waitForExpectations(timeout: 2)

        XCTAssertNil(secondError)
        XCTAssertEqual(MockURLProtocol.oauthRequestCount, 2, "Second call should re-attempt authorization")
        XCTAssertEqual(MockURLProtocol.consentRequestCount, 1)
    }

    func testPostConsent_whenAuthSucceedsAndConsentSucceeds_completesWithoutError() {
        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/oauth2/token" {
                return (Self.response(for: request, statusCode: 200), Self.validTokenData)
            }
            return (Self.response(for: request, statusCode: 200), Data())
        }

        let expectation = expectation(description: "postConsent completes")
        var receivedError: Error?

        sut.postConsent(sampleConsent) { error in
            receivedError = error
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2)
        XCTAssertNil(receivedError)
        XCTAssertEqual(MockURLProtocol.oauthRequestCount, 1)
        XCTAssertEqual(MockURLProtocol.consentRequestCount, 1)
    }

    /// Regression guard for the issue #24 failure class: if the auth endpoint keeps issuing
    /// tokens but the consent endpoint keeps rejecting them with 401, the SDK must retry at
    /// most once and then fail — never loop authorize -> post(401) -> authorize -> ...
    func testPostConsent_whenConsentEndpointAlwaysReturns401_completesOnceWithoutLooping() {
        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/oauth2/token" {
                return (Self.response(for: request, statusCode: 200), Self.validTokenData)
            }
            return (Self.response(for: request, statusCode: 401), Data())
        }

        let expectation = expectation(description: "postConsent completes")
        var completionCount = 0
        var receivedError: Error?

        sut.postConsent(sampleConsent) { error in
            completionCount += 1
            receivedError = error
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2)
        XCTAssertEqual(completionCount, 1)
        XCTAssertNotNil(receivedError)
        XCTAssertLessThanOrEqual(MockURLProtocol.oauthRequestCount, 2)
        XCTAssertLessThanOrEqual(MockURLProtocol.consentRequestCount, 2)
    }

    /// A 2xx auth response with an unusable body (captive portal, proxy HTML) must fail the
    /// current call, and the next call should reach the network again once connectivity is back.
    func testPostConsent_whenAuthReturns200WithGarbageBody_doesNotBlockSubsequentCalls() {
        MockURLProtocol.requestHandler = { request in
            (Self.response(for: request, statusCode: 200), Data("<html>captive portal</html>".utf8))
        }

        let firstExpectation = expectation(description: "first postConsent completes")
        sut.postConsent(sampleConsent) { error in
            XCTAssertNotNil(error)
            firstExpectation.fulfill()
        }
        waitForExpectations(timeout: 2)

        // Connectivity restored: auth and consent endpoints behave normally again.
        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/oauth2/token" {
                return (Self.response(for: request, statusCode: 200), Self.validTokenData)
            }
            return (Self.response(for: request, statusCode: 200), Data())
        }

        let secondExpectation = expectation(description: "second postConsent completes")
        var secondError: Error?
        sut.postConsent(sampleConsent) { error in
            secondError = error
            secondExpectation.fulfill()
        }
        waitForExpectations(timeout: 2)

        XCTAssertNil(secondError)
        XCTAssertEqual(MockURLProtocol.oauthRequestCount, 2, "Second call should re-attempt authorization")
    }

    private static let validTokenData = Data(#"{"access_token":"valid-token","expires_in":3600}"#.utf8)

    private static func response(for request: URLRequest, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }
}

private let testUserDefaults: UserDefaults = {
    let defaults = UserDefaults(suiteName: "NetworkManagerTests")!
    defaults.removePersistentDomain(forName: "NetworkManagerTests")
    return defaults
}()

private let sampleConsent = Consent(
    consentSolutionId: "solution-id",
    consentSolutionVersionId: "version-id",
    userConsents: []
)

private struct StubPlatformInformationGenerator: PlatformInformationGeneratorProtocol {
    func generatePlatformInformation() -> [String: String] {
        [:]
    }
}
