import Foundation

struct TabInfo: Codable {
    let id: String
    var title: String
    var url: String
    var active: Bool
}

final class TabsState {
    private(set) var tabs: [String] = []
    private(set) var activeTabId: String?
    private var counter = 0

    var activeTab: String? { activeTabId }

    func newTabId() -> String {
        counter += 1
        return "t\(counter)"
    }

    func addTab(id: String, url: String, title: String = "New Tab", activate: Bool = true) {
        tabs.append(id)
        if activate || activeTabId == nil {
            activeTabId = id
        }
    }

    func removeTab(id: String) {
        tabs.removeAll { $0 == id }
        if activeTabId == id {
            activeTabId = tabs.first
        }
    }

    func activateTab(id: String) {
        if tabs.contains(id) {
            activeTabId = id
        }
    }

    func info(for id: String, title: String = "New Tab", url: String = "fixture://newtab") -> TabInfo {
        return TabInfo(id: id, title: title, url: url, active: id == activeTabId)
    }

    func allInfos(titleMap: [String: String] = [:], urlMap: [String: String] = [:]) -> [TabInfo] {
        return tabs.map { id in
            TabInfo(id: id, title: titleMap[id] ?? "New Tab", url: urlMap[id] ?? "fixture://newtab", active: id == activeTabId)
        }
    }
}
