import AppKit
import WebKit

final class AppController: NSViewController {
    var windowController: WindowController!
    var tabsController: TabsController!
    var omniboxController: OmniboxController!
    var findController: FindController!
    var historyController: HistoryController!
    var bookmarksController: BookmarksController!
    var downloadsController: DownloadsController!
    var passwordController: PasswordController!
    var dataController: DataController!
    private var testAPIServer: TestAPIServer?

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Build menu bar
        MenuBuilder.buildMainMenu()

        // Create window controller and window
        windowController = WindowController()
        let win = HeadlessoneWindow(
            contentRect: NSRect(x: 100, y: 100, width: Metrics.defaultWindowSize.width, height: Metrics.defaultWindowSize.height),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        windowController.attachToWindow(win)

        // Create tabs controller (access .view to trigger viewDidLoad → route registration)
        tabsController = TabsController(windowController: windowController)
        _ = tabsController.view

        // Create omnibox controller
        omniboxController = OmniboxController()
        omniboxController.tabsController = tabsController
        _ = omniboxController.view

        // Wire toolbar buttons through TabController (single navigation path §8.3)
        let root = windowController.rootView
        let tabController = tabsController.tabController
        root.toolbarView.onBack = { [weak tabController] in
            tabController?.goBack()
        }
        root.toolbarView.onForward = { [weak tabController] in
            tabController?.goForward()
        }
        root.toolbarView.onReload = { [weak tabController] in
            tabController?.reload()
        }
        root.toolbarView.onStop = { [weak tabController] in
            tabController?.stop()
        }
        root.toolbarView.onOmniboxSubmit = { [weak self] text in
            _ = self?.omniboxController.submit(text: text)
        }

        // Create find controller
        findController = FindController()
        findController.tabsController = tabsController
        _ = findController.view // triggers viewDidLoad so /find/* routes register

        // Create history controller
        historyController = HistoryController()
        historyController.tabsController = tabsController
        _ = historyController.view // triggers viewDidLoad so /history/* routes register

        // Create bookmarks controller
        bookmarksController = BookmarksController()
        bookmarksController.tabsController = tabsController
        _ = bookmarksController.view // triggers viewDidLoad so /bookmarks/* routes register

        // Create downloads controller
        downloadsController = DownloadsController()
        downloadsController.tabsController = tabsController
        tabsController.downloadsController = downloadsController
        _ = downloadsController.view // triggers viewDidLoad so /downloads/* routes register

        // Create password controller
        passwordController = PasswordController()
        passwordController.tabsController = tabsController
        _ = passwordController.view // triggers viewDidLoad so /password/* routes register

        // Create data controller
        dataController = DataController(
            historyStore: historyController.store,
            bookmarksStore: bookmarksController.store,
            vault: passwordController.vault,
            websiteDataStore: WebConfig.shared.configuration.websiteDataStore
        )
        _ = dataController.view // triggers viewDidLoad so /data/* routes register

        // Wire history recording onto all current and future tabs
        let historyCallback: (URL, String) -> Void = { [weak self] url, title in
            guard let self else { return }
            self.historyController.store.record(url: url.absoluteString, title: title)
        }
        tabsController.onNavigationFinished = historyCallback
        // Wire onto any existing WebTabs already created by TabsController.init
        for tabInfo in tabsController.allTabInfos() {
            if let webTab = tabsController.webTab(for: tabInfo.id) {
                webTab.onNavigationFinished = historyCallback
            }
        }

        // Wire download start closure
        tabsController.onDownload = { [weak self] url in
            guard let self else { return }
            _ = self.downloadsController.start(url: url)
        }
        // Set download delegate on tabs controller level and existing webtabs
        for tabInfo in tabsController.allTabInfos() {
            if let webTab = tabsController.webTab(for: tabInfo.id) {
                webTab.onDownload = { [weak self] url in
                    guard let self else { return }
                    _ = self.downloadsController.start(url: url)
                }
                webTab.downloadDelegate = downloadsController
            }
        }

        // Register routes (top-level orchestrator routes)
        TestAPIRouter.shared.register(controller: self)

        // Start test API server if env var is set
        if ProcessInfo.processInfo.environment["HEADLESSONE_TEST_API"] == "1" {
            testAPIServer = TestAPIServer()
            do {
                try testAPIServer?.start()
            } catch {
                NSLog("Failed to start TestAPIServer: \(error)")
            }
        }

        // Show window
        win.makeKeyAndOrderFront(nil)
    }
}

extension AppController: TestAPIControllerRoutes {
    static var routePrefix: String { "" }

    func registerRoutes(on router: TestAPIRouter) {
        // Top-level routes (no prefix)
        router.get(prefix: "", path: "/healthz") { _ in
            .ok(json: Data("{\"ok\":true}\n".utf8))
        }

        router.post(prefix: "", path: "/shutdown") { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.terminate(nil)
            }
            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }

        router.get(prefix: "", path: "/screenshot") { [weak self] req in
            guard let self else { return .notFound() }

            var pngData: Data?
            DispatchQueue.main.sync {
                guard let win = self.windowController?.window else { return }
                guard let contentView = win.contentView else { return }
                let bounds = contentView.bounds
                guard let rep = contentView.bitmapImageRepForCachingDisplay(in: bounds) else { return }
                contentView.cacheDisplay(in: bounds, to: rep)
                pngData = rep.representation(using: .png, properties: [:])
            }

            guard let data = pngData else {
                return .serverError("failed to capture screenshot")
            }
            return .png(data)
        }
    }
}
