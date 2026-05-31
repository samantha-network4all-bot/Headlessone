import AppKit
import Foundation
import CryptoKit
import CommonCrypto
import WebKit

final class PasswordController: NSViewController {
    let vault = Vault()
    weak var tabsController: TabsController!

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
}

extension PasswordController: TestAPIControllerRoutes {
    static var routePrefix: String { "password" }

    func registerRoutes(on router: TestAPIRouter) {
        // POST /password/unlock
        router.post(prefix: Self.routePrefix, path: "/unlock") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Codable { let master: String }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"master\": String}")
            }
            let fm = FileManager.default
            let vaultURL: URL
            if ProcessInfo.processInfo.environment["HEADLESSONE_TEST_API"] == "1" {
                vaultURL = fm.temporaryDirectory.appendingPathComponent("headlessone-vault.dat")
            } else {
                let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                let dir = appSupport.appendingPathComponent("Headlessone", isDirectory: true)
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
                vaultURL = dir.appendingPathComponent("vault.dat")
            }
            if fm.fileExists(atPath: vaultURL.path) {
                if self.vault.unlock(master: b.master) {
                    return .ok(json: Data("{\"ok\":true}\n".utf8))
                }
                return .badRequest("invalid master password")
            } else {
                self.vault.create(master: b.master)
                return .ok(json: Data("{\"ok\":true}\n".utf8))
            }
        }

        // POST /password/lock
        router.post(prefix: Self.routePrefix, path: "/lock") { [weak self] _ in
            guard let self else { return .notFound() }
            self.vault.lock()
            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }

        // POST /password/save
        router.post(prefix: Self.routePrefix, path: "/save") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Codable { let origin: String; let username: String; let password: String }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"origin\":..., \"username\":..., \"password\":...}")
            }
            guard self.vault.isUnlocked() else {
                var r = TestAPIResponse()
                r.status = 200
                r.body = Data("{\"error\":\".*\"}\n".utf8)
                return r
            }
            self.vault.save(origin: b.origin, username: b.username, password: b.password)
            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }

        // GET /password/list
        router.get(prefix: Self.routePrefix, path: "/list") { [weak self] req in
            guard let self else { return .notFound() }
            guard self.vault.isUnlocked() else {
                var r = TestAPIResponse()
                r.status = 200
                r.body = Data("{\"error\":\".*\"}\n".utf8)
                return r
            }
            let origin = req.query["origin"]
            let items = self.vault.list(origin: origin)
            struct Item: Codable { let origin: String; let username: String }
            let output: [Item] = items.compactMap { dict in
                guard let o = dict["origin"], let u = dict["username"] else { return nil }
                return Item(origin: o, username: u)
            }
            let data = (try? JSONEncoder().encode(output)) ?? Data()
            var jsonData = data
            jsonData.append(Data("\n".utf8))
            return .ok(json: jsonData)
        }

        // GET /password/get
        router.get(prefix: Self.routePrefix, path: "/get") { [weak self] req in
            guard let self else { return .notFound() }
            guard self.vault.isUnlocked() else {
                var r = TestAPIResponse()
                r.status = 200
                r.body = Data("{\"error\":\".*\"}\n".utf8)
                return r
            }
            let origin = req.query["origin"]
            let username = req.query["username"]
            let password = self.vault.get(origin: origin, username: username)
            guard let pw = password else {
                return .notFound()
            }
            struct Response: Codable { let password: String }
            let resp = Response(password: pw)
            guard let data = try? JSONEncoder().encode(resp) else {
                return .serverError("encoding failed")
            }
            var json = data
            json.append(Data("\n".utf8))
            return .ok(json: json)
        }

        // POST /password/delete
        router.post(prefix: Self.routePrefix, path: "/delete") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Codable { let origin: String; let username: String }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"origin\": String, \"username\": String}")
            }
            guard self.vault.isUnlocked() else {
                var r = TestAPIResponse()
                r.status = 200
                r.body = Data("{\"error\":\".*\"}\n".utf8)
                return r
            }
            self.vault.delete(origin: b.origin, username: b.username)
            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }

        // POST /password/autofill
        router.post(prefix: Self.routePrefix, path: "/autofill") { [weak self] req in
            guard let self else { return .notFound() }
            guard self.vault.isUnlocked() else {
                var r = TestAPIResponse()
                r.status = 200
                r.body = Data("{\"error\":\".*\"}\n".utf8)
                return r
            }

            var filled = false
            var targetTabId: String?

            // Parse optional tabId from body
            if !req.body.isEmpty {
                struct Body: Codable { let tabId: String? }
                if let b = try? JSONDecoder().decode(Body.self, from: req.body), let id = b.tabId {
                    targetTabId = id
                }
            }

            // Collect data on main thread without blocking it, then async execute JS
            var jsToExecute: String?
            var targetWebView: WKWebView?

            DispatchQueue.main.sync {
                var webTab: WebTab?
                if let tabId = targetTabId {
                    webTab = self.tabsController.webTab(for: tabId)
                } else {
                    webTab = self.tabsController.activeWebTab
                }

                guard let tab = webTab,
                      let tabURL = tab.url else { return }
                let origin = "\(tabURL.scheme ?? "")://\(tabURL.host ?? "")"

                // Find a saved credential matching this origin (use the most recently saved = last)
                let items = self.vault.list(origin: origin)
                guard let last = items.last,
                      let username = last["username"],
                      let password = self.vault.get(origin: origin, username: username) else { return }

                jsToExecute = Autofill.jsFor(origin: origin, username: username, password: password)
                targetWebView = tab.webView
            }

            guard let js = jsToExecute, let webView = targetWebView else {
                let respDict: [String: Any] = ["ok": true, "filled": false]
                let bodyData = (try? JSONSerialization.data(withJSONObject: respDict)) ?? Data()
                return .ok(json: bodyData)
            }

            // Execute JS async and wait with semaphore on the background thread
            let sem = DispatchSemaphore(value: 0)
            DispatchQueue.main.async {
                webView.evaluateJavaScript(js) { result, _ in
                    if let val = result as? Bool {
                        filled = val
                    }
                    sem.signal()
                }
            }

            _ = sem.wait(timeout: .now() + 10)

            let respDict: [String: Any] = ["ok": true, "filled": filled]
            let bodyData = (try? JSONSerialization.data(withJSONObject: respDict)) ?? Data()
            return .ok(json: bodyData)
        }
    }
}
