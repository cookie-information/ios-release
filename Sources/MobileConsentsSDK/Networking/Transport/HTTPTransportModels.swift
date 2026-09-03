import Foundation

struct HTTPRequestID: Hashable, RawRepresentable, Sendable {
    let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

enum HTTPRequestMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

enum HTTPRequestCachePolicy: Sendable {
    case reloadIgnoringLocalAndRemoteCacheData
}

struct HTTPRequestSnapshot: Equatable, Sendable {
    let url: URL
    let method: HTTPRequestMethod
    let headers: [String: String]
    let body: Data?
    let timeoutInterval: TimeInterval
    let cachePolicy: HTTPRequestCachePolicy

    init(
        url: URL,
        method: HTTPRequestMethod,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeoutInterval: TimeInterval,
        cachePolicy: HTTPRequestCachePolicy
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeoutInterval = timeoutInterval
        self.cachePolicy = cachePolicy
    }
}

struct HTTPResponseSnapshot: Equatable, Sendable {
    let url: URL?
    let statusCode: Int
    let headers: [String: String]
    let body: Data?

    init(
        url: URL?,
        statusCode: Int,
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.url = url
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

struct HTTPTransportOperation: Sendable {
    private let task: Task<HTTPResponseSnapshot, Error>

    init(task: Task<HTTPResponseSnapshot, Error>) {
        self.task = task
    }

    var value: HTTPResponseSnapshot {
        get async throws {
            try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
        }
    }

    func cancel() {
        task.cancel()
    }
}

enum HTTPTransportError: Error, Equatable, Sendable {
    case duplicateRequestID
    case nonHTTPResponse
    case cancelled
}
