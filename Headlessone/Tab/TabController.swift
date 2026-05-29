import AppKit
import WebKit

final class TabController: NSViewController {
    weak var tabsController: TabsController!

    init(tabsController: TabsController) {
        self.tabsController = tabsController
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

    func activeWebTab() -> WebTab? {
        return tabsController.activeWebTab
    }
}

extension TabController: TestAPIControllerRoutes {
    static var routePrefix: String { "tab" }

    func registerRoutes(on router: TestAPIRouter) {
        router.post(prefix: Self.routePrefix, path: "/navigate") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Decodable { let url: String; let tabId: String? }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"url\": String, \"tabId\": String?}")
            }
            guard let targetUrl = URL(string: b.url) else {
                return .badRequest("invalid URL")
            }

            var targetTab: WebTab?
            DispatchQueue.main.sync {
                if let tabId = b.tabId {
                    targetTab = self.tabsController.webTab(for: tabId)
                } else {
                    targetTab = self.activeWebTab()
                }
                return ()
            }

            guard let webTab = targetTab else {
                return .badRequest("tab not found")
            }

            DispatchQueue.main.sync {
                webTab.loadState = "loading"
                webTab.webView.load(URLRequest(url: targetUrl))
            }

            // Wait for load to finish (synchronous from HTTP perspective)
            let semaphore = DispatchSemaphore(value: 0)
            var maxWait = 150 // 15 seconds at 0.1s intervals
            while webTab.loadState == "loading" && maxWait > 0 {
                DispatchQueue.main.sync {}
                Thread.sleep(forTimeInterval: 0.1)
                maxWait -= 1
            }

            let response: [String: String] = [
                "ok": "true",
                "url": webTab.url?.absoluteString ?? b.url,
                "title": webTab.title,
                "loadState": webTab.loadState
            ]
            let body = try? JSONEncoder().encode(response)
            return .ok(json: body ?? Data())
        }

        router.post(prefix: Self.routePrefix, path: "/back") { [weak self] _ in
            guard let self else { return .notFound() }
            DispatchQueue.main.sync {
                self.activeWebTab()?.webView.goBack()
                return ()
            }
            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }

        router.post(prefix: Self.routePrefix, path: "/forward") { [weak self] _ in
            guard let self else { return .notFound() }
            DispatchQueue.main.sync {
                self.activeWebTab()?.webView.goForward()
                return ()
            }
            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }

        router.post(prefix: Self.routePrefix, path: "/reload") { [weak self] _ in
            guard let self else { return .notFound() }
            DispatchQueue.main.sync {
                self.activeWebTab()?.webView.reload()
                return ()
            }
            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }

        router.post(prefix: Self.routePrefix, path: "/stop") { [weak self] _ in
            guard let self else { return .notFound() }
            DispatchQueue.main.sync {
                self.activeWebTab()?.webView.stopLoading()
                return ()
            }
            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }

        router.get(prefix: Self.routePrefix, path: "/state") { [weak self] req in
            guard let self else { return .notFound() }
            let tabId = req.query["tabId"]
            var webTab: WebTab?
            DispatchQueue.main.sync {
                if let id = tabId {
                    webTab = self.tabsController.webTab(for: id)
                } else {
                    webTab = self.activeWebTab()
                }
                return ()
            }
            guard let tab = webTab else {
                return .badRequest("tab not found")
            }
            let state: [String: Any] = [
                "tabId": tab.id,
                "url": tab.url?.absoluteString ?? "",
                "title": tab.title,
                "loadState": tab.loadState,
                "canGoBack": tab.canGoBack,
                "canGoForward": tab.canGoForward,
                "progress": tab.progress
            ]
            // Manual JSON since we have Any
            var json = "{"
            json += "\"tabId\":\"\(tab.id)\","
            json += "\"url\":\"\(tab.url?.absoluteString ?? "")\","
            json += "\"title\":\"\(tab.title)\","
            json += "\"loadState\":\"\(tab.loadState)\","
            json += "\"canGoBack\":\(tab.canGoBack),"
            json += "\"canGoForward\":\(tab.canGoForward),"
            json += "\"progress\":\(tab.progress)"
            json += "}\n"
            return .ok(json: Data(json.utf8))
        }

        router.post(prefix: Self.routePrefix, path: "/eval") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Decodable { let js: String }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"js\": String}")
            }
            var result: String?
            DispatchQueue.main.sync {
                self.activeWebTab()?.webView.evaluateJavaScript(b.js) { res, err in
                    if let err = err {
                        result = String(describing: err)
                    } else if let res = res {
                        result = String(describing: res)
                    } else {
                        result = "null"
                    }
                }
                return ()
            }
            // Wait briefly for JS eval
            var maxWait = 50 // 5 seconds
            while result == nil && maxWait > 0 {
                Thread.sleep(forTimeInterval: 0.1)
                maxWait -= 1
            }
            let output = result ?? "timeout"
            let body = try? JSONEncoder().encode(["result": output])
            return .ok(json: body ?? Data())
        }
    }
}
