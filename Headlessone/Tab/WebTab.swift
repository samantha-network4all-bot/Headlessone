import WebKit

final class WebTab: NSObject, WKNavigationDelegate {
    let id: String
    let webView: WKWebView

    var onNavigationFinished: ((URL, String) -> Void)?

    private(set) var url: URL?
    private(set) var title: String = "New Tab"
    internal(set) var loadState: String = "idle"
    private(set) var canGoBack: Bool = false
    private(set) var canGoForward: Bool = false
    private(set) var progress: Double = 0.0


    init(id: String, configuration: WKWebViewConfiguration) {
        self.id = id
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: [.new], context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.isLoading), options: [.new], context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack), options: [.new], context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward), options: [.new], context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: [.new], context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: [.new], context: nil)
    }

    func teardown() {
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.isLoading))
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack))
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward))
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.title))
        webView.navigationDelegate = nil
        webView.stopLoading()
    }

    func load(url: URL) -> Bool {
        DispatchQueue.main.async { [weak self] in
            self?.loadState = "loading"
            self?.url = url
            self?.webView.load(URLRequest(url: url, timeoutInterval: 5.0))
        }
        return true
    }

    private var navigationFinished = false

    func navigateSynchronously(url: URL, timeout: TimeInterval = 15.0) {
        navigationFinished = false
        let request = URLRequest(url: url, timeoutInterval: min(5.0, timeout))
        if Thread.isMainThread {
            self.loadState = "loading"
            self.url = url
            self.webView.load(request)
        } else {
            DispatchQueue.main.sync {
                self.loadState = "loading"
                self.url = url
                self.webView.load(request)
            }
        }
        let deadline = Date().addingTimeInterval(timeout)
        while !navigationFinished && Date() < deadline {
            // Spin the current thread's run loop to let events process
            if Thread.isMainThread {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
            } else {
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
    }

    func goBackSynchronously(timeout: TimeInterval = 15.0) {
        if webView.canGoBack {
            navigationFinished = false
            if Thread.isMainThread {
                webView.goBack()
            } else {
                DispatchQueue.main.sync { self.webView.goBack() }
            }
            waitForSettled(timeout: timeout)
        }
    }

    func goForwardSynchronously(timeout: TimeInterval = 15.0) {
        if webView.canGoForward {
            navigationFinished = false
            if Thread.isMainThread {
                webView.goForward()
            } else {
                DispatchQueue.main.sync { self.webView.goForward() }
            }
            waitForSettled(timeout: timeout)
        }
    }

    func reloadSynchronously(timeout: TimeInterval = 15.0) {
        navigationFinished = false
        if Thread.isMainThread {
            webView.reload()
        } else {
            DispatchQueue.main.sync { self.webView.reload() }
        }
        waitForSettled(timeout: timeout)
    }

    private func waitForSettled(timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while !navigationFinished && Date() < deadline {
            if Thread.isMainThread {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
            } else {
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
    }

    @objc override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(WKWebView.estimatedProgress) {
            progress = webView.estimatedProgress
        } else if keyPath == #keyPath(WKWebView.isLoading) {
            if !webView.isLoading && loadState == "loading" {
                // Handled in navigation delegate
            }
        } else if keyPath == #keyPath(WKWebView.canGoBack) {
            canGoBack = webView.canGoBack
        } else if keyPath == #keyPath(WKWebView.canGoForward) {
            canGoForward = webView.canGoForward
        } else if keyPath == #keyPath(WKWebView.url) {
            url = webView.url
        } else if keyPath == #keyPath(WKWebView.title) {
            if let t = webView.title, !t.isEmpty {
                title = t
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadState = "finished"
        if let u = webView.url { url = u }
        if let t = webView.title, !t.isEmpty { title = t }
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        navigationFinished = true
        if let u = url {
            onNavigationFinished?(u, title)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadState = "failed"
        navigationFinished = true
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadState = "failed"
        navigationFinished = true
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        // no-op
    }


}
