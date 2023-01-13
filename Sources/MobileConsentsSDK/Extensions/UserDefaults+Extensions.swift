import Foundation

extension UserDefaults: UserDefaultsProtocol {
    func set<T>(_ value: T?, forKey key: String) {
        setValue(value, forKey: key)
    }
    
    func get<T>(forKey key: String) -> T? {
        return object(forKey: key) as? T
    }
}
