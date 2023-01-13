enum Environment {
    case staging
    case production
    
    var apiURLString: String {
        switch self {
        case .staging:
            return "staging_url"
        case .production:
            return "production_url"
        }
    }
}
