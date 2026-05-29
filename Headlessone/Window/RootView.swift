import AppKit

final class RootView: NSView {
    let toolbarView: ToolbarView
    let tabStripView: TabStripView
    let contentAreaView: ContentAreaView

    init() {
        toolbarView = ToolbarView(frame: .zero)
        tabStripView = TabStripView(frame: .zero)
        contentAreaView = ContentAreaView(frame: .zero)
        super.init(frame: .zero)

        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        tabStripView.translatesAutoresizingMaskIntoConstraints = false
        contentAreaView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(toolbarView)
        addSubview(tabStripView)
        addSubview(contentAreaView)

        NSLayoutConstraint.activate([
            toolbarView.topAnchor.constraint(equalTo: topAnchor),
            toolbarView.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbarView.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbarView.heightAnchor.constraint(equalToConstant: Metrics.toolbarHeight),

            tabStripView.topAnchor.constraint(equalTo: toolbarView.bottomAnchor),
            tabStripView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tabStripView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tabStripView.heightAnchor.constraint(equalToConstant: Metrics.tabStripHeight),

            contentAreaView.topAnchor.constraint(equalTo: tabStripView.bottomAnchor),
            contentAreaView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentAreaView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentAreaView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}
