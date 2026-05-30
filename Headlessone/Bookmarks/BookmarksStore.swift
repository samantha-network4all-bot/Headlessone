import Foundation

// MARK: - BookmarkEntry
struct BookmarkEntry: Codable, Equatable {
    let id: String
    let url: String
    let title: String
    let addedAt: String
}

final class BookmarksStore {
    private let fileURL: URL
    private var entries: [BookmarkEntry] = []

    init() {
        let isTest = ProcessInfo.processInfo.environment["HEADLESSONE_TEST_API"] == "1"
        if isTest {
            let tmpDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("headlessone-test-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            self.fileURL = tmpDir.appendingPathComponent("bookmarks.json")
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("Headlessone")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("bookmarks.json")
        }
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([BookmarkEntry].self, from: data) else {
            entries = []
            return
        }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL)
    }

    @discardableResult
    func add(url: String, title: String) -> String {
        let id = UUID().uuidString
        let formatter = ISO8601DateFormatter()
        let entry = BookmarkEntry(id: id, url: url, title: title, addedAt: formatter.string(from: Date()))
        entries.append(entry)
        save()
        return id
    }

    func list() -> [BookmarkEntry] {
        return entries.reversed()
    }

    func delete(id: String) {
        entries.removeAll { $0.id == id }
        save()
    }
}
