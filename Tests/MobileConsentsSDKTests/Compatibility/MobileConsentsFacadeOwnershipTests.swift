import Foundation
import UIKit
import XCTest
@testable import MobileConsentsSDK

@MainActor
final class MobileConsentsFacadeOwnershipTests: XCTestCase {
    func testPublicPostCompletesAfterLocalSaveAndSchedulesAutomaticPost() async throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let transport = ScriptedOwnershipHTTPTransport(responses: [.auth, .controlledPost])
        let client = try makeClient(suiteName: suiteName, transport: transport)
        let reader = try makeReader(suiteName: suiteName)
        let consent = makeConsent(version: "success-version", valueID: "success-value")
        let completion = expectation(description: "Post completion")
        completion.assertForOverFulfill = true

        client.postConsent(consent) { error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(error)
            let snapshot = reader.snapshot()
            XCTAssertEqual(snapshot.versionId, consent.consentSolutionVersionId)
            XCTAssertEqual(snapshot.values, ["success-value": UserConsentValue(consent.userConsents[0])])
            XCTAssertFalse(snapshot.consentsInSync)
            completion.fulfill()
        }

        await fulfillment(of: [completion], timeout: 2)
        await transport.waitForPostCount(1)
        let posts = await transport.posts()
        XCTAssertEqual(posts.map(\.version), [consent.consentSolutionVersionId])
        let authorizationCount = await transport.authorizationCount()
        XCTAssertEqual(authorizationCount, 1)
        await transport.completeControlledPost(statusCode: 200)
    }

    func testBackgroundPostCompletesOnMainExactlyOnce() async throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let client = try makeClient(
            suiteName: suiteName,
            transport: ScriptedOwnershipHTTPTransport(responses: [])
        )
        let reader = try makeReader(suiteName: suiteName)
        let backgroundCall = expectation(description: "Background post call")
        let completion = expectation(description: "Post completion")
        completion.assertForOverFulfill = true
        let invoker = BackgroundFacadePostInvoker(
            client: client,
            consent: makeConsent(version: "background", valueID: "background"),
            backgroundCall: backgroundCall
        ) { error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(error)
            completion.fulfill()
        }

        invoker.start()

        await fulfillment(of: [backgroundCall, completion], timeout: 2)
        XCTAssertEqual(reader.snapshot().versionId, "background")
    }

    func testAsyncPostReturnsWithPendingSnapshotBeforeControlledWorkerCompletes() async throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let transport = ScriptedOwnershipHTTPTransport(responses: [.auth, .controlledPost])
        let client = try makeClient(suiteName: suiteName, transport: transport)
        let reader = try makeReader(suiteName: suiteName)
        let consent = makeConsent(version: "async-version", valueID: "async-value")
        let returned = expectation(description: "Async post returns after local save")

        Task<Void, Error>(
            name: "MobileConsentsFacadeOwnershipTests.asyncPost"
        ) { @MainActor in
            try await client.postConsent(consent)
            returned.fulfill()
        }

        await fulfillment(of: [returned], timeout: 2)
        XCTAssertEqual(reader.snapshot().versionId, consent.consentSolutionVersionId)
        XCTAssertFalse(reader.snapshot().consentsInSync)
        await transport.waitForPostCount(1)
        await transport.completeControlledPost(statusCode: 200)
        await waitForSynchronization(of: client, observedBy: reader)
    }

    func testCancelledAsyncPostDoesNotPersistConsent() async throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let client = try makeClient(
            suiteName: suiteName,
            transport: ScriptedOwnershipHTTPTransport(responses: [])
        )
        let reader = try makeReader(suiteName: suiteName)
        let task = Task<Void, Error>(
            name: "MobileConsentsFacadeOwnershipTests.cancelledAsyncPost"
        ) { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            try await client.postConsent(
                makeConsent(version: "cancelled", valueID: "cancelled")
            )
        }

        do {
            try await task.value
            XCTFail("Expected cancellation")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .cancelled)
        }
        let snapshot = reader.snapshot()
        XCTAssertNil(snapshot.userId)
        XCTAssertNil(snapshot.versionId)
        XCTAssertTrue(snapshot.values.isEmpty)
    }

    func testSQLiteClaimSerializesActiveWorkersAndKeepsLatestFacadeSubmission() async throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let transport = ScriptedOwnershipHTTPTransport(
            responses: [
                .auth,
                .auth,
                .auth,
                .controlledPost,
                .controlledPost,
                .controlledPost,
            ]
        )
        let first = try makeClient(
            suiteName: suiteName,
            transport: transport
        )
        let second = try makeClient(
            suiteName: suiteName,
            transport: transport
        )
        let third = try makeClient(
            suiteName: suiteName,
            transport: transport
        )
        let firstCallback = expectation(description: "First facade callback")
        let secondCallback = expectation(description: "Second facade callback")
        let thirdCallback = expectation(description: "Third facade callback")
        let firstPostStarted = expectation(
            forNotification: ScriptedOwnershipHTTPTransport.postStartedNotification,
            object: nil
        )

        first.postConsent(makeConsent(version: "A", valueID: "A")) { error in
            XCTAssertNil(error)
            firstCallback.fulfill()
        }
        await fulfillment(of: [firstCallback, firstPostStarted], timeout: 2)

        second.postConsent(makeConsent(version: "B", valueID: "B")) { error in
            XCTAssertNil(error)
            secondCallback.fulfill()
        }
        third.postConsent(makeConsent(version: "C", valueID: "C")) { error in
            XCTAssertNil(error)
            thirdCallback.fulfill()
        }
        await fulfillment(of: [secondCallback, thirdCallback], timeout: 2)
        let maximumActivePostsBeforeCompletion = await transport.maximumActivePosts()
        XCTAssertEqual(maximumActivePostsBeforeCompletion, 1)

        let secondPostStarted = expectation(
            forNotification: ScriptedOwnershipHTTPTransport.postStartedNotification,
            object: nil
        )
        await transport.completeControlledPost(statusCode: 200)
        await fulfillment(of: [secondPostStarted], timeout: 2)
        let thirdPostStarted = expectation(
            forNotification: ScriptedOwnershipHTTPTransport.postStartedNotification,
            object: nil
        )
        await transport.completeControlledPost(statusCode: 200)
        await fulfillment(of: [thirdPostStarted], timeout: 2)
        let postVersions = await transport.postVersions()
        let maximumActivePosts = await transport.maximumActivePosts()
        XCTAssertEqual(postVersions.first, "A")
        XCTAssertEqual(Set(postVersions.dropFirst()), Set(["B", "C"]))
        XCTAssertEqual(maximumActivePosts, 1)
        await transport.completeControlledPost(statusCode: 200)
        await waitForSynchronized(
            try makeReader(suiteName: suiteName)
        )
    }

    func testSameVersionReplacementWaitsForActivePostAcrossInstances() async throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let firstTransport = ScriptedOwnershipHTTPTransport(
            responses: [.auth, .controlledPost, .controlledPost]
        )
        let secondTransport = ScriptedOwnershipHTTPTransport(responses: [])
        let first = try makeClient(
            suiteName: suiteName,
            transport: firstTransport
        )
        let second = try makeClient(
            suiteName: suiteName,
            transport: secondTransport
        )
        let firstCallback = expectation(description: "First revision saved")
        let replacementCallback = expectation(description: "Replacement revision saved")

        first.postConsent(makeConsent(version: "version", valueID: "original")) { error in
            XCTAssertNil(error)
            firstCallback.fulfill()
        }
        await fulfillment(of: [firstCallback], timeout: 2)
        await firstTransport.waitForPostCount(1)

        second.postConsent(makeConsent(version: "version", valueID: "replacement")) { error in
            XCTAssertNil(error)
            replacementCallback.fulfill()
        }
        await fulfillment(of: [replacementCallback], timeout: 2)
        let maximumActivePostsBeforeCompletion = await firstTransport.maximumActivePosts()
        let secondPosts = await secondTransport.posts()
        XCTAssertEqual(maximumActivePostsBeforeCompletion, 1)
        XCTAssertTrue(secondPosts.isEmpty)

        await firstTransport.completeControlledPost(statusCode: 200)
        await firstTransport.waitForPostCount(2)
        let maximumActivePosts = await firstTransport.maximumActivePosts()
        let processingPurposeIDs = await firstTransport.posts().map(\.processingPurposeIDs)
        XCTAssertEqual(maximumActivePosts, 1)
        XCTAssertEqual(
            processingPurposeIDs,
            [["original"], ["replacement"]]
        )
        await firstTransport.completeControlledPost(statusCode: 200)

        let reader = try makeReader(suiteName: suiteName)
        await waitForSynchronization(of: first, observedBy: reader)
        XCTAssertEqual(reader.snapshot().values.keys.sorted(), ["replacement"])
    }

    func testDifferentConfigurationsKeepIndependentDecisionsAndWorkers() async throws {
        let suiteName = uniqueSuiteName()
        let firstTransport = ScriptedOwnershipHTTPTransport(
            responses: [.auth, .controlledPost]
        )
        let secondTransport = ScriptedOwnershipHTTPTransport(
            responses: [.auth, .controlledPost]
        )
        let first = try makeClient(
            suiteName: suiteName,
            transport: firstTransport,
            clientID: "client-a",
            clientSecret: "secret-a",
            solutionID: "solution-a"
        )
        let second = try makeClient(
            suiteName: suiteName,
            transport: secondTransport,
            clientID: "client-b",
            clientSecret: "secret-b",
            solutionID: "solution-b"
        )
        let firstLocalSave = expectation(description: "First configuration saves locally")
        firstLocalSave.assertForOverFulfill = true
        let secondLocalSave = expectation(description: "Second configuration saves locally")
        secondLocalSave.assertForOverFulfill = true
        let postsStarted = expectation(
            forNotification: ScriptedOwnershipHTTPTransport.postStartedNotification,
            object: nil
        )
        postsStarted.expectedFulfillmentCount = 2

        first.postConsent(
            makeConsent(version: "version-a", valueID: "value-a", solutionID: "solution-a")
        ) { error in
            XCTAssertNil(error)
            let reader = ConsentStore(
                suiteName: suiteName,
                solutionID: "solution-a",
                clientID: "client-a",
                clientSecret: "secret-a"
            )
            XCTAssertEqual(try? reader?.readSnapshot().versionId, "version-a")
            firstLocalSave.fulfill()
        }
        second.postConsent(
            makeConsent(version: "version-b", valueID: "value-b", solutionID: "solution-b")
        ) { error in
            XCTAssertNil(error)
            let reader = ConsentStore(
                suiteName: suiteName,
                solutionID: "solution-b",
                clientID: "client-b",
                clientSecret: "secret-b"
            )
            XCTAssertEqual(try? reader?.readSnapshot().versionId, "version-b")
            secondLocalSave.fulfill()
        }

        await fulfillment(
            of: [firstLocalSave, secondLocalSave, postsStarted],
            timeout: 2
        )

        let firstReader = try makeReader(
            suiteName: suiteName,
            solutionID: "solution-a",
            clientID: "client-a",
            clientSecret: "secret-a"
        )
        let secondReader = try makeReader(
            suiteName: suiteName,
            solutionID: "solution-b",
            clientID: "client-b",
            clientSecret: "secret-b"
        )
        XCTAssertEqual(firstReader.snapshot().versionId, "version-a")
        XCTAssertEqual(secondReader.snapshot().versionId, "version-b")
        let firstPostVersions = await firstTransport.postVersions()
        let secondPostVersions = await secondTransport.postVersions()
        let firstRequests = await firstTransport.requests()
        let secondRequests = await secondTransport.requests()
        XCTAssertEqual(firstPostVersions, ["version-a"])
        XCTAssertEqual(secondPostVersions, ["version-b"])
        XCTAssertEqual(firstRequests, [.authorization, .post])
        XCTAssertEqual(secondRequests, [.authorization, .post])

        await firstTransport.completeControlledPost(statusCode: 200)
        await secondTransport.completeControlledPost(statusCode: 200)
        _ = first
        _ = second
    }

    func testConfigurationsWithDifferentSecretsKeepIndependentDecisionsAndWorkers() async throws {
        let suiteName = uniqueSuiteName()
        let postActivity = OwnershipPostActivity()
        let firstTransport = ScriptedOwnershipHTTPTransport(
            responses: [.auth, .controlledPost],
            postActivity: postActivity
        )
        let secondTransport = ScriptedOwnershipHTTPTransport(
            responses: [.auth, .controlledPost],
            postActivity: postActivity
        )
        let first = try makeClient(
            suiteName: suiteName,
            transport: firstTransport,
            clientID: "client-id",
            clientSecret: "secret-a",
            solutionID: "solution-id"
        )
        let second = try makeClient(
            suiteName: suiteName,
            transport: secondTransport,
            clientID: "client-id",
            clientSecret: "secret-b",
            solutionID: "solution-id"
        )
        let firstLocalSave = expectation(description: "First secret saves locally")
        let secondLocalSave = expectation(description: "Second secret saves locally")

        first.postConsent(makeConsent(version: "version-a", valueID: "value-a")) { error in
            XCTAssertNil(error)
            firstLocalSave.fulfill()
        }
        second.postConsent(makeConsent(version: "version-b", valueID: "value-b")) { error in
            XCTAssertNil(error)
            secondLocalSave.fulfill()
        }

        await fulfillment(of: [firstLocalSave, secondLocalSave], timeout: 2)
        let didStartFirstPost = await firstTransport.waitForPostCount(1, withinYields: 100_000)
        let didStartSecondPost = await secondTransport.waitForPostCount(1, withinYields: 100_000)

        XCTAssertTrue(didStartFirstPost)
        XCTAssertTrue(didStartSecondPost)
        let firstReader = try makeReader(
            suiteName: suiteName,
            clientSecret: "secret-a"
        )
        let secondReader = try makeReader(
            suiteName: suiteName,
            clientSecret: "secret-b"
        )
        XCTAssertEqual(firstReader.snapshot().versionId, "version-a")
        XCTAssertEqual(firstReader.snapshot().values.mapValues(\.consentItem.id), ["value-a": "value-a"])
        XCTAssertEqual(secondReader.snapshot().versionId, "version-b")
        XCTAssertEqual(secondReader.snapshot().values.mapValues(\.consentItem.id), ["value-b": "value-b"])
        let maximumActivePosts = await postActivity.maximumActivePosts()
        let firstPostVersions = await firstTransport.postVersions()
        let secondPostVersions = await secondTransport.postVersions()
        let firstAuthorizationCredentials = await firstTransport.authorizationCredentials()
        let secondAuthorizationCredentials = await secondTransport.authorizationCredentials()
        XCTAssertEqual(maximumActivePosts, 2)
        XCTAssertEqual(firstPostVersions, ["version-a"])
        XCTAssertEqual(secondPostVersions, ["version-b"])
        XCTAssertEqual(
            firstAuthorizationCredentials,
            [.init(clientID: "client-id", clientSecret: "secret-a")]
        )
        XCTAssertEqual(
            secondAuthorizationCredentials,
            [.init(clientID: "client-id", clientSecret: "secret-b")]
        )

        await firstTransport.completeControlledPost(statusCode: 200)
        await secondTransport.completeControlledPost(statusCode: 200)
        await waitForSynchronization(of: first, observedBy: firstReader)
        await waitForSynchronization(of: second, observedBy: secondReader)

        XCTAssertTrue(firstReader.snapshot().consentsInSync)
        XCTAssertTrue(secondReader.snapshot().consentsInSync)
        _ = first
        _ = second
    }

    func testDeinitializingFirstClientDuringInitializationPostDoesNotDuplicateUpload() async throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let storage = try makeStorage(suiteName: suiteName)
        _ = storage.userId
        storage.recordPostResult(
            consents: [makeValue(id: "pending", isSelected: true)],
            versionId: "pending-version",
            isInSync: false, solutionID: "solution-id"
        )
        let transport = ScriptedOwnershipHTTPTransport(responses: [.auth, .controlledPost])
        let firstPostStartedExpectation = expectation(
            forNotification: ScriptedOwnershipHTTPTransport.postStartedNotification,
            object: nil
        )
        var first: MobileConsents? = try makeClient(
            suiteName: suiteName,
            transport: transport
        )
        await fulfillment(of: [firstPostStartedExpectation], timeout: 2)
        let second = try makeClient(
            suiteName: suiteName,
            transport: transport
        )

        XCTAssertNotNil(first)
        first = nil
        await drainMainActor()

        let postsBeforeCompletion = await transport.posts()
        XCTAssertEqual(postsBeforeCompletion.count, 1)

        await transport.completeControlledPost(statusCode: 200)
        await waitForSynchronized(try makeReader(suiteName: suiteName))

        let posts = await transport.posts()
        XCTAssertEqual(posts.count, 1)
        let maximumActivePosts = await transport.maximumActivePosts()
        XCTAssertEqual(maximumActivePosts, 1)
        _ = second
    }

    func testPublicPostCompletesLocallyBeforeBackendFailureLeavesSubmissionPending() async throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let transport = ScriptedOwnershipHTTPTransport(responses: [.auth, .controlledPost])
        let client = try makeClient(suiteName: suiteName, transport: transport)
        let reader = try makeReader(suiteName: suiteName)
        let consent = makeConsent(version: "failed-version", valueID: "failed-value")
        let completion = expectation(description: "Local post completion")
        completion.assertForOverFulfill = true

        client.postConsent(consent) { error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(error)
            let snapshot = reader.snapshot()
            XCTAssertEqual(snapshot.versionId, consent.consentSolutionVersionId)
            XCTAssertEqual(snapshot.values, ["failed-value": UserConsentValue(consent.userConsents[0])])
            XCTAssertFalse(snapshot.consentsInSync)
            completion.fulfill()
        }

        await fulfillment(of: [completion], timeout: 2)
        await transport.waitForPostCount(1)
        await transport.completeControlledPost(statusCode: 500)
        await waitForPending(reader, versionID: consent.consentSolutionVersionId)
    }

    func testAsyncRemoveStoredConsentsPreventsLateResponseFromRestoringConsent() async throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let storage = try makeStorage(suiteName: suiteName)
        _ = storage.userId
        storage.recordPostResult(
            consents: [makeValue(id: "pending", isSelected: true)],
            versionId: "pending-version",
            isInSync: false, solutionID: "solution-id"
        )
        let transport = ScriptedOwnershipHTTPTransport(responses: [.auth, .controlledPost])
        let client = try makeClient(
            suiteName: suiteName,
            transport: transport
        )
        let reader = try makeReader(suiteName: suiteName)

        await transport.waitForPostCount(1)
        try await client.clearStoredConsents()

        let removedSnapshot = reader.snapshot()
        XCTAssertNil(removedSnapshot.userId)
        XCTAssertTrue(removedSnapshot.values.isEmpty)
        XCTAssertTrue(removedSnapshot.consentsInSync)

        await transport.completeControlledPost(statusCode: 200)
        let pendingAfterLateResponse = await client.synchronizeIfNeeded()

        let requests = await transport.requests()
        let finalSnapshot = reader.snapshot()
        XCTAssertFalse(pendingAfterLateResponse)
        XCTAssertEqual(requests, [.authorization, .post])
        XCTAssertNil(finalSnapshot.userId)
        XCTAssertTrue(finalSnapshot.values.isEmpty)
        XCTAssertTrue(finalSnapshot.consentsInSync)
    }

    func testActiveRetryFinishesBeforeWorkerSendsLatestPublicSubmission() async throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let storage = try makeStorage(suiteName: suiteName)
        let reader = try makeReader(suiteName: suiteName)
        let retryValue = makeValue(id: "retry-value", isSelected: true)
        _ = storage.userId
        storage.recordPostResult(consents: [retryValue], versionId: "retry-version", isInSync: false, solutionID: "solution-id")
        let transport = ScriptedOwnershipHTTPTransport(responses: [.auth, .controlledPost, .controlledPost])
        let client = try makeClient(suiteName: suiteName, transport: transport)
        let completion = expectation(description: "Normal post completion")
        completion.assertForOverFulfill = true

        callSynchronousSynchronization(on: client)
        await transport.waitForPostCount(1)
        client.postConsent(makeConsent(version: "normal-version", valueID: "normal-value")) { error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(error)
            completion.fulfill()
        }
        await transport.completeControlledPost(statusCode: 200)
        await transport.waitForPostCount(2)
        await transport.completeControlledPost(statusCode: 200)

        await fulfillment(of: [completion], timeout: 2)
        await waitForSynchronization(of: client, observedBy: reader)
        let postVersions = await transport.postVersions()
        let authorizationCount = await transport.authorizationCount()
        let maximumActivePosts = await transport.maximumActivePosts()
        let posts = await transport.posts()
        XCTAssertEqual(postVersions, ["retry-version", "normal-version"])
        XCTAssertEqual(authorizationCount, 1)
        XCTAssertEqual(maximumActivePosts, 1)
        let retryPost = try XCTUnwrap(posts.first)
        XCTAssertEqual(retryPost.processingPurposeIDs, [retryValue.consentItem.id])
        let snapshot = reader.snapshot()
        XCTAssertEqual(snapshot.versionId, "normal-version")
        XCTAssertTrue(snapshot.consentsInSync)
    }

    func testSynchronizeIfNeededDoesNothingWhenStoredConsentsAreInSync() async throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let storage = try makeStorage(suiteName: suiteName)
        storage.recordPostResult(consents: [makeValue(id: "saved", isSelected: true)], versionId: "version", isInSync: true, solutionID: "solution-id")
        let transport = ScriptedOwnershipHTTPTransport(responses: [])
        let client = try makeClient(suiteName: suiteName, transport: transport)

        callSynchronousSynchronization(on: client)
        await drainMainActor()

        let requests = await transport.requests()
        XCTAssertTrue(requests.isEmpty)
    }

    func testManualSynchronizeIfNeededRetriesPendingConsent() async throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let storage = try makeStorage(suiteName: suiteName)
        _ = storage.userId
        storage.recordPostResult(
            consents: [makeValue(id: "pending", isSelected: true)],
            versionId: "pending-version",
            isInSync: false, solutionID: "solution-id"
        )
        let transport = ScriptedOwnershipHTTPTransport(responses: [.auth, .controlledPost])
        let client = try makeClient(suiteName: suiteName, transport: transport)

        callSynchronousSynchronization(on: client)
        await transport.waitForPostCount(1)
        await transport.completeControlledPost(statusCode: 200)
        await waitForSynchronization(
            of: client,
            observedBy: try makeReader(suiteName: suiteName)
        )

        let requests = await transport.requests()
        XCTAssertEqual(requests, [.authorization, .post])
    }

    func testManualSynchronizeIfNeededWithoutPendingConsentDoesNotRequest() async throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let transport = ScriptedOwnershipHTTPTransport(responses: [])
        let client = try makeClient(suiteName: suiteName, transport: transport)

        callSynchronousSynchronization(on: client)
        await drainMainActor()

        let requests = await transport.requests()
        XCTAssertTrue(requests.isEmpty)
    }

    func testPublicRemoveStoredConsentsClearsProfileAndPendingDecision() async throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let storage = try makeStorage(suiteName: suiteName)
        let reader = try makeReader(suiteName: suiteName)
        _ = storage.userId
        storage.recordPostResult(consents: [makeValue(id: "stored", isSelected: true)], versionId: "kept-version", isInSync: false, solutionID: "solution-id")
        let client = try makeClient(suiteName: suiteName, transport: ScriptedOwnershipHTTPTransport(responses: []))
        let originalUserID = try await client.getUserId()

        client.removeStoredConsents()

        let snapshot = reader.snapshot()
        XCTAssertNil(snapshot.userId)
        XCTAssertTrue(snapshot.values.isEmpty)
        XCTAssertNil(snapshot.versionId)
        XCTAssertTrue(snapshot.consentsInSync)
        let regeneratedUserID = try await client.getUserId()
        XCTAssertNotEqual(regeneratedUserID, originalUserID)
        XCTAssertEqual(regeneratedUserID, reader.userId)
    }

    func testSyncAndAsyncRemovalBothClearEveryConfigurationInProfile() async throws {
        let syncSuiteName = uniqueSuiteName()
        let asyncSuiteName = uniqueSuiteName()
        let syncDefaults = try makeUserDefaults(suiteName: syncSuiteName)
        let asyncDefaults = try makeUserDefaults(suiteName: asyncSuiteName)
        defer {
            syncDefaults.removePersistentDomain(forName: syncSuiteName)
            asyncDefaults.removePersistentDomain(forName: asyncSuiteName)
        }
        let syncClient = try makeClient(
            suiteName: syncSuiteName,
            transport: ScriptedOwnershipHTTPTransport(responses: [])
        )
        let asyncClient = try makeClient(
            suiteName: asyncSuiteName,
            transport: ScriptedOwnershipHTTPTransport(responses: [])
        )
        let syncReaders = try seedTwoConfigurations(in: syncSuiteName)
        let asyncReaders = try seedTwoConfigurations(in: asyncSuiteName)

        syncClient.removeStoredConsents()
        try await asyncClient.clearStoredConsents()

        for reader in syncReaders + asyncReaders {
            let snapshot = reader.snapshot()
            XCTAssertNil(snapshot.userId)
            XCTAssertNil(snapshot.versionId)
            XCTAssertTrue(snapshot.values.isEmpty)
            XCTAssertTrue(snapshot.consentsInSync)
        }
    }

    func testSynchronizeIfNeededAfterBackendFailureAndRemoveDoesNotPostForNewUserID() async throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let transport = ScriptedOwnershipHTTPTransport(responses: [.auth, .controlledPost])
        let client = try makeClient(suiteName: suiteName, transport: transport)
        let reader = try makeReader(suiteName: suiteName)
        let completion = expectation(description: "Local post completion")
        completion.assertForOverFulfill = true

        client.postConsent(makeConsent(version: "failed-version", valueID: "failed-value")) { error in
            XCTAssertNil(error)
            completion.fulfill()
        }
        await fulfillment(of: [completion], timeout: 2)
        await transport.waitForPostCount(1)
        await transport.completeControlledPost(statusCode: 500)

        client.removeStoredConsents()
    let newUserID = try await client.getUserId()
        callSynchronousSynchronization(on: client)
        await drainMainActor()

        let requests = await transport.requests()
        let snapshot = reader.snapshot()
        XCTAssertEqual(requests, [.authorization, .post])
        XCTAssertEqual(snapshot.userId, newUserID)
        XCTAssertTrue(snapshot.values.isEmpty)
        XCTAssertNil(snapshot.versionId)
        XCTAssertTrue(snapshot.consentsInSync)
    }

    func testRemoveDoesNotRetroactivelyChangeLocalCallbackAndFuturePostWrites() async throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let storage = try makeStorage(suiteName: suiteName)
        storage.recordPostResult(consents: [], versionId: "previous-version", isInSync: false, solutionID: "solution-id")
        let transport = ScriptedOwnershipHTTPTransport(
            responses: [.auth, .controlledPost, .post(statusCode: 200)]
        )
        let client = try makeClient(suiteName: suiteName, transport: transport)
        let reader = try makeReader(suiteName: suiteName)
        let staleConsent = makeConsent(version: "stale-version", valueID: "stale-value")
        let staleCompletion = expectation(description: "Stale post completion")
        staleCompletion.assertForOverFulfill = true
        var staleCallbackCount = 0

        client.postConsent(staleConsent) { error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(error)
            staleCallbackCount += 1
            let snapshot = reader.snapshot()
            XCTAssertNotNil(snapshot.userId)
            XCTAssertEqual(snapshot.versionId, "stale-version")
            XCTAssertEqual(snapshot.values.mapValues(\.consentItem.id), ["stale-value": "stale-value"])
            XCTAssertFalse(snapshot.consentsInSync)
            staleCompletion.fulfill()
        }
        await fulfillment(of: [staleCompletion], timeout: 2)
        await transport.waitForPostCount(1)
        let initialPosts = await transport.posts()
        let oldUserID = try XCTUnwrap(initialPosts.first?.userID)

        client.removeStoredConsents()

        XCTAssertNil(reader.snapshot().userId)

        await transport.completeControlledPost(statusCode: 200)
        XCTAssertEqual(staleCallbackCount, 1)

        let nextCompletion = expectation(description: "Future post completion")
        nextCompletion.assertForOverFulfill = true
        client.postConsent(makeConsent(version: "next-version", valueID: "next-value")) { error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(error)
            nextCompletion.fulfill()
        }
        await fulfillment(of: [nextCompletion], timeout: 2)
        await waitForSynchronization(of: client, observedBy: reader)
        await transport.waitForPostCount(2)

        let posts = await transport.posts()
        let authorizationCount = await transport.authorizationCount()
        let finalSnapshot = reader.snapshot()
        XCTAssertEqual(posts.map(\.version), ["previous-version", "next-version"])
        XCTAssertNotEqual(posts.last?.userID, oldUserID)
        XCTAssertEqual(authorizationCount, 1)
        XCTAssertEqual(finalSnapshot.versionId, "next-version")
        XCTAssertEqual(finalSnapshot.values.mapValues(\.consentItem.id), ["next-value": "next-value"])
        XCTAssertTrue(finalSnapshot.consentsInSync)
    }

    func testShowIfNeededUsesMatchingStoredConsentsWithoutErrorOrStorageMutation() async throws {
        let fixture = try fixture()
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let storage = try makeStorage(suiteName: suiteName)
        let reader = try makeReader(suiteName: suiteName)
        let storedValue = UserConsentValue(UserConsent(consentItem: fixture.consentItems[0], isSelected: true))
        storage.recordPostResult(consents: [storedValue], versionId: fixture.versionId, isInSync: true, solutionID: "solution-id")
        let transport = ScriptedOwnershipHTTPTransport(responses: [.fetch(data: fixture.data, statusCode: 200)])
        let client = try makeClient(suiteName: suiteName, transport: transport)
        let completion = expectation(description: "Stored consent completion")
        completion.assertForOverFulfill = true
        var errorCount = 0

        client.showPrivacyPopUpIfNeeded(completion: { consents in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(consents.map(\.consentItem.id), [storedValue.consentItem.id])
            XCTAssertEqual(consents.map(\.isSelected), [true])
            completion.fulfill()
        }, errorHandler: { _ in
            errorCount += 1
        })

        await fulfillment(of: [completion], timeout: 2)
        XCTAssertEqual(errorCount, 0)
        XCTAssertEqual(reader.snapshot().values, [storedValue.consentItem.id: storedValue])
    }

    func testBackgroundShowIfNeededCompletesOnMainExactlyOnce() async throws {
        let fixture = try fixture()
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let storage = try makeStorage(suiteName: suiteName)
        let storedValue = UserConsentValue(
            UserConsent(consentItem: fixture.consentItems[0], isSelected: true)
        )
        storage.recordPostResult(
            consents: [storedValue],
            versionId: fixture.versionId,
            isInSync: true,
            solutionID: "solution-id"
        )
        let client = try makeClient(
            suiteName: suiteName,
            transport: ScriptedOwnershipHTTPTransport(
                responses: [.fetch(data: fixture.data, statusCode: 200)]
            )
        )
        let backgroundCall = expectation(description: "Background popup call")
        let completion = expectation(description: "Popup completion")
        completion.assertForOverFulfill = true
        let invoker = BackgroundShowIfNeededInvoker(
            client: client,
            backgroundCall: backgroundCall
        ) { consents in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(consents.map(\.consentItem.id), [storedValue.consentItem.id])
            completion.fulfill()
        }

        invoker.start()

        await fulfillment(of: [backgroundCall, completion], timeout: 2)
    }

    func testAsyncShowIfNeededReturnsMatchingStoredConsentsWithoutPresentation() async throws {
        let fixture = try fixture()
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let storage = try makeStorage(suiteName: suiteName)
        let storedValue = UserConsentValue(
            UserConsent(consentItem: fixture.consentItems[0], isSelected: true)
        )
        storage.recordPostResult(
            consents: [storedValue],
            versionId: fixture.versionId,
            isInSync: true,
            solutionID: "solution-id"
        )
        let client = try makeClient(
            suiteName: suiteName,
            transport: ScriptedOwnershipHTTPTransport(
                responses: [.fetch(data: fixture.data, statusCode: 200)]
            )
        )

        let consents = try await client.showPrivacyPopUpIfNeeded(
            customViewType: nil,
            onViewController: nil,
            animated: false,
            ignoreVersionChanges: false
        )

        XCTAssertEqual(consents.map(\.consentItem.id), [storedValue.consentItem.id])
        XCTAssertEqual(consents.map(\.isSelected), [true])
    }

    func testShowIfNeededUsesStoredConsentsWrittenByOnePointSixWithoutPresentingPopup() async throws {
        let fixture = try fixture()
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let legacyConsentID = "one-point-six-consent"
        let legacyConsentData = Data(
            """
            {
              "consentItem": {
                "universalConsentItemId": "one-point-six-consent",
                "required": false,
                "type": "functional",
                "translations": [
                  {
                    "language": "EN",
                    "shortText": "Legacy consent",
                    "longText": "Legacy consent details"
                  }
                ]
                            },
                            "isSelected": true
            }
            """.utf8
        )
        userDefaults.set("one-point-six-user", forKey: "com.MobileConsents.userIdKey")
        userDefaults.set(
            [legacyConsentID: legacyConsentData],
            forKey: "com.MobileConsents.consentsKey"
        )
        userDefaults.set(
            fixture.versionId,
            forKey: "com.MobileConsents.consentsVersionIdKey"
        )
        userDefaults.set(true, forKey: "com.MobileConsents.consentsInSync")
        let reader = try makeReader(suiteName: suiteName)
        let transport = ScriptedOwnershipHTTPTransport(
            responses: [.fetch(data: fixture.data, statusCode: 200)]
        )
        let client = try makeClient(suiteName: suiteName, transport: transport)
        let completion = expectation(description: "Stored 1.6 consent completion")
        completion.assertForOverFulfill = true
        let popupConstructed = expectation(description: "Popup is not constructed")
        popupConstructed.isInverted = true
        let observer = OwnershipPopupObserver(expectation: popupConstructed)
        NotificationCenter.default.addObserver(
            observer,
            selector: #selector(OwnershipPopupObserver.popupConstructed),
            name: OwnershipRecordingPopup.constructedNotification,
            object: nil
        )
        defer { NotificationCenter.default.removeObserver(observer) }

        client.showPrivacyPopUpIfNeeded(
            customViewType: OwnershipRecordingPopup.self,
            completion: { consents in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(consents.count, 1)
                XCTAssertEqual(consents.first?.consentItem.id, legacyConsentID)
                XCTAssertEqual(consents.first?.isSelected, true)
                completion.fulfill()
            },
            errorHandler: { error in XCTFail("Unexpected error: \(error)") }
        )

        await fulfillment(of: [completion], timeout: 2)
        await fulfillment(of: [popupConstructed], timeout: 0.1)
        let snapshot = reader.snapshot()
        XCTAssertEqual(snapshot.userId, "one-point-six-user")
        XCTAssertEqual(snapshot.versionId, fixture.versionId)
        XCTAssertEqual(snapshot.values[legacyConsentID]?.isSelected, true)
        XCTAssertTrue(snapshot.consentsInSync)
    }

    func testShowIfNeededIgnoresVersionChangesWhenRequested() async throws {
        let fixture = try fixture()
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let storage = try makeStorage(suiteName: suiteName)
        let reader = try makeReader(suiteName: suiteName)
        let storedValue = UserConsentValue(UserConsent(consentItem: fixture.consentItems[0], isSelected: false))
        storage.recordPostResult(consents: [storedValue], versionId: "old-version", isInSync: true, solutionID: "solution-id")
        let transport = ScriptedOwnershipHTTPTransport(responses: [.fetch(data: fixture.data, statusCode: 200)])
        let client = try makeClient(suiteName: suiteName, transport: transport)
        let completion = expectation(description: "Ignored version completion")
        completion.assertForOverFulfill = true

        client.showPrivacyPopUpIfNeeded(ignoreVersionChanges: true, completion: { consents in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(consents.map(\.consentItem.id), [storedValue.consentItem.id])
            completion.fulfill()
        }, errorHandler: { error in
            XCTFail("Unexpected error: \(error)")
        })

        await fulfillment(of: [completion], timeout: 2)
        XCTAssertEqual(reader.snapshot().values, [storedValue.consentItem.id: storedValue])
        XCTAssertEqual(reader.snapshot().versionId, "old-version")
    }

    func testShowIfNeededFetchFailureCallsErrorHandlerWithoutCompletionOrStorageMutation() async throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let storage = try makeStorage(suiteName: suiteName)
        let reader = try makeReader(suiteName: suiteName)
        let storedValue = makeValue(id: "untouched", isSelected: true)
        storage.recordPostResult(consents: [storedValue], versionId: "untouched-version", isInSync: true, solutionID: "solution-id")
        let transport = ScriptedOwnershipHTTPTransport(responses: [.fetch(data: nil, statusCode: 600)])
        let client = try makeClient(suiteName: suiteName, transport: transport)
        let completion = expectation(description: "Fetch failure completion")
        completion.isInverted = true
        let errorHandler = expectation(description: "Fetch failure error")
        errorHandler.assertForOverFulfill = true

        client.showPrivacyPopUpIfNeeded(completion: { consents in
            XCTAssertTrue(Thread.isMainThread)
            completion.fulfill()
        }, errorHandler: { error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(
                (error as? NetworkResponseError)?.errorDescription,
                NetworkResponseError.outdated.errorDescription
            )
            errorHandler.fulfill()
        })

        await fulfillment(of: [errorHandler, completion], timeout: 2)
        XCTAssertEqual(reader.snapshot().values, [storedValue.consentItem.id: storedValue])
        XCTAssertEqual(reader.snapshot().versionId, "untouched-version")
        XCTAssertTrue(reader.snapshot().consentsInSync)
    }

    func testAsyncShowIfNeededPropagatesFetchFailureWithoutStorageMutation() async throws {
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let storage = try makeStorage(suiteName: suiteName)
        let reader = try makeReader(suiteName: suiteName)
        let storedValue = makeValue(id: "untouched", isSelected: true)
        storage.recordPostResult(
            consents: [storedValue],
            versionId: "untouched-version",
            isInSync: true,
            solutionID: "solution-id"
        )
        let client = try makeClient(
            suiteName: suiteName,
            transport: ScriptedOwnershipHTTPTransport(
                responses: [.fetch(data: nil, statusCode: 600)]
            )
        )

        do {
            _ = try await client.showPrivacyPopUpIfNeeded(
                customViewType: nil,
                onViewController: nil,
                animated: false,
                ignoreVersionChanges: false
            )
            XCTFail("Expected fetch failure")
        } catch let error as NetworkResponseError {
            XCTAssertEqual(error.errorDescription, NetworkResponseError.outdated.errorDescription)
        }
        XCTAssertEqual(reader.snapshot().values, [storedValue.consentItem.id: storedValue])
        XCTAssertEqual(reader.snapshot().versionId, "untouched-version")
        XCTAssertTrue(reader.snapshot().consentsInSync)
    }

    func testAsyncShowIfNeededPresentsFetchedSolutionAndReturnsDismissalValues() async throws {
        let fixture = try fixture()
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let transport = ScriptedOwnershipHTTPTransport(
            responses: [
                .fetch(data: fixture.data, statusCode: 200),
                .auth,
                .controlledPost,
            ]
        )
        let client = try makeClient(suiteName: suiteName, transport: transport)
        let popupPresented = expectation(description: "Async popup presented")
        let dataLoaded = expectation(description: "Async popup loaded")
        let presentationCompleted = expectation(description: "Async popup completed")
        let presenter = OwnershipRecordingViewController(expectation: popupPresented)
        var receivedConsents = [UserConsent]()
        Task<Void, Never>(
            name: "MobileConsentsFacadeOwnershipTests.asyncPopupPresentation"
        ) { @MainActor in
            do {
                receivedConsents = try await client.showPrivacyPopUpIfNeeded(
                    customViewType: ActionOwnershipPopup.self,
                    onViewController: presenter,
                    animated: false,
                    ignoreVersionChanges: false
                )
            } catch {
                XCTFail("Expected popup success, got \(error)")
            }
            presentationCompleted.fulfill()
        }

        await fulfillment(of: [popupPresented], timeout: 2)
        let popup = try XCTUnwrap(presenter.recordedPopup as? ActionOwnershipPopup)
        popup.onDataLoaded = { dataLoaded.fulfill() }
        popup.load()
        await fulfillment(of: [dataLoaded], timeout: 2)
        popup.acceptAll()
        await fulfillment(of: [presentationCompleted], timeout: 2)

        XCTAssertEqual(
            receivedConsents.map(\.consentItem.id).sorted(),
            fixture.consentItems.filter { $0.type != .privacyPolicy }.map(\.id).sorted()
        )
        XCTAssertTrue(receivedConsents.map(\.isSelected).allSatisfy { $0 })
        XCTAssertEqual(presenter.dismissCount, 1)
        await transport.waitForPostCount(1)
        await transport.completeControlledPost(statusCode: 200)
    }

    func testShowIfNeededVersionMismatchPreservesStoredStateBeforeConstructingCustomPopup() async throws {
        let fixture = try fixture(versionID: "new-version")
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let storage = try makeStorage(suiteName: suiteName)
        let reader = try makeReader(suiteName: suiteName)
        _ = storage.userId
        storage.recordPostResult(consents: [makeValue(id: "old", isSelected: true)], versionId: "old-version", isInSync: true, solutionID: "solution-id")
        let transport = ScriptedOwnershipHTTPTransport(responses: [.fetch(data: fixture.data, statusCode: 200)])
        let client = try makeClient(suiteName: suiteName, transport: transport)
        let popupConstructed = expectation(description: "Custom popup constructed")
        let observer = OwnershipPopupObserver(expectation: popupConstructed)
        NotificationCenter.default.addObserver(observer, selector: #selector(OwnershipPopupObserver.popupConstructed), name: OwnershipRecordingPopup.constructedNotification, object: nil)
        defer { NotificationCenter.default.removeObserver(observer) }

        client.showPrivacyPopUpIfNeeded(
            customViewType: OwnershipRecordingPopup.self,
            completion: { _ in },
            errorHandler: { error in XCTFail("Unexpected error: \(error)") }
        )

        await fulfillment(of: [popupConstructed], timeout: 2)
        let snapshot = reader.snapshot()
        XCTAssertNotNil(snapshot.userId)
        XCTAssertEqual(snapshot.values.mapValues(\.consentItem.id), ["old": "old"])
        XCTAssertEqual(snapshot.versionId, "old-version")
        XCTAssertTrue(snapshot.consentsInSync)
        observer.popup?.finish()
    }

    func testShowIfNeededVersionMismatchPresentsFetchedSolutionWithoutRefetching() async throws {
        let fixture = try fixture(versionID: "new-version")
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let transport = ScriptedOwnershipHTTPTransport(
            responses: [
                .fetch(data: fixture.data, statusCode: 200),
                .fetch(data: fixture.data, statusCode: 200),
            ]
        )
        let client = try makeClient(suiteName: suiteName, transport: transport)
        let popupPresented = expectation(description: "Fetched solution popup presented")
        popupPresented.assertForOverFulfill = true
        let dataLoaded = expectation(description: "Fetched solution data loaded")
        let presentingViewController = OwnershipRecordingViewController(expectation: popupPresented)

        client.showPrivacyPopUpIfNeeded(
            customViewType: LoadingOwnershipPopup.self,
            onViewController: presentingViewController,
            animated: false,
            completion: { _ in },
            errorHandler: { error in XCTFail("Unexpected error: \(error)") }
        )

        await fulfillment(of: [popupPresented], timeout: 2)
        let popup = try XCTUnwrap(presentingViewController.recordedPopup as? LoadingOwnershipPopup)
        popup.onDataLoaded = { dataLoaded.fulfill() }
        await fulfillment(of: [dataLoaded], timeout: 2)
        let data = try XCTUnwrap(popup.loadedData)
        XCTAssertEqual(data.title, fixture.solution.templateTexts.privacyCenterTitle.primaryTranslation().text)
        XCTAssertEqual(data.acceptAllButtonTitle, fixture.solution.templateTexts.acceptAllButton.primaryTranslation().text)
        XCTAssertEqual(
            data.privacyPolicyLongtext,
            fixture.solution.consentItems.first { $0.type == .privacyPolicy }?.translations.primaryTranslation().longText
        )
        XCTAssertEqual(presentingViewController.presentedAnimated, false)
        let requests = await transport.requests()
        XCTAssertEqual(requests, [.fetch])
    }

    func testCustomPopupDismissalCallbackAndPendingWorkerFollowLocalSave() async throws {
        let fixture = try fixture()
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let transport = ScriptedOwnershipHTTPTransport(
            responses: [.fetch(data: fixture.data, statusCode: 200), .auth, .controlledPost]
        )
        let client = try makeClient(suiteName: suiteName, transport: transport)
        let reader = try makeReader(suiteName: suiteName)
        let popupPresented = expectation(description: "Custom popup presented")
        let dataLoaded = expectation(description: "Custom popup loaded")
        let callback = expectation(description: "Custom popup callback")
        callback.assertForOverFulfill = true
        let errorHandler = expectation(description: "Custom popup error handler")
        errorHandler.isInverted = true
        let presenter = OwnershipRecordingViewController(expectation: popupPresented)
        var completionCount = 0
        var errorCount = 0

        client.showPrivacyPopUp(
            customViewType: ActionOwnershipPopup.self,
            onViewController: presenter,
            animated: false,
            completion: { _ in
                completionCount += 1
                presenter.recordUserCallback()
                callback.fulfill()
            },
            errorHandler: { _ in
                errorCount += 1
                errorHandler.fulfill()
            }
        )

        await fulfillment(of: [popupPresented], timeout: 2)
        let popup = try XCTUnwrap(presenter.recordedPopup as? ActionOwnershipPopup)
        popup.onDataLoaded = { dataLoaded.fulfill() }
        popup.load()
        await fulfillment(of: [dataLoaded], timeout: 2)

        popup.acceptAll()
        await fulfillment(of: [callback], timeout: 2)
        await transport.waitForPostCount(1)
        XCTAssertEqual(presenter.events, ["userCallback", "dismissalCompletion"])
        await waitForPending(reader, versionID: fixture.versionId)

        let snapshot = reader.snapshot()
        XCTAssertEqual(presenter.dismissCount, 1)
        XCTAssertEqual(snapshot.versionId, fixture.versionId)
        XCTAssertEqual(
            snapshot.values.mapValues(\.isSelected),
            Dictionary(uniqueKeysWithValues: fixture.consentItems.filter { $0.type != .privacyPolicy }.map { ($0.id, true) })
        )
        XCTAssertFalse(snapshot.consentsInSync)
        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(errorCount, 0)

        await transport.completeControlledPost(statusCode: 500)
        await fulfillment(of: [errorHandler], timeout: 0.1)
        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(errorCount, 0)
    }

    func testCustomPopupBackendResultDoesNotChangeCompletedCallbackOrPendingSnapshot() async throws {
        for statusCode in [200, 500] {
            let fixture = try fixture()
            let suiteName = uniqueSuiteName()
            let userDefaults = try makeUserDefaults(suiteName: suiteName)
            defer { userDefaults.removePersistentDomain(forName: suiteName) }
            let transport = ScriptedOwnershipHTTPTransport(
                responses: [.fetch(data: fixture.data, statusCode: 200), .auth, .controlledPost]
            )
            let client = try makeClient(suiteName: suiteName, transport: transport)
            let reader = try makeReader(suiteName: suiteName)
            let popupPresented = expectation(description: "Custom popup presented for status \(statusCode)")
            let dataLoaded = expectation(description: "Custom popup loaded for status \(statusCode)")
            let callback = expectation(description: "Public callback for status \(statusCode)")
            callback.assertForOverFulfill = true
            let errorHandler = expectation(description: "Error handler for status \(statusCode)")
            errorHandler.isInverted = true
            let presenter = OwnershipRecordingViewController(expectation: popupPresented)
            var completionCount = 0
            var errorCount = 0

            client.showPrivacyPopUp(
                customViewType: ActionOwnershipPopup.self,
                onViewController: presenter,
                animated: false,
                completion: { _ in
                    completionCount += 1
                    callback.fulfill()
                },
                errorHandler: { _ in
                    errorCount += 1
                    errorHandler.fulfill()
                }
            )

            await fulfillment(of: [popupPresented], timeout: 2)
            let popup = try XCTUnwrap(presenter.recordedPopup as? ActionOwnershipPopup)
            popup.onDataLoaded = { dataLoaded.fulfill() }
            popup.load()
            await fulfillment(of: [dataLoaded], timeout: 2)

            popup.acceptAll()
            await fulfillment(of: [callback], timeout: 2)
            await transport.waitForPostCount(1)
            await waitForPending(reader, versionID: fixture.versionId)
            XCTAssertEqual(completionCount, 1)
            XCTAssertEqual(errorCount, 0)
            await transport.completeControlledPost(statusCode: statusCode)
            await fulfillment(of: [errorHandler], timeout: 0.1)

            XCTAssertEqual(completionCount, 1)
            XCTAssertEqual(errorCount, 0)
            XCTAssertEqual(reader.snapshot().consentsInSync, statusCode == 200)
        }
    }

    func testShowIfNeededFetchesAndPresentsWhileRetryIsPendingAndPreservesMismatchedStorage() async throws {
        let fixture = try fixture(versionID: "new-version")
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let storage = try makeStorage(suiteName: suiteName)
        let reader = try makeReader(suiteName: suiteName)
        let transport = ScriptedOwnershipHTTPTransport(
            responses: [
                .fetch(data: fixture.data, statusCode: 200),
                .auth,
                .controlledPost,
            ]
        )
        let client = try makeClient(suiteName: suiteName, transport: transport)
        await drainMainActor()
        _ = await client.synchronizeIfNeeded()
        _ = storage.userId
        storage.recordPostResult(
            consents: [makeValue(id: "old", isSelected: true)],
            versionId: "old-version",
            isInSync: false, solutionID: "solution-id"
        )
        let retryPostStarted = expectation(description: "Retry post started")
        let retryObserver = OwnershipPopupObserver(expectation: retryPostStarted)
        NotificationCenter.default.addObserver(
            retryObserver,
            selector: #selector(OwnershipPopupObserver.popupConstructed),
            name: ScriptedOwnershipHTTPTransport.postStartedNotification,
            object: nil
        )
        defer { NotificationCenter.default.removeObserver(retryObserver) }
        let popupConstructed = expectation(description: "Custom popup constructed while retry is pending")
        let observer = OwnershipPopupObserver(expectation: popupConstructed)
        NotificationCenter.default.addObserver(
            observer,
            selector: #selector(OwnershipPopupObserver.popupConstructed),
            name: OwnershipRecordingPopup.constructedNotification,
            object: nil
        )
        defer { NotificationCenter.default.removeObserver(observer) }

        client.showPrivacyPopUpIfNeeded(
            customViewType: OwnershipRecordingPopup.self,
            completion: { _ in },
            errorHandler: { error in XCTFail("Unexpected error: \(error)") }
        )
        await fulfillment(of: [retryPostStarted, popupConstructed], timeout: 2)

        let requestsBeforeRetryCompletion = await transport.requests()
        assertSingleFetchAuthorizationAndPost(requestsBeforeRetryCompletion)

        await transport.completeControlledPost(statusCode: 500)
        await drainMainActor()

        let requests = await transport.requests()
        let snapshot = reader.snapshot()
        assertSingleFetchAuthorizationAndPost(requests)
        XCTAssertNotNil(snapshot.userId)
        XCTAssertEqual(snapshot.values.mapValues(\.consentItem.id), ["old": "old"])
        XCTAssertEqual(snapshot.versionId, "old-version")
        XCTAssertFalse(snapshot.consentsInSync)
        observer.popup?.finish()
    }

    func testShowIfNeededFetchesDecisionWhileAcceptedPostWorkerIsActive() async throws {
        let fixture = try fixture(versionID: "new-version")
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let reader = try makeReader(suiteName: suiteName)
        let transport = ScriptedOwnershipHTTPTransport(
            responses: [
                .auth,
                .controlledPost,
                .fetch(data: fixture.data, statusCode: 200),
            ]
        )
        let acceptedPostStarted = expectation(description: "Accepted post started")
        let postObserver = OwnershipPopupObserver(expectation: acceptedPostStarted)
        NotificationCenter.default.addObserver(
            postObserver,
            selector: #selector(OwnershipPopupObserver.popupConstructed),
            name: ScriptedOwnershipHTTPTransport.postStartedNotification,
            object: nil
        )
        defer { NotificationCenter.default.removeObserver(postObserver) }
        let client = try makeClient(suiteName: suiteName, transport: transport)
        let postCompletion = expectation(description: "Accepted post completion")
        let popupConstructed = expectation(description: "Popup constructed while accepted post is active")
        let observer = OwnershipPopupObserver(expectation: popupConstructed)
        NotificationCenter.default.addObserver(
            observer,
            selector: #selector(OwnershipPopupObserver.popupConstructed),
            name: OwnershipRecordingPopup.constructedNotification,
            object: nil
        )
        defer { NotificationCenter.default.removeObserver(observer) }

        client.postConsent(makeConsent(version: "posting-version", valueID: "posting")) { error in
            XCTAssertNil(error)
            postCompletion.fulfill()
        }
        await fulfillment(of: [postCompletion, acceptedPostStarted], timeout: 2)
        client.showPrivacyPopUpIfNeeded(
            customViewType: OwnershipRecordingPopup.self,
            completion: { _ in },
            errorHandler: { error in XCTFail("Unexpected error: \(error)") }
        )
        await fulfillment(of: [popupConstructed], timeout: 2)

        let requestsBeforePostCompletion = await transport.requests()
        XCTAssertEqual(requestsBeforePostCompletion, [.authorization, .post, .fetch])

        await transport.completeControlledPost(statusCode: 200)
        let pending = await client.synchronizeIfNeeded()

        let requests = await transport.requests()
        let snapshot = reader.snapshot()
        XCTAssertFalse(pending)
        XCTAssertEqual(requests, [.authorization, .post, .fetch])
        XCTAssertNotNil(snapshot.userId)
        XCTAssertEqual(snapshot.values.mapValues(\.consentItem.id), ["posting": "posting"])
        XCTAssertEqual(snapshot.versionId, "posting-version")
        XCTAssertTrue(snapshot.consentsInSync)
        observer.popup?.finish()
    }

    func testDirectShowPrivacyPopUpStartsPendingSynchronizationWithoutWaitingForRetry() async throws {
        let fixture = try fixture()
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let storage = try makeStorage(suiteName: suiteName)
        let reader = try makeReader(suiteName: suiteName)
        let transport = DirectPopupHTTPTransport(fetchData: fixture.data)
        let client = try makeClient(suiteName: suiteName, transport: transport)
        await drainMainActor()
        _ = await client.synchronizeIfNeeded()
        _ = storage.userId
        storage.recordPostResult(
            consents: [makeValue(id: "pending", isSelected: true)],
            versionId: "pending-version",
            isInSync: false, solutionID: "solution-id"
        )
        let retryPostStarted = expectation(description: "Pending synchronization post started")
        let retryObserver = OwnershipPopupObserver(expectation: retryPostStarted)
        NotificationCenter.default.addObserver(
            retryObserver,
            selector: #selector(OwnershipPopupObserver.popupConstructed),
            name: DirectPopupHTTPTransport.postStartedNotification,
            object: nil
        )
        defer { NotificationCenter.default.removeObserver(retryObserver) }
        let popupPresented = expectation(description: "Direct popup presented")
        let presenter = OwnershipRecordingViewController(expectation: popupPresented)

        callSynchronousPopup(on: client,
            customViewType: LoadingOwnershipPopup.self,
            onViewController: presenter,
            animated: false)

        await fulfillment(of: [popupPresented, retryPostStarted], timeout: 2)
        let requestsBeforeRetryCompletion = await transport.requests()
        assertSingleFetchAuthorizationAndPost(requestsBeforeRetryCompletion)

        await transport.completeControlledPost(statusCode: 200)
        await waitForSynchronization(of: client, observedBy: reader)

        let popup = try XCTUnwrap(presenter.recordedPopup as? LoadingOwnershipPopup)
        let loadedData = await waitForLoadedData(popup)
        let data = try XCTUnwrap(loadedData)
        let requests = await transport.requests()
        assertSingleFetchAuthorizationAndPost(requests)
        XCTAssertTrue(reader.snapshot().consentsInSync)
        XCTAssertEqual(data.title, fixture.solution.templateTexts.privacyCenterTitle.primaryTranslation().text)
        XCTAssertEqual(data.acceptAllButtonTitle, fixture.solution.templateTexts.acceptAllButton.primaryTranslation().text)
    }

    func testDirectShowPrivacyPopUpIgnoresPendingSynchronizationFailure() async throws {
        let fixture = try fixture()
        let suiteName = uniqueSuiteName()
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let storage = try makeStorage(suiteName: suiteName)
        let reader = try makeReader(suiteName: suiteName)
        let transport = DirectPopupHTTPTransport(fetchData: fixture.data)
        let client = try makeClient(suiteName: suiteName, transport: transport)
        await drainMainActor()
        _ = await client.synchronizeIfNeeded()
        _ = storage.userId
        storage.recordPostResult(
            consents: [makeValue(id: "pending", isSelected: true)],
            versionId: "pending-version",
            isInSync: false, solutionID: "solution-id"
        )
        let retryPostStarted = expectation(description: "Pending synchronization post started")
        let retryObserver = OwnershipPopupObserver(expectation: retryPostStarted)
        NotificationCenter.default.addObserver(
            retryObserver,
            selector: #selector(OwnershipPopupObserver.popupConstructed),
            name: DirectPopupHTTPTransport.postStartedNotification,
            object: nil
        )
        defer { NotificationCenter.default.removeObserver(retryObserver) }
        let popupPresented = expectation(description: "Direct popup presented")
        let completion = expectation(description: "Direct popup completion")
        completion.isInverted = true
        let errorHandler = expectation(description: "Direct popup error handler")
        errorHandler.isInverted = true
        let presenter = OwnershipRecordingViewController(expectation: popupPresented)

        client.showPrivacyPopUp(
            customViewType: LoadingOwnershipPopup.self,
            onViewController: presenter,
            animated: false,
            completion: { _ in completion.fulfill() },
            errorHandler: { _ in errorHandler.fulfill() }
        )

        await fulfillment(of: [popupPresented, retryPostStarted], timeout: 2)
        await transport.completeControlledPost(statusCode: 500)

        let popup = try XCTUnwrap(presenter.recordedPopup as? LoadingOwnershipPopup)
        let dataLoaded = expectation(description: "Direct popup data loaded")
        popup.onDataLoaded = { dataLoaded.fulfill() }
        await fulfillment(of: [dataLoaded], timeout: 2)
        XCTAssertNotNil(popup.loadedData)
        await fulfillment(of: [completion, errorHandler], timeout: 0.1)

        let requests = await transport.requests()
        assertSingleFetchAuthorizationAndPost(requests)
        XCTAssertEqual(presenter.dismissCount, 0)
        XCTAssertFalse(reader.snapshot().consentsInSync)
    }

    private func makeClient(
        suiteName: String,
        transport: any HTTPTransport,
        clientID: String = "client-id",
        clientSecret: String = "client-secret",
        solutionID: String = "solution-id"
    ) throws -> MobileConsents {
        try XCTUnwrap(MobileConsents(
            storageSuiteName: suiteName,
            transport: transport,
            uiLanguageCode: "EN",
            clientID: clientID,
            clientSecret: clientSecret,
            solutionID: solutionID,
            accentColor: nil,
            fontSet: .standard
        ))
    }

    private func makeStorage(suiteName: String) throws -> ConsentStore {
        try XCTUnwrap(
            ConsentStore(
                suiteName: suiteName,
                solutionID: "solution-id",
                clientID: "client-id",
                clientSecret: "client-secret"
            )
        )
    }

    private func seedTwoConfigurations(in suiteName: String) throws -> [OwnershipConsentReader] {
        let first = try makeStorage(suiteName: suiteName)
        let second = try XCTUnwrap(
            ConsentStore(
                suiteName: suiteName,
                solutionID: "other-solution",
                clientID: "other-client",
                clientSecret: "other-secret"
            )
        )
        first.recordPostResult(
            consents: [makeValue(id: "first", isSelected: true)],
            versionId: "first-version",
            isInSync: false,
            solutionID: "solution-id"
        )
        second.recordPostResult(
            consents: [makeValue(id: "second", isSelected: false)],
            versionId: "second-version",
            isInSync: false,
            solutionID: "other-solution"
        )
        return [
            try makeReader(suiteName: suiteName),
            try makeReader(
                suiteName: suiteName,
                solutionID: "other-solution",
                clientID: "other-client",
                clientSecret: "other-secret"
            ),
        ]
    }

    private func makeReader(
        suiteName: String,
        solutionID: String = "solution-id",
        clientID: String = "client-id",
        clientSecret: String = "client-secret"
    ) throws -> OwnershipConsentReader {
        let store = try XCTUnwrap(
            ConsentStore(
                suiteName: suiteName,
                solutionID: solutionID,
                clientID: clientID,
                clientSecret: clientSecret
            )
        )
        return OwnershipConsentReader(
            store: store,
            suiteName: suiteName,
            solutionID: solutionID,
            clientID: clientID,
            clientSecret: clientSecret
        )
    }

    private func makeUserDefaults(suiteName: String) throws -> UserDefaults {
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }

    private func uniqueSuiteName() -> String {
        "MobileConsentsFacadeOwnershipTests.\(UUID().uuidString)"
    }

    private func makeConsent(
        version: String,
        valueID: String,
        solutionID: String = "solution-id"
    ) -> Consent {
        Consent(
            consentSolutionId: solutionID,
            consentSolutionVersionId: version,
            customData: ["source": "ownership-test"],
            userConsents: [UserConsent(consentItem: makeValue(id: valueID, isSelected: true).consentItem, isSelected: true)]
        )
    }

    private func makeValue(id: String, isSelected: Bool) -> UserConsentValue {
        UserConsentValue(
            consentItem: ConsentItem(
                id: id,
                required: false,
                type: .functional,
                translations: Translated(
                    translations: [ConsentTranslation(language: "EN", shortText: id, longText: "Details \(id)")],
                    primaryLanguage: nil
                )
            ),
            isSelected: isSelected
        )
    }

    private func fixture(
        versionID: String? = nil,
        solutionID: String = "solution-id"
    ) throws -> (data: Data, versionId: String, consentItems: [ConsentItem], solution: ConsentSolution) {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "ConsentSolution", withExtension: "json"))
        let data = try Data(contentsOf: url)
        var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["universalConsentSolutionId"] = solutionID
        if let versionID {
            object["universalConsentSolutionVersionId"] = versionID
        }
        let fixtureData = try JSONSerialization.data(withJSONObject: object)
        let solution = try JSONDecoder().decode(ConsentSolution.self, from: fixtureData)
        return (fixtureData, solution.versionId, solution.consentItems, solution)
    }

    private func drainMainActor() async {
        let task = Task<Void, Never>(name: "MobileConsentsFacadeOwnershipTests.drainMainActor") { @MainActor in }
        await task.value
    }

    private func assertSingleFetchAuthorizationAndPost(
        _ requests: [ScriptedOwnershipHTTPTransport.RequestKind],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(requests.filter { $0 == .fetch }.count, 1, file: file, line: line)
        XCTAssertEqual(requests.filter { $0 == .authorization }.count, 1, file: file, line: line)
        XCTAssertEqual(requests.filter { $0 == .post }.count, 1, file: file, line: line)
    }

    private func waitForPending(
        _ reader: OwnershipConsentReader,
        versionID: String
    ) async {
        do {
            let wasRecorded = try await waitForPendingPersistence(
                reader,
                versionID: versionID
            )
            XCTAssertTrue(wasRecorded, "Pending submission \(versionID) was not recorded")
        } catch {
            XCTFail("Pending-state read failed: \(error)")
        }
    }

    private func waitForSynchronized(_ reader: OwnershipConsentReader) async {
        do {
            let wasSynchronized = try await waitForSynchronizedPersistence(reader)
            XCTAssertTrue(wasSynchronized, "Pending submission was not synchronized")
        } catch {
            XCTFail("Pending-state read failed: \(error)")
        }
    }

    private func waitForSynchronization(
        of client: MobileConsents,
        observedBy reader: OwnershipConsentReader
    ) async {
        let remainsPending = await client.synchronizeIfNeeded()
        XCTAssertFalse(remainsPending)
        XCTAssertTrue(reader.snapshot().consentsInSync)
    }

    private func waitForLoadedData(_ popup: LoadingOwnershipPopup) async -> PrivacyPopUpData? {
        if let loadedData = popup.loadedData {
            return loadedData
        }

        let dataLoaded = expectation(description: "Popup data loaded")
        popup.onDataLoaded = { dataLoaded.fulfill() }
        await fulfillment(of: [dataLoaded], timeout: 2)
        return popup.loadedData
    }
}

private struct OwnershipConsentReader: Sendable {
    let store: ConsentStore
    let suiteName: String
    let solutionID: String
    let clientID: String
    let clientSecret: String

    var userId: String {
        snapshot().userId ?? ""
    }

    func hasPendingSynchronization() throws -> Bool {
        try store.hasPendingPersistence(
            suiteName: suiteName,
            solutionID: solutionID,
            clientID: clientID,
            clientSecret: clientSecret
        )
    }

    func inspection() throws -> ConsentPersistenceInspection {
        try store.persistenceInspection(
            suiteName: suiteName,
            solutionID: solutionID,
            clientID: clientID,
            clientSecret: clientSecret
        )
    }

    func snapshot(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> ConsentPersistenceInspection {
        do {
            return try inspection()
        } catch {
            XCTFail("Persistence inspection failed: \(error)", file: file, line: line)
            return ConsentPersistenceInspection(
                userId: "inspection-failed",
                versionId: "inspection-failed",
                submission: nil,
                synchronizationState: "inspection-failed"
            )
        }
    }
}

@concurrent
private func waitForPendingPersistence(
    _ reader: OwnershipConsentReader,
    versionID: String
) async throws -> Bool {
    let deadline = ProcessInfo.processInfo.systemUptime + 10
    repeat {
        let snapshot = try reader.inspection()
        if snapshot.versionId == versionID, !snapshot.consentsInSync {
            return true
        }
        try await Task<Never, Never>.sleep(nanoseconds: 10_000_000)
    } while ProcessInfo.processInfo.systemUptime < deadline
    return false
}

@concurrent
private func waitForSynchronizedPersistence(
    _ reader: OwnershipConsentReader
) async throws -> Bool {
    let deadline = ProcessInfo.processInfo.systemUptime + 10
    repeat {
        if try !reader.hasPendingSynchronization() {
            return true
        }
        try await Task<Never, Never>.sleep(nanoseconds: 10_000_000)
    } while ProcessInfo.processInfo.systemUptime < deadline
    return false
}

private final class BackgroundFacadePostInvoker: NSObject {
    private let client: MobileConsents
    private let consent: Consent
    private let backgroundCall: XCTestExpectation
    private let completion: (Error?) -> Void

    init(
        client: MobileConsents,
        consent: Consent,
        backgroundCall: XCTestExpectation,
        completion: @escaping (Error?) -> Void
    ) {
        self.client = client
        self.consent = consent
        self.backgroundCall = backgroundCall
        self.completion = completion
    }

    func start() {
        performSelector(inBackground: #selector(invoke), with: nil)
    }

    @objc private func invoke() {
        XCTAssertFalse(Thread.isMainThread)
        backgroundCall.fulfill()
        client.postConsent(consent, completion: completion)
    }
}

private final class BackgroundShowIfNeededInvoker: NSObject {
    private let client: MobileConsents
    private let backgroundCall: XCTestExpectation
    private let completion: ([UserConsent]) -> Void
    private let errorHandler: (Error) -> Void

    init(
        client: MobileConsents,
        backgroundCall: XCTestExpectation,
        completion: @escaping ([UserConsent]) -> Void,
        errorHandler: @escaping (Error) -> Void = { error in
            XCTFail("Unexpected error: \(error)")
        }
    ) {
        self.client = client
        self.backgroundCall = backgroundCall
        self.completion = completion
        self.errorHandler = errorHandler
    }

    func start() {
        performSelector(inBackground: #selector(invoke), with: nil)
    }

    @objc private func invoke() {
        XCTAssertFalse(Thread.isMainThread)
        backgroundCall.fulfill()
        client.showPrivacyPopUpIfNeeded(
            completion: completion,
            errorHandler: errorHandler
        )
    }
}

private actor OwnershipPostActivity {
    private var activePosts = 0
    private var maximumPosts = 0

    func beginPost() {
        activePosts += 1
        maximumPosts = max(maximumPosts, activePosts)
    }

    func endPost() {
        activePosts -= 1
    }

    func maximumActivePosts() -> Int {
        maximumPosts
    }
}

private actor ScriptedOwnershipHTTPTransport: HTTPTransport {
    static let postStartedNotification = Notification.Name(
        "MobileConsentsFacadeOwnershipTests.scriptedPostStarted"
    )

    enum RequestKind: Equatable, Sendable { case authorization, post, fetch }
    enum Response: Sendable {
        case auth
        case post(statusCode: Int)
        case controlledPost
        case fetch(data: Data?, statusCode: Int)

        var requestKind: RequestKind {
            switch self {
            case .auth:
                return .authorization
            case .post, .controlledPost:
                return .post
            case .fetch:
                return .fetch
            }
        }
    }

    struct PostRequest: Equatable, Sendable {
        let version: String
        let userID: String
        let processingPurposeIDs: [String]
    }

    struct AuthorizationCredentials: Equatable, Sendable {
        let clientID: String
        let clientSecret: String
    }

    private var responses: [Response]
    private var recordedRequests: [RequestKind] = []
    private var recordedPosts: [PostRequest] = []
    private var recordedAuthorizationCredentials: [AuthorizationCredentials] = []
    private var cancelledVersions: [String] = []
    private var activePosts = 0
    private var maximumPosts = 0
    private var cancellationWaiters: [CheckedContinuation<Void, Never>] = []
    private var controlledWaiters: [CheckedContinuation<HTTPResponseSnapshot, Never>] = []
    private var bufferedResponses: [HTTPResponseSnapshot] = []
    private let postActivity: OwnershipPostActivity?

    init(responses: [Response], postActivity: OwnershipPostActivity? = nil) {
        self.responses = responses
        self.postActivity = postActivity
    }

    func start(snapshot: HTTPRequestSnapshot, id _: HTTPRequestID) async throws -> HTTPTransportOperation {
        let kind = requestKind(for: snapshot)
        guard let responseIndex = responses.firstIndex(where: { $0.requestKind == kind }) else {
            throw ScriptedOwnershipHTTPTransportError.unexpectedRequest(kind)
        }
        let response = responses.remove(at: responseIndex)
        recordedRequests.append(kind)
        if kind == .authorization {
            recordedAuthorizationCredentials.append(try authorizationCredentials(from: snapshot))
        }
        let post = kind == .post ? try postRequest(from: snapshot) : nil
        if let post {
            await postActivity?.beginPost()
            recordedPosts.append(post)
            activePosts += 1
            maximumPosts = max(maximumPosts, activePosts)
            NotificationCenter.default.post(name: Self.postStartedNotification, object: nil)
        }
        let task = Task<HTTPResponseSnapshot, Error>(name: "MobileConsentsFacadeOwnershipTests.transportOperation") {
            let response = await self.response(for: response)
            if post != nil {
                self.finishedPost()
                await self.postActivity?.endPost()
            }
            if Task<Never, Never>.isCancelled {
                if let post {
                    self.recordCancellation(version: post.version)
                }
                throw CancellationError()
            }
            return response
        }
        return HTTPTransportOperation(task: task)
    }

    func requests() -> [RequestKind] { recordedRequests }
    func posts() -> [PostRequest] { recordedPosts }
    func authorizationCredentials() -> [AuthorizationCredentials] { recordedAuthorizationCredentials }
    func postVersions() -> [String] { recordedPosts.map(\.version) }
    func authorizationCount() -> Int { recordedRequests.filter { $0 == .authorization }.count }
    func cancelledPostVersions() -> [String] { cancelledVersions }
    func maximumActivePosts() -> Int { maximumPosts }

    func waitForPostCount(
        _ count: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let deadline = ProcessInfo.processInfo.systemUptime + 10
        while recordedPosts.count < count {
            guard ProcessInfo.processInfo.systemUptime < deadline else {
                XCTFail(
                    "Expected \(count) POST requests, received \(recordedPosts.count)",
                    file: file,
                    line: line
                )
                return
            }
            try? await Task<Never, Never>.sleep(nanoseconds: 10_000_000)
        }
    }

    func waitForPostCount(_ count: Int, withinYields: Int) async -> Bool {
        for _ in 0 ..< withinYields {
            if recordedPosts.count >= count {
                return true
            }
            await Task<Never, Never>.yield()
        }
        return recordedPosts.count >= count
    }

    func waitForCancelledPostCount(_ count: Int) async {
        while cancelledVersions.count < count {
            await withCheckedContinuation { cancellationWaiters.append($0) }
        }
    }

    func completeControlledPost(statusCode: Int) {
        let response = HTTPResponseSnapshot(url: nil, statusCode: statusCode)
        if controlledWaiters.isEmpty {
            bufferedResponses.append(response)
        } else {
            controlledWaiters.removeFirst().resume(returning: response)
        }
    }

    private func requestKind(for snapshot: HTTPRequestSnapshot) -> RequestKind {
        if snapshot.url.path.contains("oauth2") {
            return .authorization
        }
        return snapshot.method == .post ? .post : .fetch
    }

    private func postRequest(from snapshot: HTTPRequestSnapshot) throws -> PostRequest {
        let body = try XCTUnwrap(snapshot.body)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let version = try XCTUnwrap(json["universalConsentSolutionVersionId"] as? String)
        let userID = try XCTUnwrap(json["userId"] as? String)
        let purposes = try XCTUnwrap(json["processingPurposes"] as? [[String: Any]])
        return PostRequest(
            version: version,
            userID: userID,
            processingPurposeIDs: try purposes.map { try XCTUnwrap($0["universalConsentItemId"] as? String) }
        )
    }

    private func authorizationCredentials(
        from snapshot: HTTPRequestSnapshot
    ) throws -> AuthorizationCredentials {
        let body = try XCTUnwrap(snapshot.body)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        return AuthorizationCredentials(
            clientID: try XCTUnwrap(json["client_id"] as? String),
            clientSecret: try XCTUnwrap(json["client_secret"] as? String)
        )
    }

    private func response(for response: Response) async -> HTTPResponseSnapshot {
        switch response {
        case .auth:
            return HTTPResponseSnapshot(url: nil, statusCode: 200, body: Data("{\"access_token\":\"token\",\"expires_in\":3600}".utf8))
        case let .post(statusCode):
            return HTTPResponseSnapshot(url: nil, statusCode: statusCode)
        case let .fetch(data, statusCode):
            return HTTPResponseSnapshot(url: nil, statusCode: statusCode, body: data)
        case .controlledPost:
            if !bufferedResponses.isEmpty {
                return bufferedResponses.removeFirst()
            }
            return await withCheckedContinuation { controlledWaiters.append($0) }
        }
    }

    private func finishedPost() {
        activePosts -= 1
    }

    private func recordCancellation(version: String) {
        cancelledVersions.append(version)
        cancellationWaiters.forEach { $0.resume() }
        cancellationWaiters.removeAll()
    }
}

private enum ScriptedOwnershipHTTPTransportError: Error {
    case unexpectedRequest(ScriptedOwnershipHTTPTransport.RequestKind)
}

private actor DirectPopupHTTPTransport: HTTPTransport {
    static let postStartedNotification = Notification.Name(
        "MobileConsentsFacadeOwnershipTests.directPopupPostStarted"
    )

    private var recordedRequests: [ScriptedOwnershipHTTPTransport.RequestKind] = []
    private let fetchData: Data
    private var controlledPostWaiter: CheckedContinuation<HTTPResponseSnapshot, Never>?
    private var bufferedPostResponse: HTTPResponseSnapshot?

    init(fetchData: Data) {
        self.fetchData = fetchData
    }

    func start(snapshot: HTTPRequestSnapshot, id _: HTTPRequestID) async throws -> HTTPTransportOperation {
        let kind: ScriptedOwnershipHTTPTransport.RequestKind
        if snapshot.url.path.contains("oauth2") {
            kind = .authorization
        } else {
            kind = snapshot.method == .post ? .post : .fetch
        }
        recordedRequests.append(kind)
        if kind == .post {
            NotificationCenter.default.post(name: Self.postStartedNotification, object: nil)
        }
        let task = Task<HTTPResponseSnapshot, Error>(
            name: "MobileConsentsFacadeOwnershipTests.directPopupTransportOperation"
        ) {
            await self.response(for: kind)
        }
        return HTTPTransportOperation(task: task)
    }

    func requests() -> [ScriptedOwnershipHTTPTransport.RequestKind] {
        recordedRequests
    }

    func completeControlledPost(statusCode: Int) {
        let response = HTTPResponseSnapshot(url: nil, statusCode: statusCode)
        if let controlledPostWaiter {
            self.controlledPostWaiter = nil
            controlledPostWaiter.resume(returning: response)
        } else {
            bufferedPostResponse = response
        }
    }

    private func response(
        for kind: ScriptedOwnershipHTTPTransport.RequestKind
    ) async -> HTTPResponseSnapshot {
        switch kind {
        case .authorization:
            return HTTPResponseSnapshot(
                url: nil,
                statusCode: 200,
                body: Data("{\"access_token\":\"token\",\"expires_in\":3600}".utf8)
            )
        case .post:
            if let bufferedPostResponse {
                self.bufferedPostResponse = nil
                return bufferedPostResponse
            }
            return await withCheckedContinuation { controlledPostWaiter = $0 }
        case .fetch:
            return HTTPResponseSnapshot(url: nil, statusCode: 200, body: fetchData)
        }
    }
}

@MainActor
private final class OwnershipRecordingPopup: UIViewController, @MainActor PrivacyPopupProtocol {
    static let constructedNotification = Notification.Name("MobileConsentsFacadeOwnershipTests.popupConstructed")
    private let viewModel: PrivacyPopUpViewModel

    required init(viewModel: PrivacyPopUpViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        NotificationCenter.default.post(name: Self.constructedNotification, object: self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func finish() {
        viewModel.router?.closeAll(error: nil)
    }
}

private final class OwnershipPopupObserver: NSObject {
    private let expectation: XCTestExpectation
    private(set) var popup: OwnershipRecordingPopup?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    @objc func popupConstructed(_ notification: Notification) {
        popup = notification.object as? OwnershipRecordingPopup
        expectation.fulfill()
    }
}

@MainActor
private func callSynchronousSynchronization(on client: MobileConsents) {
    let callbackClient: MobileConsents = client
    callbackClient.synchronizeIfNeeded()
}

@MainActor
private func callSynchronousPopup(
    on client: MobileConsents,
    customViewType: PrivacyPopupProtocol.Type?,
    onViewController viewController: UIViewController?,
    animated: Bool
) {
    let show: (
        PrivacyPopupProtocol.Type?,
        UIViewController?,
        Bool,
        @escaping ([UserConsent]) -> Void,
        @escaping (Error) -> Void
    ) -> Void = client.showPrivacyPopUp
    show(
        customViewType,
        viewController,
        animated,
        { _ in },
        { error in XCTFail("Unexpected error: \(error)") }
    )
}

@MainActor
private final class OwnershipRecordingViewController: UIViewController {
    private let expectation: XCTestExpectation
    private(set) var recordedPopup: UIViewController?
    private(set) var presentedAnimated: Bool?
    private(set) var dismissCount = 0
    private(set) var events: [String] = []

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func present(
        _ viewControllerToPresent: UIViewController,
        animated flag: Bool,
        completion: (() -> Void)? = nil
    ) {
        recordedPopup = viewControllerToPresent
        presentedAnimated = flag
        completion?()
        expectation.fulfill()
    }

    override func dismiss(animated _: Bool, completion: (() -> Void)? = nil) {
        dismissCount += 1
        events.append("dismissalCompletion")
        completion?()
    }

    func recordUserCallback() {
        events.append("userCallback")
    }
}

@MainActor
private final class ActionOwnershipPopup: UIViewController, @MainActor PrivacyPopupProtocol {
    private let viewModel: PrivacyPopUpViewModel
    var onDataLoaded: (() -> Void)?

    required init(viewModel: PrivacyPopUpViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func load() {
        viewModel.onDataLoaded = { [weak self] _ in
            self?.onDataLoaded?()
        }
        viewModel.viewDidLoad()
    }

    func acceptAll() {
        viewModel.acceptAll()
    }
}

@MainActor
private final class LoadingOwnershipPopup: UIViewController, @MainActor PrivacyPopupProtocol {
    private let viewModel: PrivacyPopUpViewModel
    private(set) var loadedData: PrivacyPopUpData?
    var onDataLoaded: (() -> Void)? {
        didSet {
            if loadedData != nil {
                onDataLoaded?()
            }
        }
    }

    required init(viewModel: PrivacyPopUpViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        viewModel.onDataLoaded = { [weak self] data in
            self?.loadedData = data
            self?.onDataLoaded?()
        }
        viewModel.viewDidLoad()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
