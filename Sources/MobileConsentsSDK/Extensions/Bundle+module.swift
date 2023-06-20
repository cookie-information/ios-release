import Foundation
internal extension Bundle {
    static var current:Bundle { Bundle(for: MobileConsents.self) }
}
