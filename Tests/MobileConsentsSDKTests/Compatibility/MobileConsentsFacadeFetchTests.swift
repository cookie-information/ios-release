import Foundation
import XCTest
@testable import MobileConsentsSDK

final class MobileConsentsFacadeFetchTests: XCTestCase {
    private let userIDKey = "com.MobileConsents.userIdKey"
    private let consentsKey = "com.MobileConsents.consentsKey"

    func testPublicInitializerAcceptsDefaultedConfigurationAtRuntime() {
        let client = MobileConsents(
            clientID: "client-id",
            clientSecret: "client-secret",
            solutionId: "solution-id"
        )

        XCTAssertNotNil(client)
    }

    func testTransportPreservesNetworkLoggerConfiguration() async {
        let defaultTransport = URLSessionHTTPTransport()
        let enabledTransport = URLSessionHTTPTransport(enableNetworkLogger: true)
        let metadataTransport = URLSessionHTTPTransport(networkLoggingMode: .metadata)

        let defaultValue = await defaultTransport.isNetworkLoggingEnabled
        let enabledValue = await enabledTransport.isNetworkLoggingEnabled
        let compatibilityMode = await enabledTransport.networkLoggingMode
        let metadataMode = await metadataTransport.networkLoggingMode
        XCTAssertFalse(defaultValue)
        XCTAssertTrue(enabledValue)
        XCTAssertEqual(compatibilityMode, .redactedRequestsAndResponses)
        XCTAssertEqual(metadataMode, .metadata)
    }

    func testInitializerIsLazyAndDoesNotWriteUserIDOrConsents() throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        _ = try makeClient(suiteName: suiteName, transport: FacadeHTTPTransport())

        XCTAssertNil(userDefaults.object(forKey: userIDKey))
        XCTAssertNil(userDefaults.object(forKey: consentsKey))
    }

    func testUserIDUsesSharedStorageAndRegeneratesAfterClear() async throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let transport = FacadeHTTPTransport()
        let client = try makeClient(suiteName: suiteName, transport: transport)
        let storage = try XCTUnwrap(
            ConsentStore(
                suiteName: suiteName,
                solutionID: "solution-id",
                clientID: "client-id",
                clientSecret: "client-secret"
            )
        )

        let firstID = try await client.getUserId()
        let repeatedFirstID = try await client.getUserId()
        XCTAssertEqual(repeatedFirstID, firstID)
        let storedFirstID = storage.userId
        XCTAssertEqual(storedFirstID, firstID)
        XCTAssertNil(userDefaults.string(forKey: userIDKey))

        try storage.clearAll()

        let nextClient = try makeClient(suiteName: suiteName, transport: transport)
        let secondID = try await nextClient.getUserId()
        let repeatedSecondID = try await nextClient.getUserId()
        XCTAssertNotEqual(secondID, firstID)
        XCTAssertEqual(repeatedSecondID, secondID)
        let storedSecondID = storage.userId
        XCTAssertEqual(storedSecondID, secondID)
    }

    func testSyncAndAsyncReadAPIsReturnTheSameStoredState() async throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let storage = try XCTUnwrap(
            ConsentStore(
                suiteName: suiteName,
                solutionID: "solution-id",
                clientID: "client-id",
                clientSecret: "client-secret"
            )
        )
        let expectedValues = [
            makeConsentValue(id: "second", isSelected: false),
            makeConsentValue(id: "first", isSelected: true),
        ]
        storage.recordPostResult(
            consents: expectedValues,
            versionId: "version-id",
            isInSync: true,
            solutionID: "solution-id"
        )
        let client = try makeClient(suiteName: suiteName, transport: FacadeHTTPTransport())

        let asynchronousUserID = try await client.getUserId()
        XCTAssertEqual(client.userId, asynchronousUserID)
        let synchronousConsents = client.getSavedConsents()
        let asynchronousConsents = try await client.loadSavedConsents()
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: synchronousConsents.map { ($0.consentItem.id, $0.isSelected) }),
            Dictionary(uniqueKeysWithValues: expectedValues.map { ($0.consentItem.id, $0.isSelected) })
        )
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: asynchronousConsents.map { ($0.consentItem.id, $0.isSelected) }),
            Dictionary(uniqueKeysWithValues: expectedValues.map { ($0.consentItem.id, $0.isSelected) })
        )
    }

    func testGetSavedConsentsReadsValuesWrittenByConsentStorage() async throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let storage = try XCTUnwrap(
            ConsentStore(
                suiteName: suiteName,
                solutionID: "solution-id",
                clientID: "client-id",
                clientSecret: "client-secret"
            )
        )
        let expectedValues = [
            makeConsentValue(id: "first", isSelected: true),
            makeConsentValue(id: "second", isSelected: false)
        ]
        storage.recordPostResult(
            consents: expectedValues,
            versionId: "version-id",
            isInSync: true,
            solutionID: "solution-id"
        )
        let client = try makeClient(suiteName: suiteName, transport: FacadeHTTPTransport())

        let saved = try await client.loadSavedConsents()

        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: saved.map { ($0.consentItem.id, $0.isSelected) }),
            Dictionary(uniqueKeysWithValues: expectedValues.map { ($0.consentItem.id, $0.isSelected) })
        )

        try storage.clearAll()
        let savedAfterClear = try await client.loadSavedConsents()
        XCTAssertTrue(savedAfterClear.isEmpty)
    }

    func testFetchUsesCoreRequestAndPreservesLanguageSelection() async throws {
        let response = HTTPResponseSnapshot(
            url: nil,
            statusCode: 200,
            body: try localizedFixtureData()
        )
        let transport = FacadeHTTPTransport(result: .success(response))
        let englishClient = try makeClient(
            suiteName: uniqueSuiteName(),
            transport: transport,
            uiLanguageCode: nil
        )
        let danishClient = try makeClient(
            suiteName: uniqueSuiteName(),
            transport: transport,
            uiLanguageCode: "DA"
        )
        let englishCompletion = expectation(description: "English fetch completion")
        let danishCompletion = expectation(description: "Danish fetch completion")
        englishCompletion.assertForOverFulfill = true
        danishCompletion.assertForOverFulfill = true

        englishClient.fetchConsentSolution { result in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(try? result.get().consentItems.first?.translations.primaryTranslation().language, "EN")
            englishCompletion.fulfill()
        }
        danishClient.fetchConsentSolution { result in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(try? result.get().consentItems.first?.translations.primaryTranslation().language, "DA")
            danishCompletion.fulfill()
        }

        await fulfillment(of: [englishCompletion, danishCompletion], timeout: 2)
        let requests = await transport.requests()
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests.allSatisfy {
            $0.url.path == "/v1/solution-id/consent-data.json" && $0.method == .get
        })
    }

    func testAsyncFetchReturnsSolutionWithoutCompatibilityHost() async throws {
        let response = HTTPResponseSnapshot(
            url: nil,
            statusCode: 200,
            body: try localizedFixtureData()
        )
        let transport = FacadeHTTPTransport(result: .success(response))
        let client = try makeClient(
            suiteName: uniqueSuiteName(),
            transport: transport,
            uiLanguageCode: "DA"
        )

        let solution = try await client.fetchConsentSolution()

        XCTAssertEqual(
            solution.consentItems.first?.translations.primaryTranslation().language,
            "DA"
        )
        let requests = await transport.requests()
        XCTAssertEqual(requests.count, 1)
    }

    func testFetchMapsCoreErrorAndCompletesOnMainExactlyOnce() async throws {
        let transport = FacadeHTTPTransport(
            result: .success(HTTPResponseSnapshot(url: nil, statusCode: 600))
        )
        let client = try makeClient(suiteName: uniqueSuiteName(), transport: transport)
        let completion = expectation(description: "Fetch error completion")
        completion.assertForOverFulfill = true

        client.fetchConsentSolution { result in
            XCTAssertTrue(Thread.isMainThread)
            guard case let .failure(error) = result else {
                XCTFail("Expected failure")
                return
            }
            XCTAssertEqual(
                (error as? NetworkResponseError)?.errorDescription,
                NetworkResponseError.outdated.errorDescription
            )
            completion.fulfill()
        }

        await fulfillment(of: [completion], timeout: 2)
        let requests = await transport.requests()
        XCTAssertEqual(requests.count, 1)
    }

    func testBackgroundFetchCompletesOnMainExactlyOnce() throws {
        let transport = FacadeHTTPTransport(
            result: .success(
                HTTPResponseSnapshot(
                    url: nil,
                    statusCode: 200,
                    body: try localizedFixtureData()
                )
            )
        )
        let client = try makeClient(suiteName: uniqueSuiteName(), transport: transport)
        let backgroundCall = expectation(description: "Background fetch call")
        let completion = expectation(description: "Fetch completion")
        completion.assertForOverFulfill = true
        let invoker = BackgroundFacadeFetchInvoker(
            client: client,
            backgroundCall: backgroundCall
        ) { result in
            XCTAssertTrue(Thread.isMainThread)
            guard case .success = result else {
                return XCTFail("Expected fetch success")
            }
            completion.fulfill()
        }

        invoker.start()

        wait(for: [backgroundCall, completion], timeout: 2)
    }

    func testFetchCallbackReturnsCacheFailureOnMainExactlyOnce() async throws {
        let client = makeClientWithBrokenDatabase(
            transport: FacadeHTTPTransport(
                result: .success(
                    HTTPResponseSnapshot(
                        url: nil,
                        statusCode: 200,
                        body: try localizedFixtureData()
                    )
                )
            )
        )
        let completion = expectation(description: "Cache failure completion")
        completion.assertForOverFulfill = true

        client.fetchConsentSolution { result in
            XCTAssertTrue(Thread.isMainThread)
            guard case let .failure(error) = result else {
                return XCTFail("Expected cache failure")
            }
            XCTAssertEqual(error as? ConsentStoreError, .persistenceFailed)
            completion.fulfill()
        }

        await fulfillment(of: [completion], timeout: 2)
    }

    func testAsyncFetchThrowsCacheFailureWithoutReturningSolution() async throws {
        let client = makeClientWithBrokenDatabase(
            transport: FacadeHTTPTransport(
                result: .success(
                    HTTPResponseSnapshot(
                        url: nil,
                        statusCode: 200,
                        body: try localizedFixtureData()
                    )
                )
            )
        )

        do {
            _ = try await client.fetchConsentSolution()
            XCTFail("Expected cache failure")
        } catch let error as ConsentStoreError {
            XCTAssertEqual(error, .persistenceFailed)
        }
    }

    func testAsyncPostThrowsPersistenceFailure() async {
        let client = makeClientWithBrokenDatabase(
            transport: FacadeHTTPTransport()
        )
        let consent = Consent(
            consentSolutionId: "solution-id",
            consentSolutionVersionId: "version-id",
            userConsents: []
        )

        do {
            try await client.postConsent(consent)
            XCTFail("Expected persistence failure")
        } catch let error as ConsentStoreError {
            XCTAssertEqual(error, .persistenceFailed)
        } catch {
            XCTFail("Expected ConsentStoreError, got \(error)")
        }
    }

    func testPostCallbackReturnsPersistenceFailureOnMainExactlyOnce() async {
        let transport = FacadeHTTPTransport()
        let client = makeClientWithBrokenDatabase(transport: transport)
        let consent = Consent(
            consentSolutionId: "solution-id",
            consentSolutionVersionId: "version-id",
            userConsents: []
        )
        let completion = expectation(description: "Post persistence failure")
        completion.assertForOverFulfill = true

        client.postConsent(consent) { error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(error as? ConsentStoreError, .persistenceFailed)
            completion.fulfill()
        }

        await fulfillment(of: [completion], timeout: 2)
        let requests = await transport.requests()
        XCTAssertTrue(requests.isEmpty)
    }

    private func makeClient(
        suiteName: String,
        transport: any HTTPTransport,
        uiLanguageCode: String? = "EN"
    ) throws -> MobileConsents {
        try XCTUnwrap(MobileConsents(
            storageSuiteName: suiteName,
            transport: transport,
            uiLanguageCode: uiLanguageCode,
            clientID: "client-id",
            clientSecret: "client-secret",
            solutionID: "solution-id",
            accentColor: nil,
            fontSet: .standard
        ))
    }

    private func makeClientWithBrokenDatabase(
        transport: any HTTPTransport
    ) -> MobileConsents {
        let suiteName = uniqueSuiteName()
        let partition = ConsentPartitionID(
            solutionID: "solution-id",
            clientID: "client-id",
            clientSecret: "client-secret"
        )
        let store = ConsentStore(
            database: ConsentDatabase(path: "/dev/null/MobileConsentsSDK.sqlite3"),
            domain: .suite(suiteName),
            partition: partition
        )
        return MobileConsents(
            store: store,
            transport: transport,
            uiLanguageCode: "EN",
            clientID: "client-id",
            clientSecret: "client-secret",
            solutionID: "solution-id",
            accentColor: nil,
            fontSet: .standard
        )
    }

    private func makeUserDefaults(suiteName: String) throws -> UserDefaults {
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }

    private func uniqueSuiteName() -> String {
        "MobileConsentsFacadeFetchTests.\(UUID().uuidString)"
    }

    private func makeConsentValue(id: String, isSelected: Bool) -> UserConsentValue {
        UserConsentValue(
            consentItem: ConsentItem(
                id: id,
                required: false,
                type: .functional,
                translations: Translated(
                    translations: [
                        ConsentTranslation(
                            language: "EN",
                            shortText: "English \(id)",
                            longText: "English details \(id)"
                        )
                    ],
                    primaryLanguage: nil
                )
            ),
            isSelected: isSelected
        )
    }

    private func localizedFixtureData() throws -> Data {
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(forResource: "ConsentSolution", withExtension: "json")
        )
        let fixtureData = try Data(contentsOf: fixtureURL)
        var fixture = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: fixtureData) as? [String: Any]
        )
        var consentItems = try XCTUnwrap(
            fixture["universalConsentItems"] as? [[String: Any]]
        )
        var firstConsentItem = try XCTUnwrap(consentItems.first)
        var translations = try XCTUnwrap(
            firstConsentItem["translations"] as? [[String: String]]
        )
        translations.append([
            "language": "DA",
            "shortText": "Danish consent item short text",
            "longText": "Danish consent item long text"
        ])
        firstConsentItem["translations"] = translations
        consentItems[0] = firstConsentItem
        fixture["universalConsentItems"] = consentItems
        return try JSONSerialization.data(withJSONObject: fixture)
    }

}

private enum FacadeHTTPTransportError: Error, Sendable {
    case unexpectedRequest
}

private final class BackgroundFacadeFetchInvoker: NSObject {
    private let client: MobileConsents
    private let backgroundCall: XCTestExpectation
    private let completion: MobileConsents.ConsentSolutionCompletion

    init(
        client: MobileConsents,
        backgroundCall: XCTestExpectation,
        completion: @escaping MobileConsents.ConsentSolutionCompletion
    ) {
        self.client = client
        self.backgroundCall = backgroundCall
        self.completion = completion
    }

    func start() {
        performSelector(inBackground: #selector(invoke), with: nil)
    }

    @objc private func invoke() {
        XCTAssertFalse(Thread.isMainThread)
        backgroundCall.fulfill()
        client.fetchConsentSolution(completion: completion)
    }
}

private actor FacadeHTTPTransport: HTTPTransport {
    private let result: Result<HTTPResponseSnapshot, FacadeHTTPTransportError>
    private var recordedRequests: [HTTPRequestSnapshot] = []

    init(result: Result<HTTPResponseSnapshot, FacadeHTTPTransportError> = .failure(.unexpectedRequest)) {
        self.result = result
    }

    func start(
        snapshot: HTTPRequestSnapshot,
        id _: HTTPRequestID
    ) async throws -> HTTPTransportOperation {
        recordedRequests.append(snapshot)
        let result = result
        let task = Task<HTTPResponseSnapshot, Error>(
            name: "MobileConsentsFacadeFetchTests.HTTPTransport.response"
        ) {
            try result.get()
        }
        return HTTPTransportOperation(task: task)
    }

    func requests() -> [HTTPRequestSnapshot] {
        recordedRequests
    }
}
