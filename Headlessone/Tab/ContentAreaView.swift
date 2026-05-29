import AppKit
import WebKit

final class ContentAreaView: NSView {
    private var activeWebView: WKWebView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) { fatalError() }

    func showWebView(_ webView: WKWebView) {
        if let current = activeWebView {
            current.removeFromSuperview()
        }
        activeWebView = webView
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func currentWebView() -> WKWebView? {
        return activeWebView
    }
}
