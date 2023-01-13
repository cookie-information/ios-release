import Foundation

protocol AsyncDispatcher {
    func async(execute work: @escaping () -> Void)
}

extension DispatchQueue: AsyncDispatcher {
    func async(execute work: @escaping () -> Void) {
        async(group: nil, qos: .unspecified, flags: [], execute: work)
    }
}
