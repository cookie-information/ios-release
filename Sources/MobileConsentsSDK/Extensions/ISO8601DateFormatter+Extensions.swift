import Foundation

extension ISO8601DateFormatter {
    convenience init(_ formatOptions: Options, timeZone: TimeZone? = TimeZone(secondsFromGMT: 0)) {
        self.init()
        self.formatOptions = formatOptions
        self.timeZone = timeZone
    }
}
