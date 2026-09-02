import Foundation
import XCTest
@testable import MobileConsentsSDK

final class NetworkCoreTests: XCTestCase {
    func testFetchConsentSolutionBuildsExactRequestAndStartsTransportOnce() async throws {
        let transport = HTTPTransportSpy(
            stub: .response(
                HTTPResponseSnapshot(
                    url: nil,
                    statusCode: 299,
                    body: try fixtureData()
                )
            )
        )
        let sut = NetworkCore(transport: transport, primaryLanguage: "PL")
        let _: any Sendable = sut

        _ = try await sut.fetchConsentSolution(solutionID: "solution-id")

        let invocations = await transport.recordedInvocations()
        XCTAssertEqual(invocations.count, 1)
        let invocation = try XCTUnwrap(invocations.first)
        XCTAssertEqual(
            invocation.snapshot,
            HTTPRequestSnapshot(
                url: try XCTUnwrap(
                    URL(
                        string: "https://cdnapi.app.cookieinformation.com/v1/solution-id/consent-data.json"
                    )
                ),
                method: .get,
                headers: ["Content-Type": "application/json"],
                body: nil,
                timeoutInterval: 10,
                cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
            )
        )
    }

    func testFetchConsentSolutionDecodesFixtureUsingPrimaryLanguage() async throws {
        let primaryLanguage = "PL"
        let data = try fixtureData()
        let transport = HTTPTransportSpy(
            stub: .response(
                HTTPResponseSnapshot(url: nil, statusCode: 200, body: data)
            )
        )
        let sut = NetworkCore(
            transport: transport,
            primaryLanguage: primaryLanguage
        )
        let decoder = JSONDecoder()
        decoder.userInfo[primaryLanguageCodingUserInfoKey] = primaryLanguage
        let expected = try decoder.decode(ConsentSolutionValue.self, from: data)

        let value = try await sut.fetchConsentSolution(solutionID: "solution-id")

        XCTAssertEqual(value, expected)
        XCTAssertEqual(
            value.consentItems.first?.translations.primaryTranslation().language,
            "EN"
        )
    }

    func testFetchConsentSolutionRejectsNonSuccessfulStatusCode() async throws {
        let transport = HTTPTransportSpy(
            stub: .response(
                HTTPResponseSnapshot(
                    url: nil,
                    statusCode: 300,
                    body: try fixtureData()
                )
            )
        )
        let sut = NetworkCore(transport: transport, primaryLanguage: "EN")

        do {
            _ = try await sut.fetchConsentSolution(solutionID: "solution-id")
            XCTFail("Expected unsuccessfulStatusCode")
        } catch let error as NetworkCoreError {
            XCTAssertEqual(error, .unsuccessfulStatusCode(300))
        } catch {
            XCTFail("Expected NetworkCoreError.unsuccessfulStatusCode, got \(error)")
        }
    }

    func testFetchConsentSolutionRejectsSuccessfulResponseWithoutBody() async {
        let transport = HTTPTransportSpy(
            stub: .response(
                HTTPResponseSnapshot(url: nil, statusCode: 204, body: nil)
            )
        )
        let sut = NetworkCore(transport: transport, primaryLanguage: "EN")

        do {
            _ = try await sut.fetchConsentSolution(solutionID: "solution-id")
            XCTFail("Expected missingBody")
        } catch let error as NetworkCoreError {
            XCTAssertEqual(error, .missingBody)
        } catch {
            XCTFail("Expected NetworkCoreError.missingBody, got \(error)")
        }
    }

    func testFetchConsentSolutionPropagatesDecodingErrorForEmptyBody() async {
        let transport = HTTPTransportSpy(
            stub: .response(
                HTTPResponseSnapshot(url: nil, statusCode: 204, body: Data())
            )
        )
        let sut = NetworkCore(transport: transport, primaryLanguage: "EN")

        do {
            _ = try await sut.fetchConsentSolution(solutionID: "solution-id")
            XCTFail("Expected DecodingError")
        } catch is DecodingError {
        } catch {
            XCTFail("Expected DecodingError, got \(error)")
        }
    }

    func testFetchConsentSolutionPropagatesDecodingError() async {
        let transport = HTTPTransportSpy(
            stub: .response(
                HTTPResponseSnapshot(
                    url: nil,
                    statusCode: 200,
                    body: Data("{not-json".utf8)
                )
            )
        )
        let sut = NetworkCore(transport: transport, primaryLanguage: "EN")

        do {
            _ = try await sut.fetchConsentSolution(solutionID: "solution-id")
            XCTFail("Expected DecodingError")
        } catch is DecodingError {
        } catch {
            XCTFail("Expected DecodingError, got \(error)")
        }
    }

    func testFetchConsentSolutionPropagatesTransportErrorAndStartsOnce() async {
        let transport = HTTPTransportSpy(stub: .failure(.transportFailed))
        let sut = NetworkCore(transport: transport, primaryLanguage: "EN")

        do {
            _ = try await sut.fetchConsentSolution(solutionID: "solution-id")
            XCTFail("Expected transport error")
        } catch let error as NetworkCoreTestTransportError {
            XCTAssertEqual(error, .transportFailed)
        } catch {
            XCTFail("Expected the transport error, got \(error)")
        }

        let invocations = await transport.recordedInvocations()
        XCTAssertEqual(invocations.count, 1)
    }

    func testCallerCancellationCancelsTransportOperation() async {
        let cancellationProbe = CancellationProbe()
        let transport = HTTPTransportSpy(
            stub: .pendingCancellation(cancellationProbe)
        )
        let sut = NetworkCore(transport: transport, primaryLanguage: "EN")
        let fetchTask = Task<ConsentSolutionValue, Error>(
            name: "NetworkCoreTests.fetchConsentSolution.cancellation"
        ) {
            try await sut.fetchConsentSolution(solutionID: "solution-id")
        }

        await cancellationProbe.waitUntilOperationStarted()
        fetchTask.cancel()

        do {
            _ = try await fetchTask.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }

        let operationWasCancelled = await cancellationProbe.operationWasCancelled()
        let invocations = await transport.recordedInvocations()
        XCTAssertTrue(operationWasCancelled)
        XCTAssertEqual(invocations.count, 1)
    }

    private func fixtureData() throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "ConsentSolution", withExtension: "json")
        )
        return try Data(contentsOf: url)
    }
}

private enum NetworkCoreTestTransportError: Error, Equatable, Sendable {
    case transportFailed
    case pendingOperationEndedUnexpectedly
}

private actor HTTPTransportSpy: HTTPTransport {
    struct Invocation: Sendable {
        let snapshot: HTTPRequestSnapshot
        let id: HTTPRequestID
    }

    enum Stub: Sendable {
        case response(HTTPResponseSnapshot)
        case failure(NetworkCoreTestTransportError)
        case pendingCancellation(CancellationProbe)
    }

    private let stub: Stub
    private var invocations: [Invocation] = []

    init(stub: Stub) {
        self.stub = stub
    }

    func start(
        snapshot: HTTPRequestSnapshot,
        id: HTTPRequestID
    ) async throws -> HTTPTransportOperation {
        invocations.append(Invocation(snapshot: snapshot, id: id))

        switch stub {
        case let .response(response):
            let task = Task<HTTPResponseSnapshot, Error>(
                name: "NetworkCoreTests.HTTPTransportSpy.response"
            ) {
                response
            }
            return HTTPTransportOperation(task: task)

        case let .failure(error):
            let task = Task<HTTPResponseSnapshot, Error>(
                name: "NetworkCoreTests.HTTPTransportSpy.failure"
            ) {
                throw error
            }
            return HTTPTransportOperation(task: task)

        case let .pendingCancellation(cancellationProbe):
            let (stream, continuation) = AsyncStream<Void>.makeStream()
            let task = Task<HTTPResponseSnapshot, Error>(
                name: "NetworkCoreTests.HTTPTransportSpy.pendingCancellation"
            ) {
                defer { continuation.finish() }
                await cancellationProbe.recordOperationStarted()
                for await _ in stream {}

                if Task<Never, Never>.isCancelled {
                    await cancellationProbe.recordOperationCancelled()
                }
                try Task<Never, Never>.checkCancellation()
                throw NetworkCoreTestTransportError.pendingOperationEndedUnexpectedly
            }
            return HTTPTransportOperation(task: task)
        }
    }

    func recordedInvocations() -> [Invocation] {
        invocations
    }
}

private actor CancellationProbe {
    private var didStartOperation = false
    private var didCancelOperation = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []

    func recordOperationStarted() {
        didStartOperation = true
        for waiter in startWaiters {
            waiter.resume()
        }
        startWaiters.removeAll()
    }

    func waitUntilOperationStarted() async {
        guard !didStartOperation else {
            return
        }

        await withCheckedContinuation {
            startWaiters.append($0)
        }
    }

    func recordOperationCancelled() {
        didCancelOperation = true
    }

    func operationWasCancelled() -> Bool {
        didCancelOperation
    }
}