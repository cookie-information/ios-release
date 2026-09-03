import Foundation
import Testing
@testable import MobileConsentsSDK

@Suite
struct NetworkLoggerTests {
    private let requestID = HTTPRequestID(
        rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    )

    @Test
    func disabledLoggerProducesNoOutput() {
        let logger = NetworkLogger(mode: .disabled)

        #expect(logger.requestLog(request: request(), id: requestID) == nil)
        #expect(logger.responseLog(response: response(), id: requestID) == nil)
    }

    @Test
    func metadataOmitsHeadersPayloadAndURLSecrets() throws {
        let logger = NetworkLogger(mode: .metadata)

        let output = try #require(
            logger.requestLog(request: request(), id: requestID)
        )

        #expect(output.contains("REQUEST 00000000-0000-0000-0000-000000000001"))
        #expect(output.contains("POST https://example.com/consents"))
        #expect(!output.contains("client_secret"))
        #expect(!output.contains("access-token"))
        #expect(!output.contains("known-secret"))
        #expect(!output.contains("Content-Type"))
        #expect(!output.contains("Body:"))
    }

    @Test
    func redactedRequestShowsSafeHeadersAndPayloadSizeWithoutPayloadValues() throws {
        let logger = NetworkLogger(mode: .redactedRequestsAndResponses)

        let output = try #require(
            logger.requestLog(request: request(), id: requestID)
        )

        #expect(output.contains("Content-Type: application/json"))
        #expect(output.contains("Authorization: [REDACTED]"))
        #expect(output.contains("X-Secret: [REDACTED]"))
        #expect(output.contains("Body: [REDACTED]"))
        #expect(!output.contains("access-token"))
        #expect(!output.contains("known-secret"))
    }

    @Test
    func redactedResponseShowsStatusAndSafeHeadersWithoutPayloadValues() throws {
        let logger = NetworkLogger(mode: .redactedRequestsAndResponses)

        let output = try #require(
            logger.responseLog(response: response(), id: requestID)
        )

        #expect(output.contains("200 https://example.com/consents"))
        #expect(output.contains("Content-Type: application/json"))
        #expect(output.contains("Set-Cookie: [REDACTED]"))
        #expect(output.contains("Body: [REDACTED]"))
        #expect(!output.contains("known-cookie"))
        #expect(!output.contains("known-user-id"))
    }

    @Test
    func fullRequestsIncludeCompleteRequestButKeepResponseAtMetadataLevel() throws {
        let logger = NetworkLogger(mode: .fullRequests)

        let requestOutput = try #require(
            logger.requestLog(request: request(), id: requestID)
        )
        let responseOutput = try #require(
            logger.responseLog(response: response(), id: requestID)
        )

        #expect(requestOutput.contains("client_secret=known-secret"))
        #expect(requestOutput.contains("Authorization: Bearer access-token"))
        #expect(requestOutput.contains(#"Body: {"userId":"known-user-id"}"#))
        #expect(!responseOutput.contains("access_token"))
        #expect(!responseOutput.contains("Set-Cookie"))
        #expect(!responseOutput.contains("known-user-id"))
    }

    @Test
    func fullRequestsAndResponsesIncludeCompleteNetworkExchange() throws {
        let logger = NetworkLogger(mode: .fullRequestsAndResponses)

        let requestOutput = try #require(
            logger.requestLog(request: request(), id: requestID)
        )
        let responseOutput = try #require(
            logger.responseLog(response: response(), id: requestID)
        )

        #expect(requestOutput.contains("Authorization: Bearer access-token"))
        #expect(requestOutput.contains("known-user-id"))
        #expect(responseOutput.contains("access_token=access-token"))
        #expect(responseOutput.contains("Set-Cookie: session=known-cookie"))
        #expect(responseOutput.contains("known-user-id"))
    }

    private func request() -> HTTPRequestSnapshot {
        HTTPRequestSnapshot(
            url: URL(
                string: "https://example.com/consents?client_secret=known-secret#fragment"
            )!,
            method: .post,
            headers: [
                "Authorization": "Bearer access-token",
                "Content-Type": "application/json",
                "X-Secret": "known-secret",
            ],
            body: Data(#"{"userId":"known-user-id"}"#.utf8),
            timeoutInterval: 10,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
        )
    }

    private func response() -> HTTPResponseSnapshot {
        HTTPResponseSnapshot(
            url: URL(
                string: "https://example.com/consents?access_token=access-token#fragment"
            ),
            statusCode: 200,
            headers: [
                "Content-Type": "application/json",
                "Set-Cookie": "session=known-cookie",
            ],
            body: Data(#"{"userId":"known-user-id"}"#.utf8)
        )
    }
}
