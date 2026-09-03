import Foundation
import SQLite3
import Testing
@testable import MobileConsentsSDK

@Suite
@MainActor
struct MobileConsentsReadFailureTests {
    @Test
    func asyncSavedConsentsPropagatesStoreReadFailure() async {
        let client = makeClient()

        await #expect(throws: ConsentStoreError.readFailed) {
            try await client.loadSavedConsents()
        }
    }

    @Test
    func synchronousReadAPIsReturnCompatibilityFallbacks() {
        let client = makeClient()

        #expect(client.userId.isEmpty)
        #expect(client.getSavedConsents().isEmpty)
    }

    @Test
    func asyncRemovalPropagatesPersistenceFailure() async {
        let client = makeClient()

        await #expect(throws: ConsentStoreError.persistenceFailed) {
            try await client.clearStoredConsents()
        }
    }

    @Test
    func synchronousRemovalSilentlyPreservesFailure() {
        let client = makeClient()

        client.removeStoredConsents()
    }

    @Test
    func synchronousRemovalFailurePreservesPersistedProfileAndDecision() throws {
        let suiteName = "MobileConsentsSDK.SyncRemovalFailure.\(UUID().uuidString)"
        let domain = ConsentStorageDomain.suite(suiteName)
        let store = try #require(
            ConsentStore(
                suiteName: suiteName,
                solutionID: "solution",
                clientID: "client",
                clientSecret: "secret"
            )
        )
        let submission = ConsentSubmissionValue(
            consentSolutionId: "solution",
            consentSolutionVersionId: "version",
            processingPurposes: [],
            customData: nil,
            userConsents: []
        )
        try store.savePending(submission: submission)
        var rawHolder: OpaquePointer?
        #expect(sqlite3_open(domain.consentDatabasePath, &rawHolder) == SQLITE_OK)
        let holder = try #require(rawHolder)
        defer {
            sqlite3_close(holder)
            try? FileManager.default.removeItem(atPath: domain.consentDatabasePath)
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        #expect(sqlite3_exec(holder, "BEGIN IMMEDIATE;", nil, nil, nil) == SQLITE_OK)
        let client = makeClient(store: store)
        let startedAt = ProcessInfo.processInfo.systemUptime

        client.removeStoredConsents()

        #expect(ProcessInfo.processInfo.systemUptime - startedAt >= 4.5)
        #expect(sqlite3_exec(holder, "COMMIT;", nil, nil, nil) == SQLITE_OK)
        let snapshot = try store.persistenceInspection(
            suiteName: suiteName,
            clientID: "client"
        )
        #expect(snapshot.versionId == "version")
        #expect(snapshot.submission == submission)
    }

    private func makeClient() -> MobileConsents {
        let suiteName = "MobileConsentsSDK.MobileConsentsReadFailureTests.\(UUID().uuidString)"
        let partition = ConsentPartitionID(
            solutionID: "solution",
            clientID: "client",
            clientSecret: "secret"
        )
        let store = ConsentStore(
            database: ConsentDatabase(path: "/dev/null/MobileConsentsSDK.sqlite3"),
            domain: .suite(suiteName),
            partition: partition
        )
        return makeClient(store: store)
    }

    private func makeClient(store: ConsentStore) -> MobileConsents {
        MobileConsents(
            store: store,
            transport: ReadFailureHTTPTransport(),
            uiLanguageCode: "EN",
            clientID: "client",
            clientSecret: "secret",
            solutionID: "solution",
            accentColor: nil,
            fontSet: .standard
        )
    }
}

private enum ReadFailureError: Error {
    case unexpectedRequest
}

private struct ReadFailureHTTPTransport: HTTPTransport {
    func start(
        snapshot _: HTTPRequestSnapshot,
        id _: HTTPRequestID
    ) async throws -> HTTPTransportOperation {
        throw ReadFailureError.unexpectedRequest
    }
}