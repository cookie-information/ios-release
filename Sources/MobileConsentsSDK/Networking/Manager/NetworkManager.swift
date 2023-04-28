import Foundation

enum NetworkResponseError: LocalizedError {
    case badRequest
    case outdated
    case failed
    case noData
    case unableToDecode
    case noProperResponse
    case notFound
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .badRequest: return "Bad request"
        case .outdated: return "The url you requested is outdated."
        case .failed: return "Network request failed."
        case .noData: return "Response returned with no data to decode."
        case .unableToDecode: return "We could not decode the response."
        case .noProperResponse: return "No proper response."
        case .notFound: return "Not found"
        case .unauthorized: return "Unauthorized"
        }
    }
}

enum NetworkResult<T> {
    case success
    case failure(T)
}

final class NetworkManager {
    static let environment: Environment = .production
    private lazy var provider = { Provider<APIService>(enableLogger: enableNetworkLogger) }()
    private let jsonDecoder: JSONDecoder
    private let localStorageManager: LocalStorageManagerProtocol
    private let platformInformationGenerator: PlatformInformationGeneratorProtocol
    private let clientID: String
    private let clientSecret: String
    private var token: AuthResponse?
    private let solutionID: String
    private let enableNetworkLogger: Bool
    
    init(
        jsonDecoder: JSONDecoder,
        localStorageManager: LocalStorageManagerProtocol = LocalStorageManager(),
        platformInformationGenerator: PlatformInformationGeneratorProtocol = PlatformInformationGenerator(),
        clientID: String,
        clientSecret: String,
        solutionID: String,
        enableNetworkLogger: Bool = false
    ) {
        self.jsonDecoder = jsonDecoder
        self.localStorageManager = localStorageManager
        self.platformInformationGenerator = platformInformationGenerator
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.solutionID = solutionID
        self.enableNetworkLogger = enableNetworkLogger
    }
    
    func getConsentSolution(completion: @escaping (Result<ConsentSolution, Error>) -> Void) {
        provider.request(.getConsents(uuid: self.solutionID)) { [jsonDecoder] data, response, error in
            guard let response = response as? HTTPURLResponse else {
                return completion(.failure(NetworkResponseError.noProperResponse))
            }

            switch response.result {
            case .success:
                if let error = error {
                    completion(.failure(error))
                } else if let data = data {
                    do {
                        let consentSolution = try jsonDecoder.decode(ConsentSolution.self, from: data)
                        completion(.success(consentSolution))
                    } catch {
                        completion(.failure(error))
                    }
                } else {
                    completion(.failure(NetworkResponseError.noData))
                }
            case .failure(let error): completion(.failure(error))
            }
        }
    }
    
    func authorize(_ completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        provider.request(.authorize(clientID: clientID,
                                    clientSecret: clientSecret)) { data, response, error in
            let decoder = JSONDecoder()
          decoder.keyDecodingStrategy = .convertFromSnakeCase
          guard let data = data else {
            guard let error = error else  { return }
            completion(.failure(error))
            return }
          
          let token = try? decoder.decode( AuthResponse.self, from: data)
          self.token = token
          guard let token = token else {return}
          completion(.success(token))
        }
    }
    
    func postConsent(_ consent: Consent, completion: @escaping (Error?) -> Void) {
      if let token = token, token.expiresIn > Date() {
        postConsent(consent: consent, completion: completion)
      } else {
        authorize { repsponse in
          if case .success(_) = repsponse {
            self.postConsent(consent, completion: completion)
          }
        }
      }
    }
    
  private func postConsent(consent: Consent, completion: @escaping (Error?) -> Void) {
    let platformInformation = platformInformationGenerator.generatePlatformInformation()
    let consentPayload = consent.JSONRepresentation()
    let userId = localStorageManager.userId
    guard let token = token else {
      completion(NetworkResponseError.unauthorized)
      return }
    provider.request(.postConsent(userId: userId, payload: consentPayload, platformInformation: platformInformation, token: token)) { data, response, error in
        if let error = error {
            completion(error)
        } else {
            guard let response = response as? HTTPURLResponse else {
                return completion(NetworkResponseError.noProperResponse)
            }
            
            switch response.result {
            case .success: completion(nil)
            case .failure(let error):
                switch error {
                case .badRequest:
                    guard let data = data, let apiError = try? JSONDecoder().decode(APIError.self, from: data) else { return completion(error) }
                    
                    completion(apiError)
                default: completion(error)
                }
            }
        }
    }
  }
    func cancel() {
        provider.cancel()
    }
}
