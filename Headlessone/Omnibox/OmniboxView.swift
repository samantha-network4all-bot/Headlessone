import AppKit

final class OmniboxView: NSTextField {
    var onSubmit: ((String) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.placeholderString = "Search or enter URL"
        self.font = NSFont.systemFont(ofSize: 13)
        self.target = self
        self.action = #selector(submit)
        self.delegate = nil
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func submit() {
        onSubmit?(stringValue)
    }

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
