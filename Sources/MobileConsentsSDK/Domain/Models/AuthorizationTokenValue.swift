import Foundation

struct AuthorizationTokenValue: Equatable, Sendable {
    let accessToken: String
    let expiresAt: Date

    func isValid(at date: Date) -> Bool {
        !accessToken.isEmpty && expiresAt > date
    }
}
