import Foundation

extension String {
    var iso8601withFractionalSeconds: Date? { return Formatter.iso8601withFractionalSeconds.date(from: self) }
}

internal extension String {
    var localized: String {
        NSLocalizedString(self, bundle: Bundle.module, comment: "")
    }
    
    var isValidURL:Bool {
        let urlPattern = #"^(https?|ftp)://[^\s/$.?#].[^\s]*$"#  // Adjust the pattern as needed
        let regex = try! NSRegularExpression(pattern: urlPattern)
        
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }
}

private final class BundleLocator {}

