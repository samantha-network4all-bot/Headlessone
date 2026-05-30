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
            var result: [(entry: BookmarkEntry, displayId: String)] = []
            DispatchQueue.main.sync {
                result = self.store.list()
            }
            let items = result.map { pair in
                ["id": pair.displayId, "url": pair.entry.url, "title": pair.entry.title, "addedAt": pair.entry.addedAt]
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
            var displayId: String?
            DispatchQueue.main.sync {
                _ = self.store.add(url: body.url, title: body.title)
                // After adding, the new entry is last in entries.
                // In the reversed list (most-recent-first), it appears at position 0 → displayId "b1"
                displayId = "b1"
            }
            let response = ["ok": true, "id": displayId ?? "b1"]
            let json = try? JSONSerialization.data(withJSONObject: response)
            return .ok(json: json ?? Data())
        }

        router.post(prefix: Self.routePrefix, path: "/delete") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Decodable { let id: String }
            guard let body = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"id\": String}")
            }
            DispatchQueue.main.sync {
                self.store.delete(displayId: body.id)
            }
            let json = try? JSONSerialization.data(withJSONObject: ["ok": true])
            return .ok(json: json ?? Data())
        }
    }
}
