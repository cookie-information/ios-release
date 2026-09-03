import Foundation
import XCTest
@testable import MobileConsentsSDK

final class ConsentCorePostTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "MobileConsentsSDK.ConsentCorePostTests.\(UUID().uuidString)"
        userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    func testSaveConsentPersistsSubmissionLocallyWithoutNetworkRequest() async throws {
        let transport = ScriptedConsentTransport(responses: [])
        let storage = try makeStorage()
        let sut = makeSUT(storage: storage, transport: transport)

        try await sut.saveConsent(
            submission("local-version")
        )

        let snapshot = try storage.persistenceInspection(suiteName: suiteName)
        let kinds = await transport.kinds()
        XCTAssertEqual(snapshot.versionId, "local-version")
        XCTAssertFalse(snapshot.consentsInSync)
        XCTAssertTrue(kinds.isEmpty)
    }

    func testSaveConsentReplacesPendingSubmissionLocally() async throws {
        let transport = ScriptedConsentTransport(responses: [])
        let storage = try makeStorage()
        let sut = makeSUT(storage: storage, transport: transport)

        try await sut.saveConsent(submission("first"))
        try await sut.saveConsent(submission("second"))

        let snapshot = try storage.persistenceInspection(suiteName: suiteName)
        let kinds = await transport.kinds()
        XCTAssertEqual(snapshot.versionId, "second")
        XCTAssertFalse(snapshot.consentsInSync)
        XCTAssertTrue(kinds.isEmpty)
    }

    func testSynchronizeNextDeliversPendingSubmission() async throws {
        let transport = ScriptedConsentTransport(responses: [.auth("one"), .controlledPost])
        let storage = try makeStorage()
        let sut = makeSUT(storage: storage, transport: transport)

        try await savePendingConsent(
            submission("pending-version"),
            with: sut
        )
        let synchronization = Task<ConsentSynchronizationStep, Error> {
            try await sut.synchronizeNext()
        }

        await transport.waitForPostCount(1)
        await transport.completeControlledPost(statusCode: 200)
        let step = try await synchronization.value

        let kinds = await transport.kinds()
        let snapshot = try storage.persistenceInspection(suiteName: suiteName)
        assertProcessed(step)
        XCTAssertEqual(kinds, [.auth, .post])
        XCTAssertTrue(snapshot.consentsInSync)
    }

    func testSynchronizeNextReusesValidToken() async throws {
        let transport = ScriptedConsentTransport(
            responses: [.auth("one"), .post(200), .post(200)]
        )
        let storage = try makeStorage()
        let sut = makeSUT(storage: storage, transport: transport)

        try await savePendingConsent(
            submission("one"),
            with: sut
        )
        _ = try await sut.synchronizeNext()
        try await savePendingConsent(
            submission("two"),
            with: sut
        )
        _ = try await sut.synchronizeNext()

        let kinds = await transport.kinds()
        let snapshot = try storage.persistenceInspection(suiteName: suiteName)
        XCTAssertEqual(kinds, [.auth, .post, .post])
        XCTAssertEqual(snapshot.versionId, "two")
        XCTAssertTrue(snapshot.consentsInSync)
    }

    func testSynchronizeNextReauthorizesExpiredToken() async throws {
        let transport = ScriptedConsentTransport(
            responses: [.auth("one", 1), .post(200), .auth("two"), .post(200)]
        )
        let storage = try makeStorage()
        let sut = makeSUT(
            storage: storage,
            transport: transport,
            networkNow: { Date(timeIntervalSinceReferenceDate: 1) },
            now: { Date(timeIntervalSinceReferenceDate: 3) }
        )

        try await savePendingConsent(
            submission("one"),
            with: sut
        )
        _ = try await sut.synchronizeNext()
        try await savePendingConsent(
            submission("two"),
            with: sut
        )
        _ = try await sut.synchronizeNext()

        let headers = await transport.authorizationHeaders()
        XCTAssertEqual(headers, ["Bearer one", "Bearer two"])
    }

    func testSynchronizeNextReauthorizesAndRetriesOnceAfter401() async throws {
        let transport = ScriptedConsentTransport(
            responses: [.auth("one"), .post(401), .auth("two"), .post(204)]
        )
        let storage = try makeStorage()
        let sut = makeSUT(storage: storage, transport: transport)
        try await savePendingConsent(
            submission("pending"),
            with: sut
        )

        let step = try await sut.synchronizeNext()

        let headers = await transport.authorizationHeaders()
        let kinds = await transport.kinds()
        assertProcessed(step)
        XCTAssertEqual(headers, ["Bearer one", "Bearer two"])
        XCTAssertEqual(kinds, [.auth, .post, .auth, .post])
    }

    func testClearDuringAuthorizationPreventsInitialPostAndDoesNotRestoreProfile() async throws {
        let transport = ScriptedConsentTransport(responses: [.controlledAuth, .post(200)])
        let storage = try makeStorage()
        let sut = makeSUT(storage: storage, transport: transport)
        try await savePendingConsent(
            submission("pending"),
            with: sut
        )
        let synchronization = Task<ConsentSynchronizationStep, Error> {
            try await sut.synchronizeNext()
        }

        await transport.waitForAuthorizationCount(1)
        try storage.clearAll()
        await transport.completeControlledAuthorization(token: "one")
        let step = try await synchronization.value

        let kinds = await transport.kinds()
        let snapshot = try storage.persistenceInspection(suiteName: suiteName)
        assertIdle(step)
        XCTAssertEqual(kinds, [.auth])
        XCTAssertNil(snapshot.userId)
        XCTAssertNil(snapshot.versionId)
        XCTAssertNil(snapshot.submission)
        XCTAssertTrue(snapshot.consentsInSync)
    }

    func testClearDuringFirst401PreventsAuthorizationAndPostRetry() async throws {
        let transport = ScriptedConsentTransport(
            responses: [.auth("one"), .controlledPost, .auth("two"), .post(200)]
        )
        let storage = try makeStorage()
        let sut = makeSUT(storage: storage, transport: transport)
        try await savePendingConsent(
            submission("pending"),
            with: sut
        )
        let synchronization = Task<ConsentSynchronizationStep, Error> {
            try await sut.synchronizeNext()
        }

        await transport.waitForPostCount(1)
        try storage.clearAll()
        await transport.completeControlledPost(statusCode: 401)
        let step = try await synchronization.value

        let kinds = await transport.kinds()
        let snapshot = try storage.persistenceInspection(suiteName: suiteName)
        assertIdle(step)
        XCTAssertEqual(kinds, [.auth, .post])
        XCTAssertNil(snapshot.userId)
        XCTAssertNil(snapshot.submission)
    }

    func testSecond401ClearsTokenAndNextTriggerReauthorizes() async throws {
        let transport = ScriptedConsentTransport(
            responses: [
                .auth("one"),
                .post(401),
                .auth("two"),
                .post(401),
                .auth("three"),
                .post(200),
            ]
        )
        let storage = try makeStorage()
        let sut = makeSUT(storage: storage, transport: transport)
        try await savePendingConsent(
            submission("pending"),
            with: sut
        )

        do {
            _ = try await sut.synchronizeNext()
            XCTFail("Expected second 401")
        } catch let error as NetworkCoreError {
            XCTAssertEqual(error, .consentPostFailed(statusCode: 401, serverError: nil))
        }
        let pendingAfterFailure = try storage.persistenceInspection(suiteName: suiteName)
        XCTAssertFalse(pendingAfterFailure.consentsInSync)

        _ = try await sut.synchronizeNext()

        let headers = await transport.authorizationHeaders()
        XCTAssertEqual(headers, ["Bearer one", "Bearer two", "Bearer three"])
    }

    func testAuthorizationFailureLeavesPendingAndNextTriggerReauthorizes() async throws {
        let transport = ScriptedConsentTransport(
            responses: [.authFailure(500), .auth("two"), .post(200)]
        )
        let storage = try makeStorage()
        let sut = makeSUT(storage: storage, transport: transport)
        try await savePendingConsent(
            submission("pending"),
            with: sut
        )

        do {
            _ = try await sut.synchronizeNext()
            XCTFail("Expected authorization failure")
        } catch let error as NetworkCoreError {
            XCTAssertEqual(error, .unsuccessfulStatusCode(500))
        }
        let pendingAfterFailure = try storage.persistenceInspection(suiteName: suiteName)
        XCTAssertFalse(pendingAfterFailure.consentsInSync)

        _ = try await sut.synchronizeNext()

        let kinds = await transport.kinds()
        XCTAssertEqual(kinds, [.auth, .auth, .post])
    }

    func testSynchronizeNextAfterClearDoesNotPostOrCreateUserID() async throws {
        let transport = ScriptedConsentTransport(responses: [])
        let storage = try makeStorage()
        let sut = makeSUT(storage: storage, transport: transport)
        _ = storage.userId
        storage.recordPostResult(
            consents: [makeValue(id: "pending", isSelected: false)],
            versionId: "pending-version",
            isInSync: false
        )
        try storage.clearAll()

        let step = try await sut.synchronizeNext()

        let kinds = await transport.kinds()
        let snapshot = try storage.persistenceInspection(suiteName: suiteName)
        assertIdle(step)
        XCTAssertTrue(kinds.isEmpty)
        XCTAssertNil(snapshot.userId)
        XCTAssertNil(snapshot.versionId)
        XCTAssertTrue(snapshot.consentsInSync)
    }

    func testSynchronizeNextReturnsIdleWithoutAPendingConsent() async throws {
        let transport = ScriptedConsentTransport(responses: [])
        let storage = try makeStorage()
        let sut = makeSUT(storage: storage, transport: transport)

        let step = try await sut.synchronizeNext()
        let snapshot = try storage.persistenceInspection(suiteName: suiteName)

        assertIdle(step)
        XCTAssertTrue(snapshot.consentsInSync)
    }

    func testSynchronizeNextReturnsProcessedAfterSuccessfulPost() async throws {
        let transport = ScriptedConsentTransport(responses: [.auth("one"), .post(200)])
        let storage = try makeStorage()
        let sut = makeSUT(storage: storage, transport: transport)
        _ = storage.userId
        storage.recordPostResult(consents: [makeValue(id: "pending", isSelected: true)], versionId: "pending", isInSync: false)

        let step = try await sut.synchronizeNext()

        assertProcessed(step)
    }

    func testSynchronizeNextKeepsPendingConsentAfterFailedPost() async throws {
        let transport = ScriptedConsentTransport(responses: [.auth("one"), .post(500)])
        let storage = try makeStorage()
        let sut = makeSUT(storage: storage, transport: transport)
        _ = storage.userId
        storage.recordPostResult(consents: [makeValue(id: "pending", isSelected: true)], versionId: "pending", isInSync: false)

        do {
            _ = try await sut.synchronizeNext()
            XCTFail("Expected post failure")
        } catch let error as NetworkCoreError {
            XCTAssertEqual(error, .consentPostFailed(statusCode: 500, serverError: nil))
        }

        let snapshot = try storage.persistenceInspection(suiteName: suiteName)
        XCTAssertFalse(snapshot.consentsInSync)
    }

    func testSynchronizeNextLeavesNewerVersionForNextStep() async throws {
        let transport = ScriptedConsentTransport(
            responses: [.auth("one"), .controlledPost, .post(200)]
        )
        let storage = try makeStorage()
        let sut = makeSUT(storage: storage, transport: transport)
        _ = storage.userId
        storage.recordPostResult(consents: [makeValue(id: "old", isSelected: true)], versionId: "old", isInSync: false)
        let synchronization = Task<ConsentSynchronizationStep, Error>(name: "ConsentCorePostTests.newerPending") {
            try await sut.synchronizeNext()
        }

        await transport.waitForPostCount(1)
        storage.recordPostResult(consents: [makeValue(id: "new", isSelected: false)], versionId: "new", isInSync: false)
        await transport.completeControlledPost(statusCode: 200)

        let firstStep = try await synchronization.value
        let snapshot = try storage.persistenceInspection(suiteName: suiteName)
        let versionsAfterFirstStep = await transport.postVersions()
        assertProcessed(firstStep)
        XCTAssertFalse(snapshot.consentsInSync)
        XCTAssertEqual(versionsAfterFirstStep, ["old"])

        let secondStep = try await sut.synchronizeNext()
        let versionsAfterSecondStep = await transport.postVersions()
        assertProcessed(secondStep)
        XCTAssertEqual(versionsAfterSecondStep, ["old", "new"])
    }

    func testReplacingActiveVersionUploadsReplacementRevisionAfterAttemptFinishes() async throws {
        let transport = ScriptedConsentTransport(
            responses: [.auth("one"), .controlledPost, .post(200)]
        )
        let storage = try makeStorage()
        let sut = makeSUT(storage: storage, transport: transport)
        try await savePendingConsent(
            submission(
                "version",
                userConsents: [makeValue(id: "original", isSelected: true)]
            ),
            with: sut
        )
        let synchronization = Task<ConsentSynchronizationStep, Error>(
            name: "ConsentCorePostTests.replacementRevision"
        ) {
            try await sut.synchronizeNext()
        }

        await transport.waitForPostCount(1)
        try await savePendingConsent(
            submission(
                "version",
                userConsents: [makeValue(id: "replacement", isSelected: false)]
            ),
            with: sut
        )
        await transport.completeControlledPost(statusCode: 200)

        let firstStep = try await synchronization.value
        let snapshotAfterFirstStep = try storage.persistenceInspection(suiteName: suiteName)
        let versionsAfterFirstStep = await transport.postVersions()
        assertProcessed(firstStep)
        XCTAssertFalse(snapshotAfterFirstStep.consentsInSync)
        XCTAssertEqual(versionsAfterFirstStep, ["version"])

        let secondStep = try await sut.synchronizeNext()
        let versionsAfterSecondStep = await transport.postVersions()
        assertProcessed(secondStep)
        XCTAssertEqual(versionsAfterSecondStep, ["version", "version"])
        let snapshot = try storage.persistenceInspection(suiteName: suiteName)
        XCTAssertEqual(snapshot.values.keys.sorted(), ["replacement"])
        XCTAssertEqual(snapshot.values["replacement"]?.isSelected, false)
        XCTAssertTrue(snapshot.consentsInSync)
    }

    func testReplacingActiveVersionRemainsPendingAfterOldAttemptFails() async throws {
        let transport = ScriptedConsentTransport(
            responses: [.auth("one"), .controlledPost, .post(200)]
        )
        let storage = try makeStorage()
        let sut = makeSUT(storage: storage, transport: transport)
        try await savePendingConsent(
            submission(
                "version",
                userConsents: [makeValue(id: "original", isSelected: true)]
            ),
            with: sut
        )
        let firstAttempt = Task<ConsentSynchronizationStep, Error>(
            name: "ConsentCorePostTests.failedReplacementRevision"
        ) {
            try await sut.synchronizeNext()
        }

        await transport.waitForPostCount(1)
        try await savePendingConsent(
            submission(
                "version",
                userConsents: [makeValue(id: "replacement", isSelected: false)]
            ),
            with: sut
        )
        await transport.completeControlledPost(statusCode: 500)

        do {
            _ = try await firstAttempt.value
            XCTFail("Expected post failure")
        } catch let error as NetworkCoreError {
            XCTAssertEqual(
                error,
                .consentPostFailed(statusCode: 500, serverError: nil)
            )
        }
        let pendingSnapshot = try storage.persistenceInspection(suiteName: suiteName)
        XCTAssertEqual(pendingSnapshot.values.keys.sorted(), ["replacement"])
        XCTAssertFalse(pendingSnapshot.consentsInSync)

        let step = try await sut.synchronizeNext()
        let postVersions = await transport.postVersions()
        assertProcessed(step)
        XCTAssertEqual(postVersions, ["version", "version"])
        XCTAssertTrue(
            try storage.persistenceInspection(suiteName: suiteName).consentsInSync
        )
    }

    func testReclaimedClaimPreventsOldWorkerFromRetryingAfterUnauthorizedResponse() async throws {
        let domain = ConsentStorageDomain.suite(suiteName)
        let partition = ConsentPartitionID(
            solutionID: "solution",
            clientID: "id",
            clientSecret: "secret"
        )
        let firstStorage = ConsentStore(
            database: ConsentDatabase(path: domain.consentDatabasePath),
            domain: domain,
            partition: partition,
            now: { Date(timeIntervalSince1970: 1_000) }
        )
        let secondStorage = ConsentStore(
            database: ConsentDatabase(path: domain.consentDatabasePath),
            domain: domain,
            partition: partition,
            now: { Date(timeIntervalSince1970: 1_061) }
        )
        let firstTransport = ScriptedConsentTransport(
            responses: [.auth("first"), .controlledPost]
        )
        let secondTransport = ScriptedConsentTransport(
            responses: [.auth("second"), .post(200)]
        )
        let firstCore = makeSUT(storage: firstStorage, transport: firstTransport)
        let secondCore = makeSUT(storage: secondStorage, transport: secondTransport)
        try await savePendingConsent(
            submission("version"),
            with: firstCore
        )
        let firstSynchronization = Task<ConsentSynchronizationStep, Error>(
            name: "ConsentCorePostTests.staleClaim"
        ) {
            try await firstCore.synchronizeNext()
        }
        await firstTransport.waitForPostCount(1)

        let secondStep = try await secondCore.synchronizeNext()
        await firstTransport.completeControlledPost(statusCode: 401)

        let firstStep = try await firstSynchronization.value
        let firstRequestKinds = await firstTransport.kinds()
        let secondRequestKinds = await secondTransport.kinds()
        assertProcessed(secondStep)
        assertIdle(firstStep)
        XCTAssertEqual(firstRequestKinds, [.auth, .post])
        XCTAssertEqual(secondRequestKinds, [.auth, .post])
        XCTAssertTrue(
            try firstStorage.persistenceInspection(suiteName: suiteName).consentsInSync
        )
    }

    private func makeSUT(
        storage: ConsentStore,
        transport: any HTTPTransport,
        networkNow: @escaping @Sendable () -> Date = { Date() },
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> ConsentCore {
        ConsentCore(solutionID: "solution", networkCore: NetworkCore(transport: transport, primaryLanguage: "EN", now: networkNow), store: storage, clientID: "id", clientSecret: "secret", platformInformation: { ["platform": "iOS"] }, now: now)
    }

    private func makeStorage() throws -> ConsentStore {
        try XCTUnwrap(
            ConsentStore(
                suiteName: suiteName,
                solutionID: "solution",
                clientID: "id",
                clientSecret: "secret"
            )
        )
    }

    private func savePendingConsent(
        _ submission: ConsentSubmissionValue,
        with core: ConsentCore
    ) async throws {
        try await core.saveConsent(
            submission
        )
    }

    private func assertProcessed(
        _ step: ConsentSynchronizationStep,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .processed = step else {
            XCTFail("Expected processed synchronization step", file: file, line: line)
            return
        }
    }

    private func assertIdle(
        _ step: ConsentSynchronizationStep,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .idle = step else {
            XCTFail("Expected idle synchronization step", file: file, line: line)
            return
        }
    }

    private func submission(
        _ version: String,
        userConsents: [UserConsentValue] = []
    ) -> ConsentSubmissionValue {
        ConsentSubmissionValue(
            consentSolutionId: "solution",
            consentSolutionVersionId: version,
            processingPurposes: [],
            customData: nil,
            userConsents: userConsents
        )
    }

    private func makeValue(id: String, isSelected: Bool) -> UserConsentValue {
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
                        )
                    ],
                    primaryLanguage: nil
                )
            ),
            isSelected: isSelected
        )
    }

    private func waitForPending(_ storage: ConsentStore, versionID: String) async throws {
        for _ in 0 ..< 100 {
            let snapshot = try storage.persistenceInspection(suiteName: suiteName)
            if snapshot.versionId == versionID, !snapshot.consentsInSync {
                return
            }
            await Task<Never, Never>.yield()
        }
        XCTFail("Pending submission \(versionID) was not recorded")
    }
}

private actor ScriptedConsentTransport: HTTPTransport {
    enum Kind: Equatable, Sendable { case auth, post }
    enum Response: Sendable {
        case auth(String, TimeInterval = 3600)
        case authFailure(Int)
        case controlledAuth
        case post(Int)
        case controlledPost
    }
    private var responses: [Response]
    private var requestKinds: [Kind] = []
    private var headers: [String] = []
    private var versions: [String] = []
    private var activePosts = 0
    private var maxPosts = 0
    private var postWaiters: [CheckedContinuation<Void, Never>] = []
    private var authorizationCount = 0
    private var authorizationWaiters: [CheckedContinuation<Void, Never>] = []
    private var controlled: [CheckedContinuation<HTTPResponseSnapshot, Never>] = []
    private var bufferedControlled: [HTTPResponseSnapshot] = []
    private var controlledAuthorizations: [CheckedContinuation<HTTPResponseSnapshot, Never>] = []
    private var bufferedControlledAuthorizations: [HTTPResponseSnapshot] = []

    init(responses: [Response]) { self.responses = responses }

    func start(snapshot: HTTPRequestSnapshot, id _: HTTPRequestID) async throws -> HTTPTransportOperation {
        let kind: Kind = snapshot.url.path.contains("oauth2") ? .auth : .post
        let response = responses.removeFirst()
        requestKinds.append(kind)
        if kind == .auth {
            authorizationCount += 1
            authorizationWaiters.forEach { $0.resume() }; authorizationWaiters.removeAll()
        } else {
            headers.append(snapshot.headers["Authorization"] ?? "")
            if let body = snapshot.body, let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any], let version = json["universalConsentSolutionVersionId"] as? String { versions.append(version) }
            activePosts += 1; maxPosts = max(maxPosts, activePosts)
            postWaiters.forEach { $0.resume() }; postWaiters.removeAll()
        }
        let task = Task<HTTPResponseSnapshot, Error>(name: "ConsentCorePostTests.ScriptedTransport.operation") {
            let response = await self.value(for: response)
            if kind == .post { self.finishedPost() }
            try Task<Never, Never>.checkCancellation()
            return response
        }
        return HTTPTransportOperation(task: task)
    }

    func kinds() -> [Kind] { requestKinds }
    func authorizationHeaders() -> [String] { headers }
    func postVersions() -> [String] { versions }
    func maximumActivePosts() -> Int { maxPosts }
    func waitForPostCount(_ count: Int) async { while versions.count < count { await withCheckedContinuation { postWaiters.append($0) } } }
    func waitForAuthorizationCount(_ count: Int) async { while authorizationCount < count { await withCheckedContinuation { authorizationWaiters.append($0) } } }
    func completeControlledAuthorization(token: String, expiresIn: TimeInterval = 3600) {
        let response = authorizationResponse(token: token, expiresIn: expiresIn)
        if controlledAuthorizations.isEmpty {
            bufferedControlledAuthorizations.append(response)
        } else {
            controlledAuthorizations.removeFirst().resume(returning: response)
        }
    }
    func completeControlledPost(statusCode: Int) {
        let response = HTTPResponseSnapshot(url: nil, statusCode: statusCode, body: nil)
        if controlled.isEmpty {
            bufferedControlled.append(response)
        } else {
            controlled.removeFirst().resume(returning: response)
        }
    }
    private func finishedPost() { activePosts -= 1 }
    private func value(for response: Response) async -> HTTPResponseSnapshot {
        switch response {
        case let .auth(token, expiresIn): return authorizationResponse(token: token, expiresIn: expiresIn)
        case let .authFailure(statusCode): return HTTPResponseSnapshot(url: nil, statusCode: statusCode, body: Data("{}".utf8))
        case .controlledAuth:
            if !bufferedControlledAuthorizations.isEmpty {
                return bufferedControlledAuthorizations.removeFirst()
            }
            return await withCheckedContinuation { controlledAuthorizations.append($0) }
        case let .post(statusCode): return HTTPResponseSnapshot(url: nil, statusCode: statusCode, body: nil)
        case .controlledPost:
            if !bufferedControlled.isEmpty {
                return bufferedControlled.removeFirst()
            }
            return await withCheckedContinuation { controlled.append($0) }
        }
    }

    private func authorizationResponse(token: String, expiresIn: TimeInterval) -> HTTPResponseSnapshot {
        HTTPResponseSnapshot(url: nil, statusCode: 200, body: Data("{\"access_token\":\"\(token)\",\"expires_in\":\(expiresIn)}".utf8))
    }
}

private actor ConsentCorePostTestGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var occupiedWaiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            occupiedWaiters.forEach { $0.resume() }
            occupiedWaiters.removeAll()
        }
    }

    func waitUntilOccupied() async {
        guard continuation == nil else {
            return
        }
        await withCheckedContinuation { occupiedWaiters.append($0) }
    }

    func open() {
        continuation?.resume()
        continuation = nil
    }
}
