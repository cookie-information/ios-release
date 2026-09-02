import Foundation
import XCTest
@testable import MobileConsentsSDK

final class ConsentSynchronizationCoordinatorTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "MobileConsentsSDK.ConsentSynchronizationCoordinatorTests.\(UUID().uuidString)"
        userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
    }

    func testConcurrentSynchronizationsShareOneAuthorizationAndPost() async throws {
        let transport = ControlledSynchronizationTransport(responses: [.authorization, .controlledPost])
        let storage = try makeStorage()
        await makePending(storage: storage)
        let sut = makeSUT(storage: storage, transport: transport)

        let first = Task<Bool, Never>(
            name: "ConsentSynchronizationCoordinatorTests.concurrentFirst"
        ) {
            await sut.synchronizeIfNeeded()
        }
        await transport.waitForPostCount(1)
        let second = Task<Bool, Never>(
            name: "ConsentSynchronizationCoordinatorTests.concurrentSecond"
        ) {
            await sut.synchronizeIfNeeded()
        }

        await transport.completeControlledPost(statusCode: 200)
        let firstResult = await first.value
        let secondResult = await second.value

        let authorizations = await transport.authorizationCount()
        let posts = await transport.postCount()
        XCTAssertEqual(authorizations, 1)
        XCTAssertEqual(posts, 1)
        XCTAssertEqual(firstResult, secondResult)
        XCTAssertFalse(firstResult)
    }

    func testBusyClaimReturnsPendingWithoutStartingAnotherRequest() async throws {
        let firstTransport = ControlledSynchronizationTransport(
            responses: [.authorization, .controlledPost]
        )
        let secondTransport = ControlledSynchronizationTransport(responses: [])
        let firstStorage = try makeStorage()
        let secondStorage = try makeStorage()
        await makePending(storage: firstStorage)
        let first = makeSUT(storage: firstStorage, transport: firstTransport)
        let second = makeSUT(storage: secondStorage, transport: secondTransport)

        let activeSynchronization = Task<Bool, Never>(
            name: "ConsentSynchronizationCoordinatorTests.activeClaim"
        ) {
            await first.synchronizeIfNeeded()
        }
        await firstTransport.waitForPostCount(1)

        let pending = await second.synchronizeIfNeeded()
        let secondAuthorizationCount = await secondTransport.authorizationCount()
        let secondPostCount = await secondTransport.postCount()

        XCTAssertTrue(pending)
        XCTAssertEqual(secondAuthorizationCount, 0)
        XCTAssertEqual(secondPostCount, 0)

        await firstTransport.completeControlledPost(statusCode: 200)
        let activePending = await activeSynchronization.value
        XCTAssertFalse(activePending)
    }

    func testLatestPendingSnapshotWinsAfterActivePost() async throws {
        let transport = ControlledSynchronizationTransport(
            responses: [
                .authorization,
                .controlledPost,
                .immediatePost(200),
                .immediatePost(200),
            ]
        )
        let storage = try makeStorage()
        await savePending(storage: storage, version: "A")
        let sut = makeSUT(storage: storage, transport: transport)

        let synchronization = Task<Bool, Never>(
            name: "ConsentSynchronizationCoordinatorTests.latestPending"
        ) {
            await sut.synchronizeIfNeeded()
        }
        await transport.waitForPostCount(1)
        await savePending(storage: storage, version: "B")
        await savePending(storage: storage, version: "C")
        let latestTrigger = Task<Bool, Never>(
            name: "ConsentSynchronizationCoordinatorTests.latestPendingTrigger"
        ) {
            await sut.synchronizeIfNeeded()
        }

        let current = try storage.persistenceInspection(suiteName: suiteName)
        XCTAssertEqual(current.versionId, "C")
        XCTAssertFalse(current.consentsInSync)

        await transport.completeControlledPost(statusCode: 200)
        _ = await synchronization.value
        _ = await latestTrigger.value

        let versions = await transport.postVersions()
        let maximumActivePosts = await transport.maximumActivePosts()
        let completed = try storage.persistenceInspection(suiteName: suiteName)
        XCTAssertEqual(versions, ["A", "B", "C"])
        XCTAssertEqual(maximumActivePosts, 1)
        XCTAssertTrue(completed.consentsInSync)
    }

    func testTriggerDuringFailedAttemptDrainsLatestPendingConsentInSameWorker() async throws {
        let transport = ControlledSynchronizationTransport(
            responses: [
                .authorization,
                .controlledPost,
                .immediatePost(200),
                .immediatePost(200),
            ]
        )
        let storage = try makeStorage()
        await savePending(storage: storage, version: "A")
        let sut = makeSUT(storage: storage, transport: transport)

        let first = Task<Bool, Never>(
            name: "ConsentSynchronizationCoordinatorTests.failedFirst"
        ) {
            await sut.synchronizeIfNeeded()
        }
        await transport.waitForPostCount(1)
        await savePending(storage: storage, version: "B")
        let second = Task<Bool, Never>(
            name: "ConsentSynchronizationCoordinatorTests.failedSecond"
        ) {
            await sut.synchronizeIfNeeded()
        }
        await transport.completeControlledPost(statusCode: 500)

        let firstResult = await first.value
        let secondResult = await second.value
        let versions = await transport.postVersions()
        let snapshot = try storage.persistenceInspection(suiteName: suiteName)
        XCTAssertEqual(versions, ["A", "A", "B"])
        XCTAssertFalse(firstResult)
        XCTAssertFalse(secondResult)
        XCTAssertTrue(snapshot.consentsInSync)
    }

    func testFailedAttemptLeavesLatestFullSubmissionForNextTrigger() async throws {
        let transport = ControlledSynchronizationTransport(
            responses: [.authorization, .controlledPost, .immediatePost(200)]
        )
        let storage = try makeStorage()
        let submission = ConsentSubmissionValue(
            consentSolutionId: "solution",
            consentSolutionVersionId: "latest",
            processingPurposes: [ProcessingPurpose(consentItemId: "purpose", consentGiven: true, language: "pl")],
            customData: ["region": "EU"],
            userConsents: []
        )
        _ = storage.userId
        storage.recordPostResult(submission: submission, isInSync: false)
        let sut = makeSUT(storage: storage, transport: transport)

        let first = Task<Bool, Never>(
            name: "ConsentSynchronizationCoordinatorTests.failedAttempt"
        ) {
            await sut.synchronizeIfNeeded()
        }
        await transport.waitForPostCount(1)
        await transport.completeControlledPost(statusCode: 500)
        let pendingAfterFailure = await first.value
        let failedSnapshot = try storage.persistenceInspection(suiteName: suiteName)
        XCTAssertTrue(pendingAfterFailure)
        XCTAssertEqual(failedSnapshot.submission, submission)

        let pendingAfterRetry = await sut.synchronizeIfNeeded()
        let retryVersions = await transport.postVersions()
        XCTAssertFalse(pendingAfterRetry)
        XCTAssertEqual(retryVersions, ["latest", "latest"])
    }

    func testSynchronizationAfterFailurePostsAgain() async throws {
        let transport = ControlledSynchronizationTransport(
            responses: [.authorization, .controlledPost, .immediatePost(200)]
        )
        let storage = try makeStorage()
        await makePending(storage: storage)
        let sut = makeSUT(storage: storage, transport: transport)

        let first = Task<Bool, Never>(
            name: "ConsentSynchronizationCoordinatorTests.failureFirst"
        ) {
            await sut.synchronizeIfNeeded()
        }
        await transport.waitForPostCount(1)
        await transport.completeControlledPost(statusCode: 500)
        let firstResult = await first.value
        XCTAssertTrue(firstResult)

        _ = await sut.synchronizeIfNeeded()

        let authorizations = await transport.authorizationCount()
        let posts = await transport.postCount()
        XCTAssertEqual(authorizations, 1)
        XCTAssertEqual(posts, 2)
    }

    func testSynchronizationAfterSuccessDoesNotPostAgain() async throws {
        let transport = ControlledSynchronizationTransport(responses: [.authorization, .controlledPost])
        let storage = try makeStorage()
        await makePending(storage: storage)
        let sut = makeSUT(storage: storage, transport: transport)

        let first = Task<Bool, Never>(
            name: "ConsentSynchronizationCoordinatorTests.successFirst"
        ) {
            await sut.synchronizeIfNeeded()
        }
        await transport.waitForPostCount(1)
        await transport.completeControlledPost(statusCode: 200)
        let firstResult = await first.value
        XCTAssertFalse(firstResult)

        _ = await sut.synchronizeIfNeeded()

        let authorizations = await transport.authorizationCount()
        let posts = await transport.postCount()
        XCTAssertEqual(authorizations, 1)
        XCTAssertEqual(posts, 1)
    }

    func testCancellingOneWaiterDoesNotCancelSharedPost() async throws {
        let transport = ControlledSynchronizationTransport(responses: [.authorization, .controlledPost])
        let storage = try makeStorage()
        await makePending(storage: storage)
        let sut = makeSUT(storage: storage, transport: transport)

        let cancelled = Task<Void, Never>(
            name: "ConsentSynchronizationCoordinatorTests.cancelledWaiter"
        ) {
            _ = await sut.synchronizeIfNeeded()
        }
        await transport.waitForPostCount(1)
        let completing = Task<Void, Never>(
            name: "ConsentSynchronizationCoordinatorTests.completingWaiter"
        ) {
            _ = await sut.synchronizeIfNeeded()
        }
        cancelled.cancel()

        await transport.completeControlledPost(statusCode: 200)
        await completing.value
        await cancelled.value

        let authorizations = await transport.authorizationCount()
        let posts = await transport.postCount()
        let snapshot = try storage.persistenceInspection(suiteName: suiteName)
        XCTAssertEqual(authorizations, 1)
        XCTAssertEqual(posts, 1)
        XCTAssertTrue(snapshot.consentsInSync)
    }

    private func makeSUT(
        storage: ConsentStore,
        transport: any HTTPTransport
    ) -> ConsentSynchronizationCoordinator {
        let core = ConsentCore(
            solutionID: "solution",
            networkCore: NetworkCore(transport: transport, primaryLanguage: "EN"),
            store: storage,
            clientID: "id",
            clientSecret: "secret",
            platformInformation: { ["platform": "iOS"] }
        )
        return ConsentSynchronizationCoordinator(core: core)
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

    private func makePending(storage: ConsentStore) async {
        _ = storage.userId
        storage.recordPostResult(
            consents: [
                UserConsentValue(
                    consentItem: ConsentItem(
                        id: "consent",
                        required: false,
                        type: .functional,
                        translations: Translated(
                            translations: [
                                ConsentTranslation(
                                    language: "EN",
                                    shortText: "Consent",
                                    longText: "Consent details"
                                )
                            ],
                            primaryLanguage: nil
                        )
                    ),
                    isSelected: true
                ),
            ],
            versionId: "version",
            isInSync: false
        )
    }

    private func savePending(storage: ConsentStore, version: String) async {
        try! storage.savePending(
            submission: ConsentSubmissionValue(
                consentSolutionId: "solution",
                consentSolutionVersionId: version,
                processingPurposes: [],
                customData: nil,
                userConsents: []
            )
        )
    }
}

private actor ControlledSynchronizationTransport: HTTPTransport {
    enum Response: Sendable {
        case authorization
        case immediatePost(Int)
        case controlledPost
    }

    private var responses: [Response]
    private var authorizations = 0
    private var posts = 0
    private var activePosts = 0
    private var maximumPosts = 0
    private var versions: [String] = []
    private var postCountWaiters: [CheckedContinuation<Void, Never>] = []
    private var controlledPostWaiters: [CheckedContinuation<HTTPResponseSnapshot, Never>] = []
    private var bufferedPostResponses: [HTTPResponseSnapshot] = []

    init(responses: [Response]) {
        self.responses = responses
    }

    func start(
        snapshot: HTTPRequestSnapshot,
        id _: HTTPRequestID
    ) async throws -> HTTPTransportOperation {
        let response = responses.removeFirst()
        if snapshot.url.path.contains("oauth2") {
            authorizations += 1
        } else {
            posts += 1
            activePosts += 1
            maximumPosts = max(maximumPosts, activePosts)
            if let body = snapshot.body,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
               let version = json["universalConsentSolutionVersionId"] as? String {
                versions.append(version)
            }
            postCountWaiters.forEach { $0.resume() }
            postCountWaiters.removeAll()
        }

        let operation = Task<HTTPResponseSnapshot, Error>(
            name: "ConsentSynchronizationCoordinatorTests.ControlledSynchronizationTransport.operation"
        ) {
            let result = await self.response(for: response)
            if !snapshot.url.path.contains("oauth2") {
                self.finishPost()
            }
            try Task<Never, Never>.checkCancellation()
            return result
        }
        return HTTPTransportOperation(task: operation)
    }

    func authorizationCount() -> Int {
        authorizations
    }

    func postCount() -> Int {
        posts
    }

    func postVersions() -> [String] { versions }

    func maximumActivePosts() -> Int { maximumPosts }

    func waitForPostCount(_ expectedCount: Int) async {
        guard posts < expectedCount else {
            return
        }
        await withCheckedContinuation { postCountWaiters.append($0) }
    }

    func completeControlledPost(statusCode: Int) {
        let response = HTTPResponseSnapshot(url: nil, statusCode: statusCode)
        if controlledPostWaiters.isEmpty {
            bufferedPostResponses.append(response)
        } else {
            controlledPostWaiters.removeFirst().resume(returning: response)
        }
    }

    private func response(for response: Response) async -> HTTPResponseSnapshot {
        switch response {
        case .authorization:
            return HTTPResponseSnapshot(
                url: nil,
                statusCode: 200,
                body: Data(#"{"access_token":"token","expires_in":3600}"#.utf8)
            )
        case let .immediatePost(statusCode):
            return HTTPResponseSnapshot(url: nil, statusCode: statusCode)
        case .controlledPost:
            if !bufferedPostResponses.isEmpty {
                return bufferedPostResponses.removeFirst()
            }
            return await withCheckedContinuation { controlledPostWaiters.append($0) }
        }
    }

    private func finishPost() {
        activePosts -= 1
    }
}
