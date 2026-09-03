import Foundation

private struct AsyncSignal: Sendable {
    let events: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() {
        let stream = AsyncStream.makeStream(
            of: Void.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        events = stream.stream
        continuation = stream.continuation
    }

    func send() {
        continuation.yield()
    }

    func finish() {
        continuation.finish()
    }
}

actor ConsentSynchronizationCoordinator {
    private let core: ConsentCore
    private let signal = AsyncSignal()
    private var needsAnotherPass = false
    private var waiters = [CheckedContinuation<Bool, Never>]()
    private var worker: Task<Void, Never>?

    init(core: ConsentCore) {
        self.core = core
    }

    deinit {
        signal.finish()
        worker?.cancel()
    }

    func synchronizeIfNeeded() async -> Bool {
        needsAnotherPass = true
        startWorkerIfNeeded()

        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
            signal.send()
        }
    }

    private func startWorkerIfNeeded() {
        guard worker == nil else {
            return
        }
        worker = Task<Void, Never>(
            name: "MobileConsentsSDK.ConsentSynchronizationCoordinator.events"
        ) { [weak self, signal = signal] in
            for await _ in signal.events {
                guard let self else {
                    return
                }
                await self.processNextEvent()
            }
        }
    }

    private func processNextEvent() async {
        needsAnotherPass = false
        do {
            try Task<Never, Never>.checkCancellation()
            switch try await core.synchronizeNext() {
            case .processed:
                signal.send()
            case .idle:
                finishIfStable(pending: false)
            case .busy:
                finishIfStable(pending: true)
            }
        } catch {
            finishIfStable(pending: true)
        }
    }

    private func finishIfStable(pending: Bool) {
        guard !needsAnotherPass else {
            signal.send()
            return
        }

        let completedWaiters = waiters
        waiters.removeAll()
        completedWaiters.forEach { $0.resume(returning: pending) }
    }
}
