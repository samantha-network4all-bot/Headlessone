import AppKit
import WebKit

final class DownloadsController: NSViewController, WKDownloadDelegate {
    let store = DownloadsStore()
    weak var tabsController: TabsController!

    private var activeDownloads: [String: WKDownload] = [:]

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        TestAPIRouter.shared.register(controller: self)
    }

    private func filenameFromURL(_ url: URL) -> String {
        let last = url.lastPathComponent
        if !last.isEmpty { return last }
        if let host = url.host, !host.isEmpty { return host }
        return "download"
    }

    func start(url: URL) -> String {
        let filename = filenameFromURL(url)

        // For fixture:// URLs, serve data directly from bundle for deterministic downloads
        if url.scheme == "fixture" {
            let data = loadFixtureData(url: url)
            let tmpDir = FileManager.default.temporaryDirectory
            let dest = tmpDir.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: dest)
            var finalState = "failed"
            var finalBytes = 0
            if let data = data, !data.isEmpty {
                do {
                    try data.write(to: dest)
                    finalState = "finished"
                    finalBytes = data.count
                } catch {
                    finalState = "failed"
                    finalBytes = 0
                }
            }
            let id = store.add(url: url.absoluteString, filename: filename)
            store.update(id: id, state: finalState, bytesReceived: finalBytes)
            return id
        }

        // For non-fixture URLs, start WKDownload asynchronously
        let id = store.add(url: url.absoluteString, filename: filename)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let webTab = self.tabsController?.activeWebTab else {
                self.store.update(id: id, state: "failed", bytesReceived: 0)
                return
            }
            let request = URLRequest(url: url, timeoutInterval: 5.0)
            Task { @MainActor in
                do {
                    let download = try await webTab.webView.startDownload(using: request)
                    download.delegate = self
                    self.activeDownloads[id] = download
                } catch {
                    self.store.update(id: id, state: "failed", bytesReceived: 0)
                }
            }
        }

        return id
    }

    private func loadFixtureData(url: URL) -> Data? {
        let host = url.host ?? ""
        let filename = host.isEmpty ? "newtab" : host
        let bundle = Bundle.main
        var path: String? = nil
        let ext = (filename as NSString).pathExtension
        if ext.isEmpty {
            path = bundle.path(forResource: filename, ofType: "html")
        } else {
            path = bundle.path(forResource: (filename as NSString).deletingPathExtension, ofType: ext)
            if path == nil {
                path = bundle.path(forResource: filename, ofType: nil)
            }
        }
        guard let filePath = path else { return nil }
        return try? Data(contentsOf: URL(fileURLWithPath: filePath))
    }

    func cancelDownload(id: String) {
        guard let download = activeDownloads[id] else {
            // Not an active WKDownload (e.g. already finished/canceled fixture download)
            // Update state to canceled if it exists in the store
            store.update(id: id, state: "canceled", bytesReceived: 0)
            return
        }
        download.cancel { [weak self] _ in
            guard let self else { return }
            self.store.update(id: id, state: "canceled", bytesReceived: 0)
            self.activeDownloads.removeValue(forKey: id)
        }
    }

    // MARK: - WKDownloadDelegate

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        var matchedId: String?
        for (id, d) in activeDownloads {
            if d === download {
                matchedId = id
                break
            }
        }
        let filename = suggestedFilename
        let tmpDir = FileManager.default.temporaryDirectory
        let dest = tmpDir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: dest)
        completionHandler(dest)
    }

    func download(_ download: WKDownload, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = findId(for: download) else { return }
        store.update(id: id, state: "running", bytesReceived: Int(totalBytesWritten))
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let id = findId(for: download) else { return }
        // Read actual file size from destination if needed; for now mark finished
        store.update(id: id, state: "finished", bytesReceived: 0)
        activeDownloads.removeValue(forKey: id)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        guard let id = findId(for: download) else { return }
        store.update(id: id, state: "failed", bytesReceived: 0)
        activeDownloads.removeValue(forKey: id)
    }

    private func findId(for download: WKDownload) -> String? {
        for (id, d) in activeDownloads {
            if d === download {
                return id
            }
        }
        return nil
    }
}

extension DownloadsController: TestAPIControllerRoutes {
    static var routePrefix: String { "downloads" }

    func registerRoutes(on router: TestAPIRouter) {
        router.get(prefix: Self.routePrefix, path: "/list") { [weak self] _ in
            guard let self else { return .notFound() }
            var result: [[String: Any]] = []
            DispatchQueue.main.sync {
                let entries = self.store.list()
                result = entries.map { e in
                    ["id": e.id, "url": e.url, "filename": e.filename, "state": e.state, "bytesReceived": e.bytesReceived]
                }
            }
            let json = try? JSONSerialization.data(withJSONObject: result)
            return .ok(json: json ?? Data())
        }

        router.post(prefix: Self.routePrefix, path: "/start") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Decodable { let url: String }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"url\": String}")
            }
            guard let url = URL(string: b.url) else {
                return .badRequest("invalid URL")
            }
            let id = DispatchQueue.main.sync { self.start(url: url) }
            struct StartResponse: Codable { let ok: Bool; let id: String }
            let response = StartResponse(ok: true, id: id)
            let json = try! JSONEncoder().encode(response)
            return .ok(json: json)
        }

        router.post(prefix: Self.routePrefix, path: "/cancel") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Decodable { let id: String }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"id\": String}")
            }
            DispatchQueue.main.sync { self.cancelDownload(id: b.id) }
            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }
    }
}
