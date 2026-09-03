import Foundation

final class MainActorRequestDispatcher: NSObject {
    nonisolated func dispatch(_ request: MainActorRequest) {
        performSelector(
            onMainThread: #selector(performOnMainActor(_:)),
            with: request,
            waitUntilDone: false
        )
    }

    @objc @MainActor
    private func performOnMainActor(_ request: MainActorRequest) {
        request.perform()
    }
}

class MainActorRequest: NSObject {
    @MainActor
    func perform() {
        preconditionFailure("MainActorRequest must be subclassed")
    }
}
