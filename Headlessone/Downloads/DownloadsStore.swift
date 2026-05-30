import Foundation

struct DownloadEntry: Codable, Equatable {
    let id: String
    let url: String
    let filename: String
    var state: String
    var bytesReceived: Int
}

final class DownloadsStore {
    private var entries: [DownloadEntry] = []
    private var nextId: Int = 1

    @discardableResult
    func add(url: String, filename: String) -> String {
        let id = "d\(nextId)"
        nextId += 1
        let entry = DownloadEntry(id: id, url: url, filename: filename, state: "running", bytesReceived: 0)
        entries.append(entry)
        return entry.id
    }

    func list() -> [DownloadEntry] {
        return entries.reversed()
    }

    func update(id: String, state: String, bytesReceived: Int) {
        for i in 0..<entries.count {
            if entries[i].id == id {
                entries[i].state = state
                entries[i].bytesReceived = bytesReceived
                return
            }
        }
    }

    func remove(id: String) {
        entries.removeAll { $0.id == id }
    }
}
