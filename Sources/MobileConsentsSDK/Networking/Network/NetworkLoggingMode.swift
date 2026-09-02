import Foundation

/// Controls which network diagnostics the SDK records in the system log.
@objc public enum NetworkLoggingMode: Int, Sendable {
    /// Disables network logging.
    case disabled

    /// Logs request methods, redacted URLs, response status codes, and request identifiers.
    case metadata

    /// Logs metadata, sanitized headers, and payload sizes without logging payload contents.
    case redactedRequestsAndResponses

    /// Logs complete requests and response metadata.
    ///
    /// - Warning: Request URLs, headers, and payloads may contain credentials or user data.
    case fullRequests

    /// Logs complete requests and responses.
    ///
    /// - Warning: URLs, headers, and payloads may contain credentials or user data.
    case fullRequestsAndResponses
}
