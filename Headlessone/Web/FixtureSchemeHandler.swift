import Foundation
import WebKit

final class FixtureSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(NSError(domain: "FixtureSchemeHandler", code: -1))
            return
        }
        let host = url.host ?? ""
        let filename = host.isEmpty ? "newtab" : host
        let bundle = Bundle.main
        guard let path = bundle.path(forResource: filename, ofType: "html") else {
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(Data("Not found: \(filename)".utf8))
            urlSchemeTask.didFinish()
            return
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let mimeType = mimeTypeForPath(path)
            let headerFields: [String: String] = ["Content-Type": mimeType, "Content-Length": "\(data.count)"]
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headerFields)!
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // no-op
    }

    private func mimeTypeForPath(_ path: String) -> String {
        if path.hasSuffix(".html") { return "text/html" }
        if path.hasSuffix(".css") { return "text/css" }
        if path.hasSuffix(".js") { return "application/javascript" }
        if path.hasSuffix(".png") { return "image/png" }
        if path.hasSuffix(".jpg") || path.hasSuffix(".jpeg") { return "image/jpeg" }
        return "application/octet-stream"
    }
}
