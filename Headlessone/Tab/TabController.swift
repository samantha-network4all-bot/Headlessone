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
            }

            guard let webTab = targetTab else {
                return .badRequest("tab not found")
            }

            webTab.navigateSynchronously(url: targetUrl)

            var response: [String: Any]?
            DispatchQueue.main.sync {
                response = [
                    "ok": true,
                    "url": webTab.url?.absoluteString ?? b.url,
                    "title": webTab.title,
                    "loadState": webTab.loadState
                ]
            }
            let body = try? JSONSerialization.data(withJSONObject: response ?? [:])
            return .ok(json: body ?? Data())
        }

        router.post(prefix: Self.routePrefix, path: "/back") { [weak self] _ in
            guard let self else { return .notFound() }
            DispatchQueue.main.sync {
                self.activeWebTab()?.goBackSynchronously()
            }
            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }

        router.post(prefix: Self.routePrefix, path: "/forward") { [weak self] _ in
            guard let self else { return .notFound() }
            DispatchQueue.main.sync {
                self.activeWebTab()?.goForwardSynchronously()
            }
            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }

        router.post(prefix: Self.routePrefix, path: "/reload") { [weak self] _ in
            guard let self else { return .notFound() }
            DispatchQueue.main.sync {
                self.activeWebTab()?.reloadSynchronously()
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
            var state: [String: Any]?
            DispatchQueue.main.sync {
                var webTab: WebTab?
                if let id = tabId {
                    webTab = self.tabsController.webTab(for: id)
                } else {
                    webTab = self.activeWebTab()
                }
                guard let tab = webTab else { return }
                state = [
                    "tabId": tab.id,
                    "url": tab.url?.absoluteString ?? "",
                    "title": tab.title,
                    "loadState": tab.loadState,
                    "canGoBack": tab.canGoBack,
                    "canGoForward": tab.canGoForward,
                    "progress": tab.progress
                ]
            }
            guard let s = state else {
                return .badRequest("tab not found")
            }
            let json = try! JSONSerialization.data(withJSONObject: s)
            return .ok(json: json)
        }

        router.post(prefix: Self.routePrefix, path: "/eval") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Decodable { let js: String }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"js\": String}")
            }
            var evalResult: [String: Any]?
            let sem = DispatchSemaphore(value: 0)
            var webTab: WebTab?
            DispatchQueue.main.sync {
                webTab = self.activeWebTab()
            }
            guard let tab = webTab else {
                return .serverError("no active tab")
            }
            DispatchQueue.main.async {
                tab.webView.evaluateJavaScript(b.js) { res, err in
                    if let err = err {
                        evalResult = ["error": "\(err)"]
                    } else if let value = res {
                        evalResult = ["result": value]
                    } else {
                        evalResult = ["result": NSNull()]
                    }
                    sem.signal()
                }
            }
            _ = sem.wait(timeout: .now() + 10)
            guard let result = evalResult else {
                return .serverError("eval timed out")
            }
            if let errMsg = result["error"] as? String {
                return .serverError(errMsg)
            }
            var responseData: Data
            if let resultValue = result["result"] {
                if resultValue is NSNull {
                    responseData = "{\"result\":null}".data(using: .utf8)!
                } else if let s = resultValue as? String {
                    let responseObj = ["result": s]
                    responseData = (try? JSONSerialization.data(withJSONObject: responseObj)) ?? Data()
                } else if let num = resultValue as? NSNumber {
                    if CFBooleanGetTypeID() == CFGetTypeID(num) {
                        let responseObj = ["result": num.boolValue]
                        responseData = (try? JSONSerialization.data(withJSONObject: responseObj)) ?? Data()
                    } else {
                        let responseObj: [String: Any] = ["result": num.doubleValue]
                        responseData = (try? JSONSerialization.data(withJSONObject: responseObj)) ?? Data()
                    }
                } else if let dict = resultValue as? [String: Any] {
                    responseData = try! JSONSerialization.data(withJSONObject: ["result": dict])
                } else if let arr = resultValue as? [Any] {
                    responseData = try! JSONSerialization.data(withJSONObject: ["result": arr])
                } else {
                    let responseObj = ["result": "\(resultValue)"]
                    responseData = (try? JSONSerialization.data(withJSONObject: responseObj)) ?? Data()
                }
            } else {
                responseData = "{\"result\":null}".data(using: .utf8)!
            }
            return .ok(json: responseData)
        }
    }
}
