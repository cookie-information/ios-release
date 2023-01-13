import Foundation

final class MockedUserDefaults: UserDefaultsProtocol {
    private var data: [String: Any] = [:]
    
    func set<T>(_ value: T?, forKey key: String) {
        data[key] = value
    }
    
    func get<T>(forKey key: String) -> T? {
        return data[key] as? T
    }
    
    func removeObject(forKey key: String) {
        data.removeValue(forKey: key)
    }
}
