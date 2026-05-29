import AppKit

final class HeadlessoneWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        let style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        self.title = "Headlessone"
        self.isReleasedWhenClosed = false
        self.minSize = NSSize(width: 600, height: 400)
    }
}
