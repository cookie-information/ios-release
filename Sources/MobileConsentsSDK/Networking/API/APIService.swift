import Foundation

enum APIService: EndpointType {
    case getConsents(uuid: String)
  case postConsent(userId: String, payload: [String: Any], platformInformation: [String: Any]?, token: AuthResponse)
    case authorize(clientID: String, clientSecret: String)
    
    var environmentBaseURL: String {
        switch NetworkManager.environment {
        case .production: return "https://cdnapi-prod.azureedge.net/v1/"
        case .staging: return "https://cdnapi-staging.azureedge.net/v1/"
        }
    }
    
    var apiURL: URL {
        switch NetworkManager.environment {
        case .production: return URL(string: "https://consent-api.app.cookieinformation.com")!
        case .staging: return URL(string: "https://consent-api-staging.app.cookieinformation.com")!
        }
        
    }
    
    
    var baseURL: URL? {
        switch self {
        case .getConsents: return URL(string: environmentBaseURL)
        case .postConsent(_, _, _, _): return apiURL
        case .authorize: return apiURL
        }
    }
    
    var path: String {
        switch self {
        case .authorize: return "/oauth2/token"
        case .getConsents(let uuid): return "\(uuid)/consent-data.json"
        case .postConsent: return "/v1"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getConsents: return .get
        case .postConsent: return .post
        case .authorize: return .post
            
        }
    }
    
    var parameters: Parameters? {
        switch self {
        case .postConsent(let userId, let payload, let platformInformation, _):
            var parameters: Parameters = payload
            parameters["userId"] = userId
            parameters["platformInformation"] = platformInformation
            return parameters
        
        case .authorize(clientID: let id, clientSecret: let secret):
            return try? AuthRequest(clientId: id, clientSecret: secret).asDictionary()
            
        default: return nil
        }
    }
    
    var task: Task {
        guard let parameters = parameters else { return .request }
        
        if case let .postConsent(_, _, _, token) = self {
            return .requestWithParameters(parameters: parameters, encoding: .jsonEncoding, headers: ["authorization": "Bearer \(token.accessToken ?? "")"] )
        } else {
            return .requestWithParameters(parameters: parameters, encoding: .jsonEncoding)
        }
    }
    
    var sampleData: Data {
        switch self {
        case .getConsents(let uuid):
            return uuid.data(using: .utf8) ?? Data()
        case .postConsent:
            return Data()
        case .authorize:
            return Data()
        }
    }
}
