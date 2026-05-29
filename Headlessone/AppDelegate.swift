import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var appController: AppController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        appController = AppController()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
