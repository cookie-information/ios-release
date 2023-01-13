import Foundation

public typealias NetworkProviderCompletion = (_ data: Data?, _ response: URLResponse?, _ error: Error?) -> ()

protocol NetworkProvider: AnyObject {
    associatedtype EndPoint: EndpointType
    func request(_ route: EndPoint, completion: @escaping NetworkProviderCompletion)
    func cancel()
}

private enum NetworkConstants {
    static let timeoutInterval: Double = 10.0
}

private enum NetworkProviderError: LocalizedError {
    case noBaseURL
    
    var errorDescription: String? {
        switch self {
        case .noBaseURL: return "baseURL could not be configured."
        }
    }
}

final class Provider<EndPoint: EndpointType>: NetworkProvider {
    private var task: URLSessionTask?
    
    func request(_ route: EndPoint, completion: @escaping NetworkProviderCompletion) {
        let session = URLSession.shared
        do {
            let request = try self.buildRequest(from: route)
            NetworkLogger.log(request: request)
            task = session.dataTask(with: request, completionHandler: { data, response, error in
                if let response = response {
                    NetworkLogger.log(response: response, data: data)
                }
                completion(data, response, error)
            })
            task?.resume()
        } catch {
            completion(nil, nil, error)
        }
    }
    
    func cancel() {
        task?.cancel()
    }
    
    private func buildRequest(from endpoint: EndPoint) throws -> URLRequest {
        guard let baseURL = endpoint.baseURL else { throw NetworkProviderError.noBaseURL }
        
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint.path),
                                 cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                 timeoutInterval: NetworkConstants.timeoutInterval)
        
        request.httpMethod = endpoint.method.rawValue
        switch endpoint.task {
        case .request:
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        case .requestWithParameters(let parameters, let encoding, let headers):
            headers.forEach { key, value in
                request.setValue(value, forHTTPHeaderField: key)
            }

            try self.configureParameters(
                bodyParameters: parameters,
                bodyEncoding: encoding,
                urlParameters: nil,
                request: &request
            )
        }
        return request
    }
    
    private func configureParameters(bodyParameters: Parameters?, bodyEncoding: ParameterEncoding, urlParameters: Parameters?, request: inout URLRequest) throws {
        try bodyEncoding.encode(
            urlRequest: &request,
            bodyParameters: bodyParameters,
            urlParameters: urlParameters
        )
    }
}
