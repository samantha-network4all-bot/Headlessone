import AppKit

final class WindowController: NSViewController {
    var window: HeadlessoneWindow!
    var rootView: RootView { view as! RootView }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = RootView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        TestAPIRouter.shared.register(controller: self)
    }

    func attachToWindow(_ win: HeadlessoneWindow) {
        window = win
        win.contentViewController = self
    }
}

extension WindowController: TestAPIControllerRoutes {
    static var routePrefix: String { "window" }

    func registerRoutes(on router: TestAPIRouter) {
        router.get(prefix: Self.routePrefix, path: "/list") { [weak self] _ in
            guard let self else { return .notFound() }
            let info = WindowInfo(id: "w1", title: "Headlessone", isKey: true)
            let body = try? JSONEncoder().encode(info)
            return .ok(json: body ?? Data())
        }
    }
}
