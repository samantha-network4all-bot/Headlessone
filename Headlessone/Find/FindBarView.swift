import AppKit

final class FindBarView: NSView {
    let searchField: NSSearchField
    let matchLabel: NSTextField
    let prevButton: NSButton
    let nextButton: NSButton
    let closeButton: NSButton

    var onSearchQuery: ((String) -> Void)?
    var onNext: (() -> Void)?
    var onPrev: (() -> Void)?
    var onClose: (() -> Void)?

    override init(frame frameRect: NSRect) {
        searchField = NSSearchField(frame: .zero)
        matchLabel = NSTextField(labelWithString: "0 of 0")
        prevButton = NSButton(title: "◀", target: nil, action: nil)
        nextButton = NSButton(title: "▶", target: nil, action: nil)
        closeButton = NSButton(title: "✕", target: nil, action: nil)
        super.init(frame: frameRect)

        searchField.translatesAutoresizingMaskIntoConstraints = false
        matchLabel.translatesAutoresizingMaskIntoConstraints = false
        prevButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(searchField)
        addSubview(matchLabel)
        addSubview(prevButton)
        addSubview(nextButton)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            searchField.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchField.widthAnchor.constraint(equalToConstant: 200),

            matchLabel.leadingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: 8),
            matchLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            prevButton.leadingAnchor.constraint(equalTo: matchLabel.trailingAnchor, constant: 8),
            prevButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            nextButton.leadingAnchor.constraint(equalTo: prevButton.trailingAnchor, constant: 4),
            nextButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        prevButton.target = self
        prevButton.action = #selector(prevClicked(_:))
        nextButton.target = self
        nextButton.action = #selector(nextClicked(_:))
        closeButton.target = self
        closeButton.action = #selector(closeClicked(_:))
    }

    required init?(coder: NSCoder) { fatalError() }

    func setMatchLabel(current: Int, total: Int) {
        if Thread.isMainThread {
            matchLabel.stringValue = "\(current) of \(total)"
        } else {
            DispatchQueue.main.sync {
                matchLabel.stringValue = "\(current) of \(total)"
            }
        }
    }

    func setQueryText(_ text: String) {
        if Thread.isMainThread {
            searchField.stringValue = text
        } else {
            DispatchQueue.main.sync {
                searchField.stringValue = text
            }
        }
    }

    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        onSearchQuery?(sender.stringValue)
    }

    @objc private func prevClicked(_ sender: NSButton) {
        onPrev?()
    }

    @objc private func nextClicked(_ sender: NSButton) {
        onNext?()
    }

    @objc private func closeClicked(_ sender: NSButton) {
        onClose?()
    }
}
