import AppKit

final class TabButton: NSView {
    private let titleLabel: NSTextField
    private let closeButton: NSButton
    var onClick: (() -> Void)?
    var onClose: (() -> Void)?
    var tabId: String = ""

    var isActive: Bool = false {
        didSet { needsDisplay = true }
    }

    init(title: String) {
        titleLabel = NSTextField(labelWithString: title)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.font = NSFont.systemFont(ofSize: 11)
        closeButton = NSButton(title: "×", target: nil, action: #selector(closeClicked))
        closeButton.bezelStyle = .inline
        closeButton.font = NSFont.systemFont(ofSize: 11)
        closeButton.isBordered = false

        super.init(frame: .zero)
        closeButton.target = self

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -4),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 18),
        ])

        let tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(tracking)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setTitle(_ title: String) {
        titleLabel.stringValue = title
    }

    @objc private func closeClicked() {
        onClose?()
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isActive {
            Palette.tabActiveBackground.setFill()
        } else {
            Palette.tabInactiveBackground.setFill()
        }
        dirtyRect.fill()
        Palette.tabBorder.setStroke()
        let border = NSBezierPath(rect: bounds)
        border.lineWidth = 0.5
        border.stroke()
    }
}
