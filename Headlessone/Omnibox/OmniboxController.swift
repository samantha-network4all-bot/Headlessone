import AppKit

final class OmniboxController: NSViewController {
    let state = OmniboxState()
    weak var tabsController: TabsController?

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

    func resolveURL(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return trimmed
        }
        let schemes = ["http://", "https://", "file://", "fixture://", "data:"]
        if schemes.contains(where: { trimmed.lowercased().hasPrefix($0) }) {
            return trimmed
        }
        // Check if it looks like a host: "localhost", IP, or "xxx.yyy" with no spaces
        let isIP = trimmed.allSatisfy { $0.isNumber || $0 == "." || $0 == ":" }
        let hasDottedName = trimmed.contains(".") && !trimmed.contains(" ") && !trimmed.contains("..")
        if isIP || hasDottedName || trimmed == "localhost" {
            return "https://" + trimmed
        }
        // Otherwise search
        let escaped = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return "https://duckduckgo.com/?q=\(escaped)"
    }

    func submit(text: String) -> String {
        let url = resolveURL(from: text)
        guard let targetURL = URL(string: url) else { return url }
        if let webTab = tabsController?.activeWebTab {
            webTab.navigateSynchronously(url: targetURL)
        }
        state.text = url
        return url
    }
}

extension OmniboxController: TestAPIControllerRoutes {
    static var routePrefix: String { "omnibox" }

    func registerRoutes(on router: TestAPIRouter) {
        router.post(prefix: Self.routePrefix, path: "/submit") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Decodable { let text: String }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"text\": String}")
            }
            var navigatedTo = ""
            DispatchQueue.main.sync {
                navigatedTo = self.submit(text: b.text)
            }
            struct SubmitResponse: Codable { let ok: Bool; let navigatedTo: String }
            let body = try? JSONEncoder().encode(SubmitResponse(ok: true, navigatedTo: navigatedTo))
            return .ok(json: body ?? Data())
        }

        router.get(prefix: Self.routePrefix, path: "/state") { [weak self] _ in
            guard let self else { return .notFound() }
            let body = try? JSONEncoder().encode(["text": self.state.text])
            return .ok(json: body ?? Data())
        }
    }
}
