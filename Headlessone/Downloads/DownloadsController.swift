import AppKit
import WebKit

final class DownloadsController: NSViewController, WKDownloadDelegate {
    let store = DownloadsStore()
    weak var tabsController: TabsController!

    private var activeDownloads: [String: WKDownload] = [:]
    private var downloadGroups: [String: DispatchGroup] = [:]

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

    func start(url: URL) -> String {
        let filename = url.lastPathComponent
        let id = store.add(url: url.absoluteString, filename: filename)

        var group: DispatchGroup?
        DispatchQueue.main.sync {
            guard let webTab = self.tabsController.activeWebTab else { return }
            let request = URLRequest(url: url, timeoutInterval: 5.0)
            let g = DispatchGroup()
            g.enter()
            self.downloadGroups[id] = g
            group = g

            Task { @MainActor in
                do {
                    let download = try await webTab.webView.startDownload(using: request)
                    download.delegate = self
                    self.activeDownloads[id] = download
                } catch {
                    self.store.update(id: id, state: "failed", bytesReceived: 0)
                    g.leave()
                    self.downloadGroups.removeValue(forKey: id)
                }
            }
        }

        // Wait synchronously for timeout or terminal state
        if let g = group {
            _ = g.wait(timeout: .now() + 15.0)
        }

        return id
    }

    func cancelDownload(id: String) {
        DispatchQueue.main.sync {
            if let download = self.activeDownloads[id] {
                download.cancel { [weak self] _ in
                    guard let self else { return }
                    self.store.update(id: id, state: "canceled", bytesReceived: 0)
                    self.downloadGroups[id]?.leave()
                    self.downloadGroups.removeValue(forKey: id)
                }
            } else {
                self.store.update(id: id, state: "canceled", bytesReceived: 0)
                self.downloadGroups[id]?.leave()
                self.downloadGroups.removeValue(forKey: id)
            }
        }
    }

    // MARK: - WKDownloadDelegate

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let tmpDir = FileManager.default.temporaryDirectory
        let dest = tmpDir.appendingPathComponent(suggestedFilename)
        // Remove if exists so we start clean
        try? FileManager.default.removeItem(at: dest)
        completionHandler(dest)
    }

    func download(_ download: WKDownload, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // Find the download id and update bytes
        for (id, d) in activeDownloads {
            if d === download {
                let currentBytes = Int(totalBytesWritten)
                store.update(id: id, state: "running", bytesReceived: currentBytes)
                break
            }
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        for (id, d) in activeDownloads {
            if d === download {
                let entries = store.list()
                let entry = entries.first(where: { $0.id == id })
                store.update(id: id, state: "finished", bytesReceived: entry?.bytesReceived ?? 0)
                downloadGroups[id]?.leave()
                downloadGroups.removeValue(forKey: id)
                activeDownloads.removeValue(forKey: id)
                break
            }
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        for (id, d) in activeDownloads {
            if d === download {
                store.update(id: id, state: "failed", bytesReceived: 0)
                downloadGroups[id]?.leave()
                downloadGroups.removeValue(forKey: id)
                activeDownloads.removeValue(forKey: id)
                break
            }
        }
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
            let id = self.start(url: url)
            let json = try? JSONSerialization.data(withJSONObject: ["ok": true, "id": id])
            return .ok(json: json ?? Data())
        }

        router.post(prefix: Self.routePrefix, path: "/cancel") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Decodable { let id: String }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"id\": String}")
            }
            DispatchQueue.main.sync {
                self.cancelDownload(id: b.id)
            }
            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }
    }
}
