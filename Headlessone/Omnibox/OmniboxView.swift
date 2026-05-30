import AppKit

final class OmniboxView: NSTextField, NSTextFieldDelegate {
    var onSubmit: ((String) -> Void)?
    var onBeginEditing: (() -> Void)?
    var onEndEditing: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.placeholderString = "Search or enter URL"
        self.font = NSFont.systemFont(ofSize: 13)
        self.target = self
        self.action = #selector(submit)
        self.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func submit() {
        onSubmit?(stringValue)
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidBeginEditing(_ obj: Notification) {
        onBeginEditing?()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        onEndEditing?()
    }

    // MARK: - Helpers

    func setEditingURL(_ url: String) {
        stringValue = url
    }

    func syncFromActiveTab(url: String) {
        if !isEditing {
            stringValue = url
        }
    }

    private var isEditing: Bool {
        return currentEditor() != nil
    }
}
