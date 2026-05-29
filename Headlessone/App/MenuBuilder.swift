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
}
