import AppKit

final class OmniboxView: NSTextField {
    var onSubmit: ((String) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.placeholderString = "Search or enter URL"
        self.font = NSFont.systemFont(ofSize: 13)
        self.target = self
        self.action = #selector(submit)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func submit() {
        onSubmit?(stringValue)
    }
}
