import UIKit
import XCTest
@testable import MobileConsentsSDK

final class PlatformInformationGeneratorTests: XCTestCase {
    @MainActor
    func testGeneratePlatformInformation_returnsExact1_6KeysAndValues() {
        let actual = PlatformInformationGenerator().generatePlatformInformation()
        let expected = [
            "operatingSystem": "iOS \(UIDevice.current.systemVersion)",
            "applicationId": Bundle.main.bundleIdentifier ?? "",
            "applicationName": Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ""
        ]

        XCTAssertEqual(Set(actual.keys), Set(expected.keys))
        XCTAssertEqual(actual, expected)
    }
}
