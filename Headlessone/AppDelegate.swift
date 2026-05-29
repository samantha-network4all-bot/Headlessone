import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var appController: AppController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        appController = AppController()
        // Trigger view loading so viewDidLoad fires (window creation, route registration, test API)
        _ = appController.view
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
