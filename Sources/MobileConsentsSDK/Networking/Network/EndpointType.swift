import Foundation

protocol EndpointType {
    var baseURL: URL? { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var task: Task { get }
    var sampleData: Data { get }
}
