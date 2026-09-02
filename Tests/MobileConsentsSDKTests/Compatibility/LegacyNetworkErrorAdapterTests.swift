import Foundation
import XCTest
@testable import MobileConsentsSDK

final class LegacyNetworkErrorAdapterTests: XCTestCase {
    func testAuthorizationFailuresPreserveMessages() {
        assertNetworkResponseError(
            LegacyNetworkErrorAdapter.adapt(
                NetworkCoreError.authorizationFailed("invalid credentials")
            ),
            equals: .invalidClientCredentials("invalid credentials")
        )
        assertNetworkResponseError(
            LegacyNetworkErrorAdapter.adapt(
                NetworkCoreError.authorizationFailed(nil)
            ),
            equals: .invalidClientCredentials(nil)
        )
    }

    func testMissingBodyMapsToNoData() {
        assertNetworkResponseError(
            LegacyNetworkErrorAdapter.adapt(NetworkCoreError.missingBody),
            equals: .noData
        )
    }

    func testUnsuccessfulStatusCodesMapAtBoundaries() {
        assertNetworkResponseError(
            LegacyNetworkErrorAdapter.adapt(
                NetworkCoreError.unsuccessfulStatusCode(399)
            ),
            equals: .failed
        )
        assertNetworkResponseError(
            LegacyNetworkErrorAdapter.adapt(
                NetworkCoreError.unsuccessfulStatusCode(400)
            ),
            equals: .badRequest
        )
        assertNetworkResponseError(
            LegacyNetworkErrorAdapter.adapt(
                NetworkCoreError.unsuccessfulStatusCode(599)
            ),
            equals: .badRequest
        )
        assertNetworkResponseError(
            LegacyNetworkErrorAdapter.adapt(
                NetworkCoreError.unsuccessfulStatusCode(600)
            ),
            equals: .outdated
        )
        assertNetworkResponseError(
            LegacyNetworkErrorAdapter.adapt(
                NetworkCoreError.unsuccessfulStatusCode(601)
            ),
            equals: .failed
        )
    }

    func testConsentPostFailureMapsServerSnapshotAndNilSnapshot() {
        let snapshot = ConsentPostServerErrorValue(
            statusCode: 422,
            message: "Validation failed",
            error: "invalid_consent"
        )

        let adapted = LegacyNetworkErrorAdapter.adapt(
            NetworkCoreError.consentPostFailed(
                statusCode: 400,
                serverError: snapshot
            )
        )

        let apiError = adapted as? APIError
        XCTAssertEqual(apiError?.statusCode, snapshot.statusCode)
        XCTAssertEqual(apiError?.message, snapshot.message)
        XCTAssertEqual(apiError?.error, snapshot.error)
        assertNetworkResponseError(
            LegacyNetworkErrorAdapter.adapt(
                NetworkCoreError.consentPostFailed(
                    statusCode: 400,
                    serverError: nil
                )
            ),
            equals: .badRequest
        )
    }

    func testTransportFailuresAndCancellationMapToLegacyErrors() {
        assertNetworkResponseError(
            LegacyNetworkErrorAdapter.adapt(HTTPTransportError.nonHTTPResponse),
            equals: .noProperResponse
        )
        assertURLError(
            LegacyNetworkErrorAdapter.adapt(HTTPTransportError.cancelled),
            code: .cancelled
        )
        assertNetworkResponseError(
            LegacyNetworkErrorAdapter.adapt(HTTPTransportError.duplicateRequestID),
            equals: .failed
        )
        assertURLError(
            LegacyNetworkErrorAdapter.adapt(CancellationError()),
            code: .cancelled
        )
    }

    func testUnmappedErrorsAreReturnedUnchanged() {
        let urlError = URLError(.timedOut)
        let adaptedURL = LegacyNetworkErrorAdapter.adapt(urlError)
        XCTAssertEqual((adaptedURL as? URLError)?.code, .timedOut)

        let decodingError = DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: [],
                debugDescription: "Invalid fixture"
            )
        )
        guard case let .dataCorrupted(context) = LegacyNetworkErrorAdapter.adapt(decodingError) as? DecodingError else {
            XCTFail("Expected unchanged DecodingError")
            return
        }
        XCTAssertEqual(context.codingPath.count, 0)
        XCTAssertEqual(context.debugDescription, "Invalid fixture")

        let customError = ReferenceError()
        let adaptedCustomError = LegacyNetworkErrorAdapter.adapt(customError)
        XCTAssertTrue(adaptedCustomError as AnyObject === customError)
    }

    private func assertNetworkResponseError(
        _ error: Error,
        equals expected: NetworkResponseError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual = error as? NetworkResponseError else {
            XCTFail("Expected NetworkResponseError, got \(error)", file: file, line: line)
            return
        }
        XCTAssertEqual(actual.errorDescription, expected.errorDescription, file: file, line: line)
    }

    private func assertURLError(
        _ error: Error,
        code: URLError.Code,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual((error as? URLError)?.code, code, file: file, line: line)
    }
}

private final class ReferenceError: Error {}
