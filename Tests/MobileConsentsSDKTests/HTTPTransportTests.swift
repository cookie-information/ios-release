import Foundation
import XCTest
@testable import MobileConsentsSDK

final class HTTPTransportTests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        super.setUp()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HTTPTransportTestURLProtocol.self]
        session = URLSession(configuration: configuration)
    }

    override func tearDown() {
        session = nil
        super.tearDown()
    }

    func testStartIsSendableAndPreservesRequestAndResponseSnapshots() async throws {
        let requestURL = URL(string: "https://example.com/success?request=1")!
        let requestBody = Data("request-body".utf8)
        let snapshot = HTTPRequestSnapshot(
            url: requestURL,
            method: .post,
            headers: ["X-Request": "value"],
            body: requestBody,
            timeoutInterval: 17.5,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
        )
        let id = HTTPRequestID()
        let transport: any HTTPTransport = URLSessionHTTPTransport(session: session)

        let _: any Sendable = id
        let _: any Sendable = snapshot
        let _: any Sendable = transport

        let operation = try await transport.start(snapshot: snapshot, id: id)
        let _: any Sendable = operation
        let response = try await operation.value
        let observedData = try XCTUnwrap(response.body)
        let observedRequest = try JSONDecoder().decode(
            ObservedRequestSnapshot.self,
            from: observedData
        )

        XCTAssertEqual(observedRequest.url, requestURL.absoluteString)
        XCTAssertEqual(observedRequest.method, "POST")
        XCTAssertEqual(observedRequest.headers["X-Request"], "value")
        XCTAssertEqual(observedRequest.body, requestBody)
        XCTAssertEqual(observedRequest.timeoutInterval, 17.5)
        XCTAssertEqual(observedRequest.cachePolicy, "reloadIgnoringLocalAndRemoteCacheData")
        XCTAssertEqual(response.url, requestURL)
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.headers, ["X-Response": "success"])
    }

    func testNonHTTPResponseThrowsAndCleansUpID() async throws {
        let requestURL = URL(string: "https://example.com/non-http")!
        let snapshot = HTTPRequestSnapshot(
            url: requestURL,
            method: .get,
            timeoutInterval: 10,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
        )
        let transport = URLSessionHTTPTransport(session: session)
        let id = HTTPRequestID()
        let operation = try await transport.start(snapshot: snapshot, id: id)

        do {
            _ = try await operation.value
            XCTFail("Expected nonHTTPResponse")
        } catch let error as HTTPTransportError {
            XCTAssertEqual(error, .nonHTTPResponse)
        } catch {
            XCTFail("Expected HTTPTransportError.nonHTTPResponse, got \(error)")
        }

        let retryURL = URL(string: "https://example.com/success?reuse=error")!
        let retrySnapshot = HTTPRequestSnapshot(
            url: retryURL,
            method: .get,
            timeoutInterval: 10,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
        )
        let retryOperation = try await transport.start(snapshot: retrySnapshot, id: id)
        let retryResponse = try await retryOperation.value

        XCTAssertEqual(retryResponse.url, retryURL)
        XCTAssertEqual(retryResponse.statusCode, 200)
    }

    func testOperationCancellationStopsLoadingAndCleansUpID() async throws {
        let requestURL = URL(string: "https://example.com/cancel")!
        let started = urlNotificationExpectation(
            .httpTransportDidStartLoading,
            matching: requestURL
        )
        let stopped = urlNotificationExpectation(
            .httpTransportDidStopLoading,
            matching: requestURL
        )
        let transport = URLSessionHTTPTransport(session: session)
        let id = HTTPRequestID()
        let snapshot = HTTPRequestSnapshot(
            url: requestURL,
            method: .get,
            timeoutInterval: 30,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
        )
        let operation = try await transport.start(snapshot: snapshot, id: id)

        await fulfillment(of: [started], timeout: 2)
        operation.cancel()
        await fulfillment(of: [stopped], timeout: 2)

        do {
            _ = try await operation.value
            XCTFail("Expected cancellation")
        } catch let error as HTTPTransportError {
            XCTAssertEqual(error, .cancelled)
        } catch {
            XCTFail("Expected HTTPTransportError.cancelled, got \(error)")
        }

        let retryURL = URL(string: "https://example.com/success?reuse=cancelled")!
        let retrySnapshot = HTTPRequestSnapshot(
            url: retryURL,
            method: .get,
            timeoutInterval: 10,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
        )
        let retryOperation = try await transport.start(snapshot: retrySnapshot, id: id)
        let retryResponse = try await retryOperation.value

        XCTAssertEqual(retryResponse.url, retryURL)
        XCTAssertEqual(retryResponse.statusCode, 200)
    }

    func testValueWaiterCancellationStopsOperationAndReturnsCancelled() async throws {
        let requestURL = URL(string: "https://example.com/caller-cancel")!
        let started = urlNotificationExpectation(
            .httpTransportDidStartLoading,
            matching: requestURL
        )
        let stopped = urlNotificationExpectation(
            .httpTransportDidStopLoading,
            matching: requestURL
        )
        let transport = URLSessionHTTPTransport(session: session)
        let id = HTTPRequestID()
        let snapshot = HTTPRequestSnapshot(
            url: requestURL,
            method: .get,
            timeoutInterval: 30,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
        )
        let operation = try await transport.start(snapshot: snapshot, id: id)

        await fulfillment(of: [started], timeout: 2)

        let waiter = Task<HTTPResponseSnapshot, Error>(
            name: "HTTPTransportTests.valueWaiterCancellation"
        ) {
            try await operation.value
        }
        waiter.cancel()
        await fulfillment(of: [stopped], timeout: 2)

        do {
            _ = try await waiter.value
            XCTFail("Expected caller cancellation")
        } catch let error as HTTPTransportError {
            XCTAssertEqual(error, .cancelled)
        } catch {
            XCTFail("Expected HTTPTransportError.cancelled, got \(error)")
        }
    }

    func testStartRegistersOperationBeforeReturningAndRejectsDuplicateActiveID() async throws {
        let duplicateURL = URL(string: "https://example.com/duplicate")!
        let started = urlNotificationExpectation(
            .httpTransportDidStartLoading,
            matching: duplicateURL
        )
        let stopped = urlNotificationExpectation(
            .httpTransportDidStopLoading,
            matching: duplicateURL
        )
        let transport = URLSessionHTTPTransport(session: session)
        let id = HTTPRequestID()
        let duplicateSnapshot = HTTPRequestSnapshot(
            url: duplicateURL,
            method: .get,
            timeoutInterval: 30,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
        )
        let firstOperation = try await transport.start(snapshot: duplicateSnapshot, id: id)

        do {
            _ = try await transport.start(snapshot: duplicateSnapshot, id: id)
            XCTFail("Expected duplicateRequestID")
        } catch let error as HTTPTransportError {
            XCTAssertEqual(error, .duplicateRequestID)
        } catch {
            XCTFail("Expected HTTPTransportError.duplicateRequestID, got \(error)")
        }

        await fulfillment(of: [started], timeout: 2)
        firstOperation.cancel()
        await fulfillment(of: [stopped], timeout: 2)

        do {
            _ = try await firstOperation.value
            XCTFail("Expected first operation cancellation")
        } catch let error as HTTPTransportError {
            XCTAssertEqual(error, .cancelled)
        } catch {
            XCTFail("Expected HTTPTransportError.cancelled, got \(error)")
        }
    }

    func testSuccessfulOperationCleansUpIDForReuse() async throws {
        let firstURL = URL(string: "https://example.com/success?cleanup=first")!
        let secondURL = URL(string: "https://example.com/success?cleanup=second")!
        let transport = URLSessionHTTPTransport(session: session)
        let id = HTTPRequestID()
        let firstSnapshot = HTTPRequestSnapshot(
            url: firstURL,
            method: .get,
            timeoutInterval: 10,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
        )
        let secondSnapshot = HTTPRequestSnapshot(
            url: secondURL,
            method: .get,
            timeoutInterval: 10,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
        )

        let firstOperation = try await transport.start(snapshot: firstSnapshot, id: id)
        let firstResponse = try await firstOperation.value
        let secondOperation = try await transport.start(snapshot: secondSnapshot, id: id)
        let secondResponse = try await secondOperation.value

        XCTAssertEqual(firstResponse.url, firstURL)
        XCTAssertEqual(secondResponse.url, secondURL)
    }

    private func urlNotificationExpectation(
        _ name: Notification.Name,
        matching expectedURL: URL
    ) -> XCTestExpectation {
        expectation(forNotification: name, object: nil) { notification in
            (notification.object as? URL) == expectedURL
        }
    }
}

private struct ObservedRequestSnapshot: Codable, Equatable, Sendable {
    let url: String?
    let method: String?
    let headers: [String: String]
    let body: Data?
    let timeoutInterval: Double
    let cachePolicy: String
}

private extension Notification.Name {
    static let httpTransportDidStartLoading = Notification.Name(
        "HTTPTransportTests.didStartLoading"
    )
    static let httpTransportDidStopLoading = Notification.Name(
        "HTTPTransportTests.didStopLoading"
    )
}

private final class HTTPTransportTestURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        switch request.url?.path {
        case "/success":
            respondWithObservedRequest()
        case "/non-http":
            guard let responseURL = request.url else {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                return
            }
            let response = URLResponse(
                url: responseURL,
                mimeType: nil,
                expectedContentLength: 0,
                textEncodingName: nil
            )
            respond(with: response, body: Data())
        case "/cancel", "/caller-cancel", "/duplicate":
            NotificationCenter.default.post(
                name: .httpTransportDidStartLoading,
                object: request.url
            )
        default:
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
        }
    }

    override func stopLoading() {
        switch request.url?.path {
        case "/cancel", "/caller-cancel", "/duplicate":
            NotificationCenter.default.post(
                name: .httpTransportDidStopLoading,
                object: request.url
            )
        default:
            break
        }
    }

    private func respondWithObservedRequest() {
        guard let requestURL = request.url,
              let observedData = try? JSONEncoder().encode(observedRequest())
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotParseResponse))
            return
        }

        let response = HTTPURLResponse(
            url: requestURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["X-Response": "success"]
        )!
        respond(with: response, body: observedData)
    }

    private func observedRequest() -> ObservedRequestSnapshot {
        ObservedRequestSnapshot(
            url: request.url?.absoluteString,
            method: request.httpMethod,
            headers: request.allHTTPHeaderFields ?? [:],
            body: requestBodyData(),
            timeoutInterval: request.timeoutInterval,
            cachePolicy: request.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData
                ? "reloadIgnoringLocalAndRemoteCacheData"
                : String(describing: request.cachePolicy)
        )
    }

    private func requestBodyData() -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var body = Data()
        while true {
            let bytesRead = stream.read(buffer, maxLength: bufferSize)
            guard bytesRead >= 0 else {
                return nil
            }
            if bytesRead == 0 {
                return body
            }
            body.append(buffer, count: bytesRead)
        }
    }

    private func respond(with response: URLResponse, body: Data) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
}
