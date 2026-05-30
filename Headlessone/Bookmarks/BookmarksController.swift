import AppKit

final class BookmarksController: NSViewController {
    let store = BookmarksStore()
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

extension BookmarksController: TestAPIControllerRoutes {
    static var routePrefix: String { "bookmarks" }

    func registerRoutes(on router: TestAPIRouter) {
        router.get(prefix: Self.routePrefix, path: "/list") { [weak self] _ in
            guard let self else { return .notFound() }
            var result: [BookmarkEntry] = []
            DispatchQueue.main.sync {
                result = self.store.list()
            }
            let items = result.map { e in
                ["id": e.id, "url": e.url, "title": e.title, "addedAt": e.addedAt]
            }
            let json = try? JSONSerialization.data(withJSONObject: items)
            return .ok(json: json ?? Data())
        }

        router.post(prefix: Self.routePrefix, path: "/add") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Decodable { let url: String; let title: String }
            guard let body = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"url\": String, \"title\": String}")
            }
            var id = ""
            DispatchQueue.main.sync {
                id = self.store.add(url: body.url, title: body.title)
            }
            let json = try? JSONSerialization.data(withJSONObject: ["ok": true, "id": id])
            return .ok(json: json ?? Data())
        }

        router.post(prefix: Self.routePrefix, path: "/delete") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Decodable { let id: String }
            guard let body = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"id\": String}")
            }
            DispatchQueue.main.sync {
                self.store.delete(id: body.id)
            }
            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }
    }
}
