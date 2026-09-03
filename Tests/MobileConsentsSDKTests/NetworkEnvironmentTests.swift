import Foundation
import Testing
@testable import MobileConsentsSDK

@Suite
struct NetworkEnvironmentTests {
    @Test
    func productionEndpoints() {
        let environment = NetworkEnvironment.production

        #expect(
            environment.consentSolutionBaseURL
                == URL(string: "https://cdnapi.app.cookieinformation.com/v1/")!
        )
        #expect(
            environment.authorizationURL
                == URL(string: "https://consent-api.app.cookieinformation.com/oauth2/token")!
        )
        #expect(
            environment.consentSubmissionURL
                == URL(string: "https://consent-api.app.cookieinformation.com/v1")!
        )
    }

    @Test
    func stagingEndpoints() {
        let environment = NetworkEnvironment.staging

        #expect(
            environment.consentSolutionBaseURL
                == URL(string: "https://cdnapi-staging.azureedge.net/v1/")!
        )
        #expect(
            environment.authorizationURL
                == URL(
                    string: "https://consent-api-staging.app.cookieinformation.com/oauth2/token"
                )!
        )
        #expect(
            environment.consentSubmissionURL
                == URL(string: "https://consent-api-staging.app.cookieinformation.com/v1")!
        )
    }
}
