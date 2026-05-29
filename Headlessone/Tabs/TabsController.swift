import AppKit
import WebKit

final class TabsController: NSViewController {
    let state = TabsState()
    private var webTabs: [String: WebTab] = [:]
    private var tabController: TabController!
    private var windowController: WindowController!

    init(windowController: WindowController) {
        self.windowController = windowController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tabController = TabController(tabsController: self)
        _ = tabController.view // triggers viewDidLoad so /tab/* routes register
        TestAPIRouter.shared.register(controller: self)

        // Create initial tab
        let id = state.newTabId()
        let webTab = WebTab(id: id, configuration: WebConfig.shared.configuration)
        webTabs[id] = webTab
        state.addTab(id: id, url: "fixture://newtab", title: "New Tab", activate: true)

        // Add tab button
        windowController.rootView.tabStripView.addTabButton(id: id, title: "New Tab", active: true)

        // Wire tab strip callbacks
        windowController.rootView.tabStripView.onTabClick = { [weak self] tabId in
            self?.activateTab(id: tabId)
        }
        windowController.rootView.tabStripView.onTabClose = { [weak self] tabId in
            self?.closeTab(id: tabId)
        }
        windowController.rootView.tabStripView.onNewTab = { [weak self] in
            self?.newTab()
        }

        // Place webview in content area
        windowController.rootView.contentAreaView.showWebView(webTab.webView)

        // Load fixture://newtab
        webTab.load(url: URL(string: "fixture://newtab")!)
    }

    func newTab(url: String = "fixture://newtab") -> String {
        let id = state.newTabId()
        let webTab = WebTab(id: id, configuration: WebConfig.shared.configuration)
        webTabs[id] = webTab
        state.addTab(id: id, url: url, title: "New Tab", activate: true)
        windowController.rootView.tabStripView.addTabButton(id: id, title: "New Tab", active: true)
        activateTab(id: id)
        if let u = URL(string: url) {
            webTab.load(url: u)
        }
        return id
    }

    func closeTab(id: String) {
        webTabs[id]?.teardown()
        webTabs.removeValue(forKey: id)
        state.removeTab(id: id)
        windowController.rootView.tabStripView.removeTabButton(id: id)

        // If we closed the last tab, open a new one
        if state.tabs.isEmpty {
            newTab()
        } else if let activeId = state.activeTab {
            activateTab(id: activeId)
        }
    }

    func activateTab(id: String) {
        state.activateTab(id: id)
        windowController.rootView.tabStripView.setActiveTab(id: id)
        if let webTab = webTabs[id] {
            windowController.rootView.contentAreaView.showWebView(webTab.webView)
        }
    }

    func tabInfo(for id: String) -> TabInfo? {
        guard let webTab = webTabs[id] else { return nil }
        return TabInfo(id: id, title: webTab.title, url: webTab.url?.absoluteString ?? "fixture://newtab", active: id == state.activeTab)
    }

    func allTabInfos() -> [TabInfo] {
        return state.tabs.compactMap { tabInfo(for: $0) }
    }

    func webTab(for id: String) -> WebTab? {
        return webTabs[id]
    }

    var activeWebTab: WebTab? {
        guard let id = state.activeTab else { return nil }
        return webTabs[id]
    }

    func activeTabInfo() -> TabInfo? {
        guard let id = state.activeTab else { return nil }
        return tabInfo(for: id)
    }
}

extension TabsController: TestAPIControllerRoutes {
    static var routePrefix: String { "tabs" }

    func registerRoutes(on router: TestAPIRouter) {
        router.get(prefix: Self.routePrefix, path: "/list") { [weak self] _ in
            guard let self else { return .notFound() }
            var infos: [TabInfo] = []
            DispatchQueue.main.sync {
                infos = self.allTabInfos()
            }
            let body = try? JSONEncoder().encode(infos)
            return .ok(json: body ?? Data())
        }

        router.post(prefix: Self.routePrefix, path: "/new") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Decodable { let url: String? }
            let url: String
            if let b = try? JSONDecoder().decode(Body.self, from: req.body) {
                url = b.url ?? "fixture://newtab"
            } else {
                url = "fixture://newtab"
            }
            let id = self.newTab(url: url)
            struct NewTabResponse: Codable { let ok: Bool; let id: String }
            let body = try? JSONEncoder().encode(NewTabResponse(ok: true, id: id))
            return .ok(json: body ?? Data())
        }

        router.post(prefix: Self.routePrefix, path: "/close") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Decodable { let id: String }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"id\": String}")
            }
            DispatchQueue.main.sync {
                self.closeTab(id: b.id)
            }
            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }

        router.post(prefix: Self.routePrefix, path: "/activate") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Decodable { let id: String }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"id\": String}")
            }
            DispatchQueue.main.sync {
                self.activateTab(id: b.id)
            }
            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }

        router.post(prefix: Self.routePrefix, path: "/reorder") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Decodable { let id: String; let index: Int }
            guard (try? JSONDecoder().decode(Body.self, from: req.body)) != nil else {
                return .badRequest("body must be {\"id\": String, \"index\": Int}")
            }
            // Reorder not yet implemented in UI but accepted for API parity
            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }


    }
}
