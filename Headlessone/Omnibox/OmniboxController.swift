import AppKit

final class OmniboxController: NSViewController {
    let state = OmniboxState()
    let omniboxView = OmniboxView(frame: .zero)
    weak var tabsController: TabsController?

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = omniboxView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        omniboxView.onSubmit = { [weak self] text in
            _ = self?.submit(text: text)
        }
        omniboxView.onBeginEditing = { [weak self] in
            guard let self else { return }
            let url = self.tabsController?.activeWebTab?.url?.absoluteString ?? self.state.text
            self.omniboxView.setEditingURL(url)
        }
        omniboxView.onEndEditing = { [weak self] in
            guard let self else { return }
            if let url = self.tabsController?.activeWebTab?.url?.absoluteString {
                self.omniboxView.syncFromActiveTab(url: url)
            }
        }
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

    @discardableResult
    func submit(text: String) -> (navigatedTo: String, ok: Bool) {
        let url = resolveURL(from: text)
        guard let targetURL = URL(string: url) else {
            state.text = url
            return (url, true)
        }
        if let webTab = tabsController?.activeWebTab {
            webTab.navigateSynchronously(url: targetURL)
        }
        state.text = url
        omniboxView.stringValue = url
        return (url, true)
    }

    private func resolveAndNavigate(text: String) -> String {
        let url = resolveURL(from: text)
        guard let targetURL = URL(string: url) else {
            self.state.text = url
            DispatchQueue.main.sync {
                self.omniboxView.stringValue = url
            }
            return url
        }
        self.tabsController?.activeWebTab?.navigateSynchronously(url: targetURL)
        self.state.text = url
        DispatchQueue.main.sync {
            self.omniboxView.stringValue = url
        }
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
            let resolvedUrl = self.resolveAndNavigate(text: b.text)
            struct SubmitResponse: Codable { let ok: Bool; let navigatedTo: String }
            let bodyData = try? JSONEncoder().encode(SubmitResponse(ok: true, navigatedTo: resolvedUrl))
            return .ok(json: bodyData ?? Data())
        }

        router.get(prefix: Self.routePrefix, path: "/state") { [weak self] _ in
            guard let self else { return .notFound() }
            let text = self.state.text
            let body = try? JSONEncoder().encode(["text": text])
            return .ok(json: body ?? Data())
        }
    }
}
