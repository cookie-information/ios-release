enum Task {
    case request
  case requestWithParameters(parameters: Parameters, encoding: ParameterEncoding, headers: [String: String] = [:])
    
}
