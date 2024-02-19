import Foundation

#if !SWIFT_PACKAGE
internal extension Bundle {
  static var module:Bundle { Bundle(for: MobileConsents.self) }
}
#endif
