import Foundation

actor URLSessionHTTPTransport: HTTPTransport {
    private let session: URLSession
    private let networkLogger: NetworkLogger
    private var tasks: [HTTPRequestID: Task<HTTPResponseSnapshot, Error>] = [:]

    init(
        session: URLSession = .shared,
        networkLoggingMode: NetworkLoggingMode = .disabled,
    ) {
        self.session = session
        self.networkLogger = NetworkLogger(mode: networkLoggingMode)
    }

    init(
        session: URLSession = .shared,
        enableNetworkLogger: Bool,
    ) {
        self.session = session
        self.networkLogger = NetworkLogger(
            mode: enableNetworkLogger ? .redactedRequestsAndResponses : .disabled
        )
    }

    var isNetworkLoggingEnabled: Bool {
        networkLogger.isEnabled
    }

    var networkLoggingMode: NetworkLoggingMode {
        networkLogger.mode
    }

    func start(
        snapshot: HTTPRequestSnapshot,
        id: HTTPRequestID,
    ) async throws -> HTTPTransportOperation {
        guard tasks[id] == nil else {
            throw HTTPTransportError.duplicateRequestID
        }

        let task = Task<HTTPResponseSnapshot, Error>(
            name: "MobileConsentsSDK.HTTPTransport.operation"
        ) {
            try await self.run(snapshot: snapshot, id: id)
        }
        tasks[id] = task

        return HTTPTransportOperation(task: task)
    }

    private func run(
        snapshot: HTTPRequestSnapshot,
        id: HTTPRequestID
    ) async throws -> HTTPResponseSnapshot {
        defer { tasks[id] = nil }

        do {
            try Task<Never, Never>.checkCancellation()
            return try await perform(snapshot: snapshot, id: id)
        } catch {
            throw normalized(error)
        }
    }

    private func perform(
        snapshot: HTTPRequestSnapshot,
        id: HTTPRequestID
    ) async throws -> HTTPResponseSnapshot {
        var request = URLRequest(
            url: snapshot.url,
            cachePolicy: urlCachePolicy(for: snapshot.cachePolicy),
            timeoutInterval: snapshot.timeoutInterval
        )
        request.httpMethod = snapshot.method.rawValue
        for (field, value) in snapshot.headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.httpBody = snapshot.body

        networkLogger.log(request: snapshot, id: id)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPTransportError.nonHTTPResponse
        }

        let responseSnapshot = HTTPResponseSnapshot(
            url: httpResponse.url,
            statusCode: httpResponse.statusCode,
            headers: responseHeaders(from: httpResponse),
            body: data
        )
        networkLogger.log(response: responseSnapshot, id: id)
        return responseSnapshot
    }

    private func urlCachePolicy(
        for cachePolicy: HTTPRequestCachePolicy
    ) -> URLRequest.CachePolicy {
        switch cachePolicy {
        case .reloadIgnoringLocalAndRemoteCacheData:
            return .reloadIgnoringLocalAndRemoteCacheData
        }
    }

    private func responseHeaders(from response: HTTPURLResponse) -> [String: String] {
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            headers[String(describing: key)] = String(describing: value)
        }
        return headers
    }

    private func normalized(_ error: Error) -> Error {
        if error is CancellationError {
            return HTTPTransportError.cancelled
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return HTTPTransportError.cancelled
        }
        return error
    }
}
