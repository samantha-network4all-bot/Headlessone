import AppKit
import WebKit

final class DataController: NSViewController {
    let historyStore: HistoryStore
    let bookmarksStore: BookmarksStore
    let vault: Vault
    let websiteDataStore: WKWebsiteDataStore

    init(historyStore: HistoryStore, bookmarksStore: BookmarksStore, vault: Vault, websiteDataStore: WKWebsiteDataStore) {
        self.historyStore = historyStore
        self.bookmarksStore = bookmarksStore
        self.vault = vault
        self.websiteDataStore = websiteDataStore
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
}

extension DataController: TestAPIControllerRoutes {
    static var routePrefix: String { "data" }

    func registerRoutes(on router: TestAPIRouter) {
        router.post(prefix: Self.routePrefix, path: "/clear") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Decodable { let types: [String] }
            guard let body = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"types\": [...]}")
            }

            let types = Set(body.types)

            if types.contains("cookies") || types.contains("all") {
                let sem = DispatchSemaphore(value: 0)
                DispatchQueue.main.sync {
                    self.websiteDataStore.removeData(
                        ofTypes: [WKWebsiteDataTypeCookies],
                        modifiedSince: Date.distantPast
                    ) {
                        sem.signal()
                    }
                }
                _ = sem.wait(timeout: .now() + 5)
            }

            if types.contains("cache") || types.contains("all") {
                let sem = DispatchSemaphore(value: 0)
                DispatchQueue.main.sync {
                    self.websiteDataStore.removeData(
                        ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache],
                        modifiedSince: Date.distantPast
                    ) {
                        sem.signal()
                    }
                }
                _ = sem.wait(timeout: .now() + 5)
            }

            if types.contains("history") || types.contains("all") {
                self.historyStore.clear()
            }

            if types.contains("bookmarks") || types.contains("all") {
                self.bookmarksStore.clear()
            }

            if types.contains("passwords") || types.contains("all") {
                self.vault.clear()
            }

            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }
    }
}
