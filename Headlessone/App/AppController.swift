import AppKit
import WebKit

final class AppController: NSViewController {
    var windowController: WindowController!
    var tabsController: TabsController!
    var omniboxController: OmniboxController!
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
