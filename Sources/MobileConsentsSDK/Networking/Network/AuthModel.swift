import Foundation

struct AuthRequest: Encodable {
    let clientId: String
    let clientSecret: String
    let grantType: String = "client_credentials"
}

struct AuthResponse: Codable {
    let accessToken: String?
    var expiresIn: Date
    
    var errorDescription: String?
    var error: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let expires = (try? container.decode(Double.self, forKey: .expiresIn)) ?? -1
        
        expiresIn = Date(timeIntervalSinceNow: expires)
        accessToken = try? container.decode(String?.self, forKey: .accessToken)
        errorDescription = try? container.decode(String?.self, forKey: .errorDescription)
        error = try? container.decode(String.self, forKey: .error)
        
    }
    

}
