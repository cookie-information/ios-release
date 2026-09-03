import Foundation
import XCTest
@testable import MobileConsentsSDK

final class ConsentCoreTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "MobileConsentsSDK.ConsentCoreTests.\(UUID().uuidString)"
        userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
    }

    func testPresentationDecisionPresentsExactFetchedSolutionForEmptyStorage() async throws {
        let expected = try fixtureSolution()
        let storage = try makeStorage()
        let sut = makeSUT(storage: storage, responseData: try fixtureData())

        let decision = try await sut.presentationDecision(ignoreVersionChanges: false)

        XCTAssertEqual(
            decision,
            .present(solution: expected, savedConsents: [:])
        )
    }

    func testPresentationDecisionPropagatesSolutionCacheFailure() async throws {
        let storage = ConsentStore(
            database: ConsentDatabase(path: "/dev/null/MobileConsentsSDK.sqlite3"),
            domain: .suite(suiteName),
            partition: ConsentPartitionID(solutionID: "solution-id", clientID: "client-id", clientSecret: "client-secret")
        )
        let sut = makeSUT(storage: storage, responseData: try fixtureData())

        do {
            _ = try await sut.presentationDecision(ignoreVersionChanges: false)
            XCTFail("Expected solution cache failure")
        } catch let error as ConsentStoreError {
            XCTAssertEqual(error, .persistenceFailed)
        }
    }

    func testFetchPersistsSolutionBeforeReturningIt() async throws {
        let expected = try fixtureSolution()
        let storage = try makeStorage()
        let sut = makeSUT(storage: storage, responseData: try fixtureData())

        let fetched = try await sut.fetchConsentSolution()
        let cached = try ConsentDatabase(
            path: ConsentStorageDomain.suite(suiteName).consentDatabasePath
        ).latestConsentSolution(
            partition: ConsentPartitionID(
                solutionID: "solution-id",
                clientID: "client-id",
                clientSecret: "client-secret"
            ),
            primaryLanguage: "EN"
        )

        XCTAssertEqual(fetched, expected)
        XCTAssertEqual(cached, expected)
    }

    func testPresentationDecisionUsesStoredValuesForMatchingVersion() async throws {
        let fetched = try fixtureSolution()
        let first = makeConsent(id: "first", isSelected: true)
        let second = makeConsent(id: "second", isSelected: false)
        let storedValues = [
            "first": first,
            "second": second,
        ]
        let storage = try makeStorage()
        try storage.savePending(
            submission: Consent(
                consentSolutionId: "solution-id",
                consentSolutionVersionId: fetched.versionId,
                userConsents: [first, second].map(UserConsent.init)
            ).submissionValue
        )
        let sut = makeSUT(storage: storage, responseData: try fixtureData())

        let decision = try await sut.presentationDecision(ignoreVersionChanges: false)

        XCTAssertEqual(decision, .useStored(storedValues))
        let snapshot = try storage.readSnapshot()
        XCTAssertEqual(snapshot.values, storedValues)
        XCTAssertEqual(Set(snapshot.values.keys), Set(storedValues.keys))
    }

    func testPresentationDecisionPresentsAndPreservesEmptySynchronizedSubmissionForMatchingVersion() async throws {
        let fetched = try fixtureSolution()
        let storage = try makeStorage()
        let submission = Consent(
            consentSolutionId: "solution-id",
            consentSolutionVersionId: fetched.versionId,
            userConsents: []
        ).submissionValue
        try storage.savePending(submission: submission)
        let claim = try XCTUnwrap(storage.claimPendingSynchronization())
        XCTAssertTrue(
            try storage.completeSynchronizationClaim(claim)
        )
        let before = try storage.persistenceInspection(
            suiteName: suiteName,
            solutionID: "solution-id",
            clientID: "client-id",
            clientSecret: "client-secret"
        )
        XCTAssertEqual(before.submission, submission)
        XCTAssertTrue(before.consentsInSync)
        let sut = makeSUT(storage: storage, responseData: try fixtureData())

        let decision = try await sut.presentationDecision(ignoreVersionChanges: false)

        XCTAssertEqual(
            decision,
            .present(solution: fetched, savedConsents: [:])
        )
        let after = try storage.persistenceInspection(
            suiteName: suiteName,
            solutionID: "solution-id",
            clientID: "client-id",
            clientSecret: "client-secret"
        )
        XCTAssertEqual(after, before)
    }

    func testPresentationDecisionPresentsAndPreservesEmptyPendingSubmissionForMatchingVersion() async throws {
        let fetched = try fixtureSolution()
        let storage = try makeStorage()
        let submission = Consent(
            consentSolutionId: "solution-id",
            consentSolutionVersionId: fetched.versionId,
            userConsents: []
        ).submissionValue
        try storage.savePending(submission: submission)
        let before = try storage.persistenceInspection(
            suiteName: suiteName,
            solutionID: "solution-id",
            clientID: "client-id",
            clientSecret: "client-secret"
        )
        XCTAssertEqual(before.submission, submission)
        XCTAssertFalse(before.consentsInSync)
        let sut = makeSUT(storage: storage, responseData: try fixtureData())

        let decision = try await sut.presentationDecision(ignoreVersionChanges: false)

        XCTAssertEqual(
            decision,
            .present(solution: fetched, savedConsents: [:])
        )
        let after = try storage.persistenceInspection(
            suiteName: suiteName,
            solutionID: "solution-id",
            clientID: "client-id",
            clientSecret: "client-secret"
        )
        XCTAssertEqual(after, before)
        XCTAssertFalse(after.consentsInSync)
    }

    func testPresentationDecisionPresentsAndPreservesPendingConsentForMismatchedVersion() async throws {
        let fetched = try fixtureSolution()
        let storedValue = makeConsent(id: "stored", isSelected: true)
        let storage = try makeStorage()
        let expectedUserID = storage.userId
        let submission = Consent(
            consentSolutionId: "solution-id",
            consentSolutionVersionId: "old-version",
            userConsents: [UserConsent(storedValue)]
        ).submissionValue
        try storage.savePending(submission: submission)
        let sut = makeSUT(storage: storage, responseData: try fixtureData())

        let decision = try await sut.presentationDecision(ignoreVersionChanges: false)

        XCTAssertEqual(
            decision,
            .present(
                solution: fetched,
                savedConsents: ["stored": storedValue]
            )
        )
        let snapshot = try storage.persistenceInspection(
            suiteName: suiteName,
            solutionID: "solution-id",
            clientID: "client-id",
            clientSecret: "client-secret"
        )
        XCTAssertEqual(snapshot.userId, expectedUserID)
        XCTAssertEqual(snapshot.values, ["stored": storedValue])
        XCTAssertEqual(snapshot.versionId, "old-version")
        XCTAssertEqual(snapshot.submission, submission)
        XCTAssertFalse(snapshot.consentsInSync)
        XCTAssertNil(userDefaults.object(forKey: LegacyConsentStorageKey.consentsKey))
    }

    func testPresentationDecisionUsesStoredValuesWithoutClearingForIgnoredVersionChanges() async throws {
        let storedValue = makeConsent(id: "stored", isSelected: true)
        let storage = try makeStorage()
        _ = storage.userId
        storage.recordPostResult(
            consents: [storedValue],
            versionId: "old-version",
            isInSync: false, solutionID: "solution-id"
        )
        let before = try storage.persistenceInspection(
            suiteName: suiteName,
            solutionID: "solution-id",
            clientID: "client-id",
            clientSecret: "client-secret"
        )
        let beforeDomain = userDefaults.persistentDomain(forName: suiteName)
        let sut = makeSUT(storage: storage, responseData: try fixtureData())

        let decision = try await sut.presentationDecision(ignoreVersionChanges: true)

        XCTAssertEqual(decision, .useStored([storedValue.consentItem.id: storedValue]))
        let after = try storage.persistenceInspection(
            suiteName: suiteName,
            solutionID: "solution-id",
            clientID: "client-id",
            clientSecret: "client-secret"
        )
        let afterDomain = userDefaults.persistentDomain(forName: suiteName)
        XCTAssertEqual(after, before)
        XCTAssertTrue(domainsAreEqual(beforeDomain, afterDomain))
    }

    func testPresentationDecisionPropagatesTransportErrorWithoutChangingStorage() async throws {
        let storedValue = makeConsent(id: "stored", isSelected: true)
        let storage = try makeStorage()
        _ = storage.userId
        storage.recordPostResult(
            consents: [storedValue],
            versionId: "stored-version",
            isInSync: false, solutionID: "solution-id"
        )
        let before = try storage.persistenceInspection(
            suiteName: suiteName,
            solutionID: "solution-id",
            clientID: "client-id",
            clientSecret: "client-secret"
        )
        let beforeDomain = userDefaults.persistentDomain(forName: suiteName)
        let sut = makeSUT(storage: storage, error: .transportFailed)

        do {
            _ = try await sut.presentationDecision(ignoreVersionChanges: false)
            XCTFail("Expected transport error")
        } catch let error as ConsentCoreTestTransportError {
            XCTAssertEqual(error, .transportFailed)
        } catch {
            XCTFail("Expected ConsentCoreTestTransportError, got \(error)")
        }

        let after = try storage.persistenceInspection(
            suiteName: suiteName,
            solutionID: "solution-id",
            clientID: "client-id",
            clientSecret: "client-secret"
        )
        let afterDomain = userDefaults.persistentDomain(forName: suiteName)
        XCTAssertEqual(after, before)
        XCTAssertTrue(domainsAreEqual(beforeDomain, afterDomain))
    }

    func testPresentationDecisionAllowsOverlappingFetchesToCompleteOutOfOrder() async throws {
        let expected = try fixtureSolution()
        let response = HTTPResponseSnapshot(
            url: nil,
            statusCode: 200,
            body: try fixtureData()
        )
        let storage = try makeStorage()
        let transport = ControlledConsentCoreHTTPTransport()
        let sut = makeSUT(storage: storage, transport: transport)

        let firstDecisionTask = Task<ConsentPresentationDecision, Error>(
            name: "ConsentCoreTests.firstPresentationDecision"
        ) {
            try await sut.presentationDecision(ignoreVersionChanges: false)
        }
        await transport.waitUntilRequestCount(1)

        let secondDecisionTask = Task<ConsentPresentationDecision, Error>(
            name: "ConsentCoreTests.secondPresentationDecision"
        ) {
            try await sut.presentationDecision(ignoreVersionChanges: false)
        }
        await transport.waitUntilRequestCount(2)

        await transport.completeRequest(at: 1, with: response)
        let secondDecision = try await secondDecisionTask.value
        await transport.completeRequest(at: 0, with: response)
        let firstDecision = try await firstDecisionTask.value

        XCTAssertEqual(
            firstDecision,
            .present(solution: expected, savedConsents: [:])
        )
        XCTAssertEqual(
            secondDecision,
            .present(solution: expected, savedConsents: [:])
        )
    }

    func testPresentationDecisionCancellationAfterFetchStartsDoesNotChangeStorage() async throws {
        let storedValue = makeConsent(id: "stored", isSelected: true)
        let storage = try makeStorage()
        _ = storage.userId
        storage.recordPostResult(
            consents: [storedValue],
            versionId: "old-version",
            isInSync: false, solutionID: "solution-id"
        )
        let before = try storage.persistenceInspection(
            suiteName: suiteName,
            solutionID: "solution-id",
            clientID: "client-id",
            clientSecret: "client-secret"
        )
        let beforeDomain = userDefaults.persistentDomain(forName: suiteName)
        let transport = ControlledConsentCoreHTTPTransport()
        let sut = makeSUT(storage: storage, transport: transport)

        let decisionTask = Task<ConsentPresentationDecision, Error>(
            name: "ConsentCoreTests.cancelledPresentationDecision"
        ) {
            try await sut.presentationDecision(ignoreVersionChanges: false)
        }
        await transport.waitUntilRequestCount(1)
        decisionTask.cancel()
        await transport.completeRequest(
            at: 0,
            with: HTTPResponseSnapshot(
                url: nil,
                statusCode: 200,
                body: try fixtureData()
            )
        )

        do {
            _ = try await decisionTask.value
            XCTFail("Expected cancellation error")
        } catch is CancellationError {
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }

        let after = try storage.persistenceInspection(
            suiteName: suiteName,
            solutionID: "solution-id",
            clientID: "client-id",
            clientSecret: "client-secret"
        )
        let afterDomain = userDefaults.persistentDomain(forName: suiteName)
        XCTAssertEqual(after, before)
        XCTAssertTrue(domainsAreEqual(beforeDomain, afterDomain))
    }

    private func makeSUT(
        storage: ConsentStore,
        responseData: Data
    ) -> ConsentCore {
        ConsentCore(
            solutionID: "solution-id",
            networkCore: NetworkCore(
                transport: ConsentCoreHTTPTransport(responseData: responseData),
                primaryLanguage: "EN"
            ),
            store: storage,
            clientID: "client-id",
            clientSecret: "client-secret",
            platformInformation: { [:] }
        )
    }

    private func makeSUT(
        storage: ConsentStore,
        transport: any HTTPTransport
    ) -> ConsentCore {
        ConsentCore(
            solutionID: "solution-id",
            networkCore: NetworkCore(
                transport: transport,
                primaryLanguage: "EN"
            ),
            store: storage,
            clientID: "client-id",
            clientSecret: "client-secret",
            platformInformation: { [:] }
        )
    }

    private func makeSUT(
        storage: ConsentStore,
        error: ConsentCoreTestTransportError
    ) -> ConsentCore {
        ConsentCore(
            solutionID: "solution-id",
            networkCore: NetworkCore(
                transport: ConsentCoreHTTPTransport(error: error),
                primaryLanguage: "EN"
            ),
            store: storage,
            clientID: "client-id",
            clientSecret: "client-secret",
            platformInformation: { [:] }
        )
    }

    private func makeStorage() throws -> ConsentStore {
        try XCTUnwrap(
            ConsentStore(
                suiteName: suiteName,
                solutionID: "solution-id",
                clientID: "client-id",
                clientSecret: "client-secret"
            )
        )
    }

    private func fixtureSolution() throws -> ConsentSolutionValue {
        let decoder = JSONDecoder()
        decoder.userInfo[primaryLanguageCodingUserInfoKey] = "EN"
        return try decoder.decode(ConsentSolutionValue.self, from: fixtureData())
    }

    private func fixtureData() throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "ConsentSolution", withExtension: "json")
        )
        return try Data(contentsOf: url)
    }

    private func makeConsent(id: String, isSelected: Bool) -> UserConsentValue {
        UserConsentValue(
            consentItem: ConsentItem(
                id: id,
                required: false,
                type: .functional,
                translations: Translated(
                    translations: [
                        ConsentTranslation(
                            language: "EN",
                            shortText: "Text",
                            longText: "Details"
                        ),
                    ],
                    primaryLanguage: nil
                )
            ),
            isSelected: isSelected
        )
    }

    private func domainsAreEqual(
        _ lhs: [String: Any]?,
        _ rhs: [String: Any]?
    ) -> Bool {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return (lhs as NSDictionary).isEqual(rhs)
        case (nil, nil):
            return true
        default:
            return false
        }
    }
}

private enum ConsentCoreTestTransportError: Error, Equatable, Sendable {
    case transportFailed
}

private actor ConsentCoreHTTPTransport: HTTPTransport {
    private let result: Result<HTTPResponseSnapshot, ConsentCoreTestTransportError>

    init(responseData: Data) {
        self.result = .success(
            HTTPResponseSnapshot(
                url: nil,
                statusCode: 200,
                body: responseData
            )
        )
    }

    init(error: ConsentCoreTestTransportError) {
        self.result = .failure(error)
    }

    func start(
        snapshot _: HTTPRequestSnapshot,
        id _: HTTPRequestID
    ) async throws -> HTTPTransportOperation {
        let result = result
        let task = Task<HTTPResponseSnapshot, Error>(
            name: "ConsentCoreTests.HTTPTransport.response"
        ) {
            try result.get()
        }
        return HTTPTransportOperation(task: task)
    }
}

private actor ControlledConsentCoreHTTPTransport: HTTPTransport {
    private var requestCount = 0
    private var expectedRequestCount = 0
    private var requestCountContinuation: CheckedContinuation<Void, Never>?
    private var bufferedResponses: [Int: HTTPResponseSnapshot] = [:]
    private var responseContinuations: [Int: CheckedContinuation<HTTPResponseSnapshot, Never>] = [:]

    func start(
        snapshot _: HTTPRequestSnapshot,
        id _: HTTPRequestID
    ) async throws -> HTTPTransportOperation {
        let requestIndex = requestCount
        requestCount += 1
        if requestCount >= expectedRequestCount {
            requestCountContinuation?.resume()
            requestCountContinuation = nil
        }
        let task = Task<HTTPResponseSnapshot, Error>(
            name: "ConsentCoreTests.ControlledHTTPTransport.response"
        ) {
            await self.response(at: requestIndex)
        }
        return HTTPTransportOperation(task: task)
    }

    func waitUntilRequestCount(_ count: Int) async {
        guard requestCount < count else {
            return
        }
        expectedRequestCount = count
        await withCheckedContinuation { requestCountContinuation = $0 }
    }

    func completeRequest(at index: Int, with response: HTTPResponseSnapshot) {
        if let continuation = responseContinuations.removeValue(forKey: index) {
            continuation.resume(returning: response)
        } else {
            bufferedResponses[index] = response
        }
    }

    private func response(at index: Int) async -> HTTPResponseSnapshot {
        if let response = bufferedResponses.removeValue(forKey: index) {
            return response
        }
        return await withCheckedContinuation { responseContinuations[index] = $0 }
    }
}
