import AppKit

final class RootView: NSView {
    let toolbarView: ToolbarView
    let tabStripView: TabStripView
    let contentAreaView: ContentAreaView
    private var findBarView: FindBarView?

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

    func showFindBar(_ bar: FindBarView) {
        if let existing = findBarView {
            existing.removeFromSuperview()
        }
        findBarView = bar
        bar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bar)
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: bottomAnchor),
            bar.heightAnchor.constraint(equalToConstant: Metrics.findBarHeight),
        ])
        // Move content area up to sit above the find bar
        // We need to update contentAreaView's bottom constraint
        for constraint in constraints {
            if constraint.firstItem === contentAreaView && constraint.firstAttribute == .bottom {
                constraint.isActive = false
                break
            }
        }
        NSLayoutConstraint.activate([
            contentAreaView.bottomAnchor.constraint(equalTo: bar.topAnchor),
        ])
    }

    func hideFindBar() {
        findBarView?.removeFromSuperview()
        findBarView = nil
        // Restore content area to bottom
        for constraint in constraints {
            if constraint.firstItem === contentAreaView && constraint.firstAttribute == .bottom {
                constraint.isActive = false
                break
            }
        }
        NSLayoutConstraint.activate([
            contentAreaView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
