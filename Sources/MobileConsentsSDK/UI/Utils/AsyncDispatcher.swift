import Foundation

protocol AsyncDispatcher {
    func async(execute work: @escaping () -> Void)
}

final class MainThreadAsyncDispatcher: AsyncDispatcher {
    func async(execute work: @escaping () -> Void) {
        DispatchQueue.main.async(execute: DispatchWorkItem(block: work))
    }
}
