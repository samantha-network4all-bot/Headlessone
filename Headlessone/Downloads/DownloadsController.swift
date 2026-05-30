import AppKit
import WebKit

final class DownloadsController: NSViewController, WKDownloadDelegate {
    let store = DownloadsStore()
    weak var tabsController: TabsController!

    private var activeDownloads: [String: WKDownload] = [:]
    private var downloadSemaphores: [String: DispatchSemaphore] = [:]
    private var lastBytesWritten: [String: Int64] = [:]
    private var downloadFilenames: [String: String] = [:]
    private let lock = NSLock()

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

    func start(url: URL) -> (id: String, settled: Bool) {
        let filename = url.lastPathComponent
        let id = store.add(url: url.absoluteString, filename: filename)

        let sem = DispatchSemaphore(value: 0)
        lock.lock()
        downloadSemaphores[id] = sem
        lastBytesWritten[id] = 0
        downloadFilenames[id] = filename
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                sem.signal()
                return
            }
            guard let webTab = self.tabsController?.activeWebTab else {
                self.store.update(id: id, state: "failed", bytesReceived: 0)
                self.lock.lock()
                self.lastBytesWritten.removeValue(forKey: id)
                self.downloadFilenames.removeValue(forKey: id)
                self.lock.unlock()
                sem.signal()
                return
            }
            let request = URLRequest(url: url, timeoutInterval: 5.0)
            Task { @MainActor in
                do {
                    let download = try await webTab.webView.startDownload(using: request)
                    download.delegate = self
                    self.lock.lock()
                    self.activeDownloads[id] = download
                    self.lock.unlock()
                } catch {
                    self.store.update(id: id, state: "failed", bytesReceived: 0)
                    self.lock.lock()
                    self.lastBytesWritten.removeValue(forKey: id)
                    self.downloadFilenames.removeValue(forKey: id)
                    self.lock.unlock()
                    sem.signal()
                }
            }
        }

        let result = sem.wait(timeout: .now() + 15.0)
        return (id: id, settled: result == .success)
    }

    func cancelDownload(id: String) -> Bool {
        let sem = DispatchSemaphore(value: 0)
        lock.lock()
        downloadSemaphores[id] = sem
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                sem.signal()
                return
            }
            self.lock.lock()
            let download = self.activeDownloads[id]
            self.lock.unlock()
            if let download = download {
                download.cancel { [weak self] _ in
                    guard let self else { return }
                    self.store.update(id: id, state: "canceled", bytesReceived: 0)
                    self.lock.lock()
                    self.activeDownloads.removeValue(forKey: id)
                    self.lastBytesWritten.removeValue(forKey: id)
                    self.downloadFilenames.removeValue(forKey: id)
                    self.lock.unlock()
                    sem.signal()
                }
            } else {
                self.store.update(id: id, state: "canceled", bytesReceived: 0)
                self.lock.lock()
                self.lastBytesWritten.removeValue(forKey: id)
                self.downloadFilenames.removeValue(forKey: id)
                self.lock.unlock()
                sem.signal()
            }
        }

        let result = sem.wait(timeout: .now() + 15.0)
        return result == .success
    }

    // MARK: - WKDownloadDelegate

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        // Try to find the matching id by checking which download id doesn't have an activeDownloads entry yet
        let filename = suggestedFilename
        lock.lock()
        // Find a pending download id without an active download assigned
        var matchedId: String?
        for (id, d) in activeDownloads {
            if d === download {
                matchedId = id
                break
            }
        }
        if matchedId == nil {
            // The activeDownloads entry hasn't been set yet (race with Task)
            // Use the last-added id without an active download
            let activeIds = Set(activeDownloads.keys)
            let pendingIds = downloadFilenames.keys.filter { !activeIds.contains($0) }
            // Pick the most recent pending id
            if let lastPending = pendingIds.last {
                activeDownloads[lastPending] = download
                matchedId = lastPending
            }
        }
        let id = matchedId
        lock.unlock()

        let tmpDir = FileManager.default.temporaryDirectory
        let dest = tmpDir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: dest)
        completionHandler(dest)
    }

    func download(_ download: WKDownload, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        lock.lock()
        let id = findId(for: download)
        lock.unlock()
        if let id = id {
            store.update(id: id, state: "running", bytesReceived: Int(totalBytesWritten))
            lock.lock()
            lastBytesWritten[id] = totalBytesWritten
            lock.unlock()
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        lock.lock()
        let id = findId(for: download)
        lock.unlock()
        guard let id = id else { return }

        // Get bytes from in-memory tracking, fallback to file size
        lock.lock()
        let memBytes = lastBytesWritten[id] ?? 0
        lock.unlock()
        let filename = downloadFilenames[id] ?? store.filename(for: id) ?? "unknown"
        let filePath = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let fileBytes: Int64
        if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath.path),
           let size = attrs[.size] as? Int64 {
            fileBytes = size
        } else {
            fileBytes = memBytes
        }
        let finalBytes = max(memBytes, fileBytes)

        store.update(id: id, state: "finished", bytesReceived: Int(finalBytes))
        lock.lock()
        downloadSemaphores[id]?.signal()
        downloadSemaphores.removeValue(forKey: id)
        activeDownloads.removeValue(forKey: id)
        lastBytesWritten.removeValue(forKey: id)
        downloadFilenames.removeValue(forKey: id)
        lock.unlock()
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        lock.lock()
        let id = findId(for: download)
        lock.unlock()
        guard let id = id else { return }

        store.update(id: id, state: "failed", bytesReceived: 0)
        lock.lock()
        downloadSemaphores[id]?.signal()
        downloadSemaphores.removeValue(forKey: id)
        activeDownloads.removeValue(forKey: id)
        lastBytesWritten.removeValue(forKey: id)
        downloadFilenames.removeValue(forKey: id)
        lock.unlock()
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
            let (id, _) = self.start(url: url)
            let json = try? JSONSerialization.data(withJSONObject: ["ok": true, "id": id])
            return .ok(json: json ?? Data())
        }

        router.post(prefix: Self.routePrefix, path: "/cancel") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Decodable { let id: String }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"id\": String}")
            }
            _ = self.cancelDownload(id: b.id)
            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }
    }
}
