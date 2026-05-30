import AppKit

final class HistoryController: NSViewController {
    let store = HistoryStore()
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

extension HistoryController: TestAPIControllerRoutes {
    static var routePrefix: String { "history" }

    func registerRoutes(on router: TestAPIRouter) {
        router.get(prefix: Self.routePrefix, path: "/list") { [weak self] _ in
            guard let self else { return .notFound() }
            var result: HistoryEntry?
            DispatchQueue.main.sync {
                result = self.store.list().first
            }
            guard let item = result else {
                return .ok(json: Data("{}".utf8))
            }
            let json = try? JSONEncoder().encode(item)
            return .ok(json: json ?? Data())
        }

        router.get(prefix: Self.routePrefix, path: "/search") { [weak self] req in
            guard let self else { return .notFound() }
            let q = req.query["q"] ?? ""
            var result: HistoryEntry?
            DispatchQueue.main.sync {
                result = self.store.search(q: q).first
            }
            guard let item = result else {
                return .ok(json: Data("{}".utf8))
            }
            let json = try? JSONEncoder().encode(item)
            return .ok(json: json ?? Data())
        }

        router.post(prefix: Self.routePrefix, path: "/clear") { [weak self] _ in
            guard let self else { return .notFound() }
            DispatchQueue.main.sync {
                self.store.clear()
            }
            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }
    }
}
