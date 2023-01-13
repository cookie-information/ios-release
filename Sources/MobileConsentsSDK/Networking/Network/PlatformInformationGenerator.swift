import UIKit

protocol PlatformInformationGeneratorProtocol {
    func generatePlatformInformation() -> [String: String]
}

struct PlatformInformationGenerator: PlatformInformationGeneratorProtocol {
    func generatePlatformInformation() -> [String: String] {
        return [
            "operatingSystem": "iOS \(UIDevice.current.systemVersion)",
            "applicationId": Bundle.main.bundleIdentifier ?? "",
            "applicationName": Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ""
        ]
    }
}
