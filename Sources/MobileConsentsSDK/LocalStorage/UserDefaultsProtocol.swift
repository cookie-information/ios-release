protocol UserDefaultsProtocol {
    func set<T>(_ value: T?, forKey key: String)
    func get<T>(forKey key: String) -> T?
    func removeObject(forKey key: String)
}
