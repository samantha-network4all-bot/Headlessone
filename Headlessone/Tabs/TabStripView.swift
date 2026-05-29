import AppKit

final class TabStripView: NSView {
    private var tabButtons: [String: TabButton] = [:]
    private let newTabButton: NSButton
    private let scrollView: NSScrollView
    private let stackView: NSStackView

    var onTabClick: ((String) -> Void)?
    var onTabClose: ((String) -> Void)?
    var onNewTab: (() -> Void)?

    override init(frame frameRect: NSRect) {
        newTabButton = NSButton(title: "+", target: nil, action: #selector(newTabClicked))
        newTabButton.bezelStyle = .inline
        newTabButton.font = NSFont.systemFont(ofSize: 12)
        newTabButton.isBordered = false

        scrollView = NSScrollView()
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .none

        stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 1
        stackView.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        super.init(frame: frameRect)
        newTabButton.target = self

        scrollView.documentView = stackView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        newTabButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)
        addSubview(newTabButton)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.trailingAnchor.constraint(equalTo: newTabButton.leadingAnchor, constant: -4),

            newTabButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            newTabButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            newTabButton.widthAnchor.constraint(equalToConstant: 22),
            newTabButton.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func newTabClicked() {
        onNewTab?()
    }

    func addTabButton(id: String, title: String, active: Bool) {
        let btn = TabButton(title: title)
        btn.tabId = id
        btn.isActive = active
        btn.onClick = { [weak self] in self?.onTabClick?(id) }
        btn.onClose = { [weak self] in self?.onTabClose?(id) }
        tabButtons[id] = btn
        stackView.addArrangedSubview(btn)
        btn.widthAnchor.constraint(greaterThanOrEqualToConstant: Metrics.tabMinWidth).isActive = true
        btn.widthAnchor.constraint(lessThanOrEqualToConstant: Metrics.tabMaxWidth).isActive = true
    }

    func removeTabButton(id: String) {
        if let btn = tabButtons[id] {
            stackView.removeArrangedSubview(btn)
            btn.removeFromSuperview()
            tabButtons.removeValue(forKey: id)
        }
    }

    func setActiveTab(id: String) {
        for (tid, btn) in tabButtons {
            btn.isActive = (tid == id)
        }
    }

    func updateTabTitle(id: String, title: String) {
        tabButtons[id]?.setTitle(title)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        Palette.tabStripBackground.setFill()
        dirtyRect.fill()
    }
}
