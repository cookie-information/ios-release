import Foundation

nonisolated final class MainThreadNotificationObserver: NSObject {
    private let center: NotificationCenter
    private let handler: () -> Void

    init(
        center: NotificationCenter,
        name: Notification.Name,
        handler: @escaping () -> Void
    ) {
        self.center = center
        self.handler = handler
        super.init()
        center.addObserver(
            self,
            selector: #selector(receive(_:)),
            name: name,
            object: nil
        )
    }

    deinit {
        center.removeObserver(self)
    }

    @objc nonisolated func receive(_: Notification) {
        if Thread.isMainThread {
            _ = perform(#selector(Self.deliverOnMainActor))
        } else {
            performSelector(
                onMainThread: #selector(deliverOnMainActor),
                with: nil,
                waitUntilDone: false
            )
        }
    }

    @objc @MainActor private func deliverOnMainActor() {
        handler()
    }
}
