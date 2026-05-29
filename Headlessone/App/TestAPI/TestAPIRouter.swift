import Foundation

protocol TestAPIControllerRoutes: AnyObject {
    static var routePrefix: String { get }
    func registerRoutes(on router: TestAPIRouter)
}

final class TestAPIRouter {
    static let shared = TestAPIRouter()
    private var handlers: [String: (TestAPIRequest) -> TestAPIResponse] = [:]

    private init() {}

    func register<C: TestAPIControllerRoutes>(controller: C) {
        controller.registerRoutes(on: self)
    }

    func get(prefix: String, path: String, _ h: @escaping (TestAPIRequest) -> TestAPIResponse) {
        let full = prefix.isEmpty ? path : "/\(prefix)\(path)"
        handlers["GET \(full)"] = h
    }

    func post(prefix: String, path: String, _ h: @escaping (TestAPIRequest) -> TestAPIResponse) {
        let full = prefix.isEmpty ? path : "/\(prefix)\(path)"
        handlers["POST \(full)"] = h
    }

    func dispatch(_ req: TestAPIRequest) -> TestAPIResponse {
        let key = "\(req.method) \(req.path)"
        if let handler = handlers[key] {
            return handler(req)
        }
        return .notFound(req)
    }
}
