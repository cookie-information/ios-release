import Foundation
import OSLog

struct NetworkLogger: Sendable {
    private let systemLogger = Logger(
        subsystem: "com.cookieinformation.MobileConsentsSDK",
        category: "network"
    )

    let mode: NetworkLoggingMode

    var isEnabled: Bool {
        mode != .disabled
    }

    func log(request: HTTPRequestSnapshot, id: HTTPRequestID) {
        guard let message = requestLog(request: request, id: id) else {
            return
        }
        systemLogger.debug("\(message, privacy: .public)")
    }

    func log(response: HTTPResponseSnapshot, id: HTTPRequestID) {
        guard let message = responseLog(response: response, id: id) else {
            return
        }
        systemLogger.debug("\(message, privacy: .public)")
    }

    func requestLog(request: HTTPRequestSnapshot, id: HTTPRequestID) -> String? {
        guard isEnabled else {
            return nil
        }

        let usesFullRequest = switch mode {
        case .fullRequests, .fullRequestsAndResponses:
            true
        case .disabled, .metadata, .redactedRequestsAndResponses:
            false
        }
        var lines = [
            "REQUEST \(id.rawValue.uuidString)",
            "\(request.method.rawValue) \(urlString(request.url, redacted: !usesFullRequest))",
        ]
        switch mode {
        case .redactedRequestsAndResponses:
            appendRedactedDetails(
                headers: request.headers,
                body: request.body,
                to: &lines
            )
        case .fullRequests, .fullRequestsAndResponses:
            appendFullDetails(
                headers: request.headers,
                body: request.body,
                to: &lines
            )
        case .disabled, .metadata:
            break
        }
        return lines.joined(separator: "\n")
    }

    func responseLog(response: HTTPResponseSnapshot, id: HTTPRequestID) -> String? {
        guard isEnabled else {
            return nil
        }

        let usesFullResponse = mode == .fullRequestsAndResponses
        var lines = [
            "RESPONSE \(id.rawValue.uuidString)",
            "\(response.statusCode) \(urlString(response.url, redacted: !usesFullResponse))",
        ]
        switch mode {
        case .redactedRequestsAndResponses:
            appendRedactedDetails(
                headers: response.headers,
                body: response.body,
                to: &lines
            )
        case .fullRequestsAndResponses:
            appendFullDetails(
                headers: response.headers,
                body: response.body,
                to: &lines
            )
        case .disabled, .metadata, .fullRequests:
            break
        }
        return lines.joined(separator: "\n")
    }

    private func appendRedactedDetails(
        headers: [String: String],
        body: Data?,
        to lines: inout [String],
    ) {
        guard mode == .redactedRequestsAndResponses else {
            return
        }

        for (name, value) in headers.sorted(by: headerNamePrecedes) {
            lines.append("\(name): \(redactedHeaderValue(for: name, value: value))")
        }
        if let body {
            lines.append("Body: [REDACTED] (\(body.count) bytes)")
        }
    }

    private func appendFullDetails(
        headers: [String: String],
        body: Data?,
        to lines: inout [String],
    ) {
        for (name, value) in headers.sorted(by: headerNamePrecedes) {
            lines.append("\(name): \(value)")
        }
        if let body {
            lines.append("Body: \(String(decoding: body, as: UTF8.self))")
        }
    }

    private func headerNamePrecedes(
        _ lhs: (key: String, value: String),
        _ rhs: (key: String, value: String),
    ) -> Bool {
        lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
    }

    private func redactedHeaderValue(for name: String, value: String) -> String {
        switch name.lowercased() {
        case "accept", "accept-language", "content-length", "content-type":
            value
        default:
            "[REDACTED]"
        }
    }

    private func urlString(_ url: URL?, redacted: Bool) -> String {
        guard redacted else {
            return url?.absoluteString ?? ""
        }
        guard var components = url.flatMap({
            URLComponents(url: $0, resolvingAgainstBaseURL: false)
        }) else {
            return ""
        }

        components.user = nil
        components.password = nil
        components.query = nil
        components.fragment = nil
        return components.string ?? ""
    }
}
