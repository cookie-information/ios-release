import XCTest
@testable import MobileConsentsSDK

final class AuthResponseTests: XCTestCase {
    func testIsValid_whenTokenHasAccessTokenAndExpiresIn_returnsTrue() throws {
        let response = try decodeAuthResponse(from: #"{"access_token":"token","expires_in":3600}"#)

        XCTAssertTrue(response.isValid)
    }

    func testIsValid_whenOAuthErrorPayload_returnsFalse() throws {
        let response = try decodeAuthResponse(from: #"{"error":"invalid_client","error_description":"Bad credentials"}"#)

        XCTAssertFalse(response.isValid)
    }

    func testIsValid_whenAccessTokenIsEmpty_returnsFalse() throws {
        let response = try decodeAuthResponse(from: #"{"access_token":"","expires_in":3600}"#)

        XCTAssertFalse(response.isValid)
    }

    func testIsValid_whenExpiresInIsMissing_returnsFalse() throws {
        let response = try decodeAuthResponse(from: #"{"access_token":"token"}"#)

        XCTAssertFalse(response.isValid)
    }

    func testIsValid_whenTokenIsExpired_returnsFalse() throws {
        let response = try decodeAuthResponse(from: #"{"access_token":"token","expires_in":-1}"#)

        XCTAssertFalse(response.isValid)
    }
}

private func decodeAuthResponse(from json: String) throws -> AuthResponse {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(AuthResponse.self, from: Data(json.utf8))
}
