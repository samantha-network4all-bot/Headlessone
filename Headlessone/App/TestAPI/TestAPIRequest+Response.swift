import Foundation

struct TestAPIRequest {
    let method: String
    let path: String
    let query: [String: String]
    let body: Data
}

struct TestAPIResponse {
    var status: Int = 200
    var contentType: String = "application/json"
    var body: Data = Data()

    static func ok(json: Data) -> TestAPIResponse {
        var r = TestAPIResponse()
        r.body = json
        r.contentType = "application/json"
        return r
    }

    static func notFound(_ req: TestAPIRequest) -> TestAPIResponse {
        var r = TestAPIResponse()
        r.status = 404
        r.body = Data("{\"error\":\"not found: \\(req.method) \\(req.path)\"}\n".utf8)
        return r
    }

    static func notFound() -> TestAPIResponse {
        var r = TestAPIResponse()
        r.status = 404
        r.body = Data("{\"error\":\"not found\"}\n".utf8)
        return r
    }

    static func badRequest(_ message: String) -> TestAPIResponse {
        var r = TestAPIResponse()
        r.status = 400
        r.body = Data("{\"error\":\"\(message)\"}\n".utf8)
        return r
    }

    static func serverError(_ message: String) -> TestAPIResponse {
        var r = TestAPIResponse()
        r.status = 500
        r.body = Data("{\"error\":\"\\(message)\"}\n".utf8)
        return r
    }

    static func png(_ data: Data) -> TestAPIResponse {
        var r = TestAPIResponse()
        r.body = data
        r.contentType = "image/png"
        return r
    }
}
