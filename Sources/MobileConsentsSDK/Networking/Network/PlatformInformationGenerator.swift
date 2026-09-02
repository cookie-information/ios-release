import Foundation

struct PlatformInformationGenerator {
    func generatePlatformInformation() -> [String: String] {
        let operatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
        let formattedOperatingSystemVersion = "\(operatingSystemVersion.majorVersion).\(operatingSystemVersion.minorVersion)"
            + (operatingSystemVersion.patchVersion == 0 ? "" : ".\(operatingSystemVersion.patchVersion)")

        return [
            "operatingSystem": "iOS \(formattedOperatingSystemVersion)",
            "applicationId": Bundle.main.bundleIdentifier ?? "",
            "applicationName": Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ""
        ]
    }
}
