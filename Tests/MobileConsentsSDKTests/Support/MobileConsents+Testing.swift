import UIKit
@testable import MobileConsentsSDK

extension MobileConsents {
    convenience init?(
        storageSuiteName: String,
        transport: any HTTPTransport,
        uiLanguageCode: String?,
        clientID: String,
        clientSecret: String,
        solutionID: String,
        accentColor: UIColor?,
        fontSet: FontSet,
        localizationOverride: [Locale: LabelText] = [:]
    ) {
        guard let store = ConsentStore(
            suiteName: storageSuiteName,
            solutionID: solutionID,
            clientID: clientID,
            clientSecret: clientSecret
        ) else {
            return nil
        }

        self.init(
            store: store,
            transport: transport,
            uiLanguageCode: uiLanguageCode,
            clientID: clientID,
            clientSecret: clientSecret,
            solutionID: solutionID,
            accentColor: accentColor,
            fontSet: fontSet,
            localizationOverride: localizationOverride
        )
    }
}