import Foundation

extension String {
    var iso8601withFractionalSeconds: Date? { return Formatter.iso8601withFractionalSeconds.date(from: self) }
}

extension String {
    var localized: String {
        NSLocalizedString(self, bundle: Bundle.module, comment: "")
    }
}

private final class BundleLocator {}
