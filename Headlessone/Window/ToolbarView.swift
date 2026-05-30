import AppKit

final class ToolbarView: NSView {
    private let backButton: NSButton
    private let forwardButton: NSButton
    private let reloadButton: NSButton
    private let stopButton: NSButton
    private let omniboxView: OmniboxView

    private(set) var omniboxText: String {
        get { omniboxView.stringValue }
        set { omniboxView.stringValue = newValue }
    }

    var onBack: (() -> Void)?
    var onForward: (() -> Void)?
    var onReload: (() -> Void)?
    var onStop: (() -> Void)?
    var onOmniboxSubmit: ((String) -> Void)?

    override init(frame frameRect: NSRect) {
        backButton = NSButton(image: NSImage(named: NSImage.goBackTemplateName)!, target: nil, action: #selector(backClicked))
        forwardButton = NSButton(image: NSImage(named: NSImage.goForwardTemplateName)!, target: nil, action: #selector(forwardClicked))
        reloadButton = NSButton(image: NSImage(named: NSImage.refreshTemplateName)!, target: nil, action: #selector(reloadClicked))
        stopButton = NSButton(image: NSImage(named: NSImage.stopProgressTemplateName)!, target: nil, action: #selector(stopClicked))
        omniboxView = OmniboxView(frame: .zero)

        super.init(frame: frameRect)
        backButton.target = self
        forwardButton.target = self
        reloadButton.target = self
        stopButton.target = self
        omniboxView.target = self
        omniboxView.action = #selector(omniboxSubmit)
        omniboxView.onSubmit = { [weak self] text in
            self?.onOmniboxSubmit?(text)
        }

        backButton.translatesAutoresizingMaskIntoConstraints = false
        forwardButton.translatesAutoresizingMaskIntoConstraints = false
        reloadButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        omniboxView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(backButton)
        addSubview(forwardButton)
        addSubview(reloadButton)
        addSubview(stopButton)
        addSubview(omniboxView)

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            backButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: Metrics.navButton),
            backButton.heightAnchor.constraint(equalToConstant: Metrics.navButton),

            forwardButton.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 4),
            forwardButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            forwardButton.widthAnchor.constraint(equalToConstant: Metrics.navButton),
            forwardButton.heightAnchor.constraint(equalToConstant: Metrics.navButton),

            reloadButton.leadingAnchor.constraint(equalTo: forwardButton.trailingAnchor, constant: 4),
            reloadButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            reloadButton.widthAnchor.constraint(equalToConstant: Metrics.navButton),
            reloadButton.heightAnchor.constraint(equalToConstant: Metrics.navButton),

            stopButton.leadingAnchor.constraint(equalTo: reloadButton.trailingAnchor, constant: 4),
            stopButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            stopButton.widthAnchor.constraint(equalToConstant: Metrics.navButton),
            stopButton.heightAnchor.constraint(equalToConstant: Metrics.navButton),

            omniboxView.leadingAnchor.constraint(equalTo: stopButton.trailingAnchor, constant: 8),
            omniboxView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            omniboxView.centerYAnchor.constraint(equalTo: centerYAnchor),
            omniboxView.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func backClicked() { onBack?() }
    @objc private func forwardClicked() { onForward?() }
    @objc private func reloadClicked() { onReload?() }
    @objc private func stopClicked() { onStop?() }

    @objc private func omniboxSubmit() {
        onOmniboxSubmit?(omniboxView.stringValue)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        Palette.toolbarBackground.setFill()
        dirtyRect.fill()
    }
}
