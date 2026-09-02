import Foundation

protocol HTTPTransport: Sendable {
    func start(
        snapshot: HTTPRequestSnapshot,
        id: HTTPRequestID
    ) async throws -> HTTPTransportOperation
}
