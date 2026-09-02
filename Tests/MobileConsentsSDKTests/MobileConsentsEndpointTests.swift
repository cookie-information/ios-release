import Foundation
import Testing
@testable import MobileConsentsSDK

@Suite
struct MobileConsentsEndpointTests {
    @Test
    func consentSolutionBuildsExactStagingRequest() {
        let request = MobileConsentsEndpoint
            .consentSolution(solutionID: "solution-id")
            .request(in: .staging)

        #expect(
            request
                == HTTPRequestSnapshot(
                    url: URL(
                        string: "https://cdnapi-staging.azureedge.net/v1/solution-id/consent-data.json"
                    )!,
                    method: .get,
                    headers: ["Content-Type": "application/json"],
                    timeoutInterval: 10,
                    cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
                )
        )
    }

    @Test
    func authorizationBuildsExactStagingRequest() {
        let body = Data("authorization-body".utf8)

        let request = MobileConsentsEndpoint
            .authorization(body: body)
            .request(in: .staging)

        #expect(
            request
                == HTTPRequestSnapshot(
                    url: URL(
                        string: "https://consent-api-staging.app.cookieinformation.com/oauth2/token"
                    )!,
                    method: .post,
                    headers: ["Content-Type": "application/json"],
                    body: body,
                    timeoutInterval: 10,
                    cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
                )
        )
    }

    @Test
    func consentSubmissionBuildsExactStagingRequest() {
        let body = Data("consent-body".utf8)

        let request = MobileConsentsEndpoint
            .consentSubmission(body: body, accessToken: "access-token")
            .request(in: .staging)

        #expect(
            request
                == HTTPRequestSnapshot(
                    url: URL(
                        string: "https://consent-api-staging.app.cookieinformation.com/v1"
                    )!,
                    method: .post,
                    headers: [
                        "Content-Type": "application/json",
                        "Authorization": "Bearer access-token",
                    ],
                    body: body,
                    timeoutInterval: 10,
                    cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
                )
        )
    }
}
