import AppKit
import WebKit

final class FindController: NSViewController {
    var findBarView: FindBarView!
    private var query: String = ""
    private var matchCount: Int = 0
    private var activeMatch: Int = 0
    private var findSemaphore: DispatchSemaphore?
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

    func activeWebView() -> WKWebView? {
        return tabsController?.activeWebTab?.webView
    }

    func startFind(query: String) {
        self.query = query
        self.matchCount = 0
        self.activeMatch = 0
        guard let webView = activeWebView() else { return }

        // First, perform the native find to highlight matches
        let config = WKFindConfiguration()
        config.backwards = false
        config.wraps = true
        webView.find(query, configuration: config) { [weak self] _ in
            self?.countMatches(in: webView, query: query)
        }
    }

    private func countMatches(in webView: WKWebView, query: String) {
        guard !query.isEmpty else {
            findSemaphore?.signal()
            return
        }
        // Escape the query for JS
        let escaped = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")

        let js = """
        (function() {
            var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
            var count = 0;
            var q = '\(escaped)';
            var qlen = q.length;
            if (qlen === 0) return 0;
            var node;
            while (node = walker.nextNode()) {
                var text = node.textContent.toLowerCase();
                var lowerq = q.toLowerCase();
                var idx = 0;
                while ((idx = text.indexOf(lowerq, idx)) !== -1) {
                    count++;
                    idx += qlen;
                }
            }
            return count;
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self = self else { return }
            if let count = result as? Int, count > 0 {
                self.matchCount = count
                self.activeMatch = 1
            } else {
                self.matchCount = 0
                self.activeMatch = 0
            }
            DispatchQueue.main.async {
                self.updateFindBarLabel()
            }
            self.findSemaphore?.signal()
        }
    }

    func doFindNext() {
        guard !query.isEmpty, matchCount > 0 else { return }
        if activeMatch < matchCount {
            activeMatch += 1
        } else {
            activeMatch = 1
        }
        highlightFind()
        updateFindBarLabel()
    }

    func doFindPrev() {
        guard !query.isEmpty, matchCount > 0 else { return }
        if activeMatch > 1 {
            activeMatch -= 1
        } else {
            activeMatch = matchCount
        }
        highlightFind()
        updateFindBarLabel()
    }

    private func highlightFind() {
        guard let webView = activeWebView(), !query.isEmpty else { return }
        let config = WKFindConfiguration()
        config.backwards = false
        config.wraps = true
        webView.find(query, configuration: config) { _ in }
    }

    func closeFind() {
        query = ""
        matchCount = 0
        activeMatch = 0
        guard let webView = activeWebView() else { return }
        let clearConfig = WKFindConfiguration()
        clearConfig.backwards = false
        webView.find("", configuration: clearConfig) { _ in }
        updateFindBarLabel()
    }

    func updateFindBarLabel() {
        findBarView?.setMatchLabel(current: activeMatch, total: matchCount)
    }

    func toggleFindBar() {
        guard let windowController = tabsController?.windowController else { return }
        let root = windowController.rootView
        if findBarView != nil && findBarView?.superview != nil {
            closeFind()
            root.hideFindBar()
        } else {
            let bar = FindBarView(frame: .zero)
            bar.setQueryText(query)
            bar.setMatchLabel(current: activeMatch, total: matchCount)
            bar.onSearchQuery = { [weak self] text in
                self?.startFind(query: text)
            }
            bar.onNext = { [weak self] in
                self?.doFindNext()
            }
            bar.onPrev = { [weak self] in
                self?.doFindPrev()
            }
            bar.onClose = { [weak self] in
                guard let self else { return }
                self.closeFind()
                root.hideFindBar()
            }
            findBarView = bar
            root.showFindBar(bar)
        }
    }
}

extension FindController: TestAPIControllerRoutes {
    static var routePrefix: String { "find" }

    func registerRoutes(on router: TestAPIRouter) {
        router.post(prefix: Self.routePrefix, path: "/start") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Decodable { let query: String }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"query\": String}")
            }
            let sem = DispatchSemaphore(value: 0)
            self.findSemaphore = sem
            DispatchQueue.main.sync {
                self.startFind(query: b.query)
            }
            // Wait for the JS evaluate callback to signal
            _ = sem.wait(timeout: .now() + 10)
            self.findSemaphore = nil
            var response: [String: Any]?
            DispatchQueue.main.sync {
                response = [
                    "matchCount": self.matchCount,
                    "activeMatch": self.activeMatch
                ]
            }
            let body = try! JSONSerialization.data(withJSONObject: response ?? [:])
            return .ok(json: body)
        }

        router.post(prefix: Self.routePrefix, path: "/next") { [weak self] req in
            guard let self else { return .notFound() }
            DispatchQueue.main.sync {
                self.doFindNext()
            }
            var response: [String: Any]?
            DispatchQueue.main.sync {
                response = ["activeMatch": self.activeMatch]
            }
            let body = try! JSONSerialization.data(withJSONObject: response ?? [:])
            return .ok(json: body)
        }

        router.post(prefix: Self.routePrefix, path: "/prev") { [weak self] req in
            guard let self else { return .notFound() }
            DispatchQueue.main.sync {
                self.doFindPrev()
            }
            var response: [String: Any]?
            DispatchQueue.main.sync {
                response = ["activeMatch": self.activeMatch]
            }
            let body = try! JSONSerialization.data(withJSONObject: response ?? [:])
            return .ok(json: body)
        }

        router.post(prefix: Self.routePrefix, path: "/close") { [weak self] req in
            guard let self else { return .notFound() }
            DispatchQueue.main.sync {
                self.closeFind()
            }
            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }
    }
}
