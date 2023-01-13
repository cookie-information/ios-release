import Foundation

enum NetworkLogger {
    static func log(request: URLRequest) {
        #if DEBUG
            print("\n ====================== REQUEST START ====================== \n")
            defer { print("\n ======================  REQUEST END ====================== \n") }
            
            let urlAsString = request.url?.absoluteString ?? ""
            let urlComponents = NSURLComponents(string: urlAsString)
            
            let method = request.httpMethod != nil ? "\(request.httpMethod ?? "")" : ""
            let path = "\(urlComponents?.path ?? "")"
            let query = "\(urlComponents?.query ?? "")"
            let host = "\(urlComponents?.host ?? "")"
            
            var logOutput = """
                            \(urlAsString) \n\n
                            \(method) \(path)?\(query) HTTP/1.1 \n
                            HOST: \(host)\n
                            """
            for (key, value) in request.allHTTPHeaderFields ?? [:] {
                logOutput += "\(key): \(value) \n"
            }
            if let body = request.httpBody {
                logOutput += "\n \(NSString(data: body, encoding: String.Encoding.utf8.rawValue) ?? "")"
            }
            
            print(logOutput)
        #endif
    }
    
    static func log(response: URLResponse, data: Data? = nil) {
        #if DEBUG
            print("\n ====================== RESPONSE START ====================== \n")
            defer { print("\n ======================  RESPONSE END ====================== \n") }
            
        guard let response = response as? HTTPURLResponse else {
            print("NO PROPER RESPONSE FORMAT")
            return
        }
        
        let urlAsString = response.url?.absoluteString ?? ""
        let urlComponents = NSURLComponents(string: urlAsString)
        
        let path = "\(urlComponents?.path ?? "")"
        let query = "\(urlComponents?.query ?? "")"
        let host = "\(urlComponents?.host ?? "")"
        
        var logOutput = """
                        \(urlAsString) \n\n
                        \(path)?\(query) HTTP/1.1 \n
                        HOST: \(host)\n
          """
        
        for (key, value) in response.allHeaderFields {
            logOutput += "\(key): \(value) \n"
        }
        
        logOutput += "\(response.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: response.statusCode)) \n"
        
        if let body = data {
            logOutput += "\n \(String(data: body, encoding: .utf8) ?? "")"
        }
        
        print(logOutput)
        #endif
    }
}
