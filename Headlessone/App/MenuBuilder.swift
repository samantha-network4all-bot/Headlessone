import AppKit

final class MenuBuilder {
    static func buildMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "Headlessone")
        appMenuItem.submenu = appMenu
        appMenu.addItem(NSMenuItem(title: "About Headlessone", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Headlessone", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // File menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(NSMenuItem(title: "New Tab", action: #selector(AppController.newTab(_:)), keyEquivalent: "t"))
        fileMenu.addItem(NSMenuItem(title: "Close Tab", action: #selector(AppController.closeTab(_:)), keyEquivalent: "w"))

        // View menu
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        viewMenu.addItem(NSMenuItem(title: "Reload", action: #selector(AppController.reload(_:)), keyEquivalent: "r"))
        viewMenu.addItem(NSMenuItem(title: "Stop", action: #selector(AppController.stop(_:)), keyEquivalent: "."))
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(NSMenuItem(title: "Find…", action: #selector(AppController.find(_:)), keyEquivalent: "f"))

        // Bookmarks menu
        let bookmarksMenuItem = NSMenuItem()
        mainMenu.addItem(bookmarksMenuItem)
        let bookmarksMenu = NSMenu(title: "Bookmarks")
        bookmarksMenuItem.submenu = bookmarksMenu
        bookmarksMenu.addItem(NSMenuItem(title: "Add Bookmark", action: #selector(AppController.addBookmark(_:)), keyEquivalent: "d"))
        bookmarksMenu.addItem(NSMenuItem(title: "Show Bookmarks", action: #selector(AppController.showBookmarks(_:)), keyEquivalent: ""))

        // History menu
        let historyMenuItem = NSMenuItem()
        mainMenu.addItem(historyMenuItem)
        let historyMenu = NSMenu(title: "History")
        historyMenuItem.submenu = historyMenu
        historyMenu.addItem(NSMenuItem(title: "Back", action: #selector(AppController.goBack(_:)), keyEquivalent: "["))
        historyMenu.addItem(NSMenuItem(title: "Forward", action: #selector(AppController.goForward(_:)), keyEquivalent: "]"))
        historyMenu.addItem(NSMenuItem.separator())
        historyMenu.addItem(NSMenuItem(title: "Show History", action: #selector(AppController.showHistory(_:)), keyEquivalent: ""))
        historyMenu.addItem(NSMenuItem(title: "Clear History", action: #selector(AppController.clearHistory(_:)), keyEquivalent: ""))

        NSApp.mainMenu = mainMenu
    }
}

extension AppController {
    @objc func newTab(_ sender: Any?) {
        _ = tabsController.newTab()
    }

    @objc func closeTab(_ sender: Any?) {
        if let id = tabsController.state.activeTab {
            tabsController.closeTab(id: id)
        }
    }

    @objc func reload(_ sender: Any?) {
        DispatchQueue.main.async { [weak self] in
            self?.tabsController.activeWebTab?.webView.reload()
        }
    }

    @objc func stop(_ sender: Any?) {
        DispatchQueue.main.async { [weak self] in
            self?.tabsController.activeWebTab?.webView.stopLoading()
        }
    }

    @objc func find(_ sender: Any?) {
        DispatchQueue.main.async { [weak self] in
            self?.findController?.toggleFindBar()
        }
    }

    @objc func goBack(_ sender: Any?) {
        DispatchQueue.main.async { [weak self] in
            self?.tabsController.tabController.goBack()
        }
    }

    @objc func goForward(_ sender: Any?) {
        DispatchQueue.main.async { [weak self] in
            self?.tabsController.tabController.goForward()
        }
    }

    @objc func showHistory(_ sender: Any?) {
        // Placeholder — no panel required for this slice
    }

    @objc func clearHistory(_ sender: Any?) {
        DispatchQueue.main.async { [weak self] in
            self?.historyController.store.clear()
        }
    }

    @objc func addBookmark(_ sender: Any?) {
        // Placeholder — will use active tab URL/title via BookmarksController
    }

    @objc func showBookmarks(_ sender: Any?) {
        // Placeholder — no panel required for this slice
    }
}
