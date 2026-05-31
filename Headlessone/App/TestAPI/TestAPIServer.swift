import Foundation
import Network

final class TestAPIServer {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.bimboware.headlessone.testapi")
    private var connections: [NWConnection] = []

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        listener = try NWListener(using: parameters, on: .any)
        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.writePortFile()
            case .failed(let err):
                NSLog("TestAPIServer failed: \(err)")
            default:
                break
            }
        }
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        listener?.start(queue: queue)
    }

    private func writePortFile() {
        guard let port = listener?.port else { return }
        let portStr = "\(port)\n"
        let url = applicationSupportDirectory().appendingPathComponent("test-api.port")
        try? portStr.write(to: url, atomically: true, encoding: .utf8)
    }

    private func applicationSupportDirectory() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Headlessone")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)
        connection.start(queue: queue)
        receiveHTTP(connection)
    }

    private func receiveHTTP(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error = error {
                NSLog("TestAPIServer receive error: \(error)")
                self.removeConnection(connection)
                return
            }
            guard let data = data, !data.isEmpty else {
                if isComplete {
                    self.removeConnection(connection)
                } else {
                    self.receiveHTTP(connection)
                }
                return
            }
            let response = self.processRequest(data: data)
            self.sendResponse(response, on: connection, complete: isComplete)
        }
    }

    private func processRequest(data: Data) -> TestAPIResponse {
        guard let raw = String(data: data, encoding: .utf8) else {
            return .badRequest("invalid encoding")
        }
        let lines = raw.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            return .badRequest("empty request")
        }
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            return .badRequest("malformed request line")
        }
        let method = parts[0]
        let fullPath = parts[1]

        var path = fullPath
        var query: [String: String] = [:]
        if let qMark = fullPath.firstIndex(of: "?") {
            path = String(fullPath[..<qMark])
            var qs = String(fullPath[fullPath.index(after: qMark)...])
            // Decode percent-encoding first to handle double-encoded query strings
            if let decoded = qs.removingPercentEncoding {
                qs = decoded
            }
            // Normalize separators: replace '?' with '&' to handle frameworks
            // that use '?' instead of '&' as query param separator
            qs = qs.replacingOccurrences(of: "?", with: "&")
            for pair in qs.components(separatedBy: "&") {
                let kv = pair.components(separatedBy: "=")
                if kv.count >= 2 {
                    query[kv[0]] = kv.dropFirst().joined(separator: "=")
                }
            }
        }

        // Find body after \r\n\r\n
        var body = Data()
        if let sep = raw.range(of: "\r\n\r\n") {
            let bodyStr = String(raw[sep.upperBound...])
            body = Data(bodyStr.utf8)
        }

        let req = TestAPIRequest(method: method, path: path, query: query, body: body)
        return TestAPIRouter.shared.dispatch(req)
    }

    private func sendResponse(_ response: TestAPIResponse, on connection: NWConnection, complete: Bool) {
        var header = "HTTP/1.1 \(response.status) \(statusText(response.status))\r\n"
        header += "Content-Type: \(response.contentType)\r\n"
        header += "Content-Length: \(response.body.count)\r\n"
        header += "Connection: close\r\n"
        header += "\r\n"
        var data = Data(header.utf8)
        data.append(response.body)
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                NSLog("TestAPIServer send error: \(error)")
            }
            self?.removeConnection(connection)
        })
    }

    private func statusText(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }

    private func removeConnection(_ connection: NWConnection) {
        connection.cancel()
        connections.removeAll { $0 === connection }
    }

    func stop() {
        listener?.cancel()
        connections.forEach { $0.cancel() }
        connections.removeAll()
    }
}
