import Foundation

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

    private var nextId: Int = 1

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([BookmarkEntry].self, from: data) else {
            entries = []
            nextId = 1
            return
        }
        entries = decoded
        nextId = (entries.compactMap { entry in
            guard entry.id.hasPrefix("b"), let n = Int(entry.id.dropFirst()) else { return nil }
            return n
        }.max() ?? 0) + 1
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL)
    }

    private func makeId() -> String {
        let id = "b\(nextId)"
        nextId += 1
        return id
    }

    /// Add a bookmark at the front (most-recent-first). Returns the id.
    @discardableResult
    func add(url: String, title: String) -> String {
        let formatter = ISO8601DateFormatter()
        let entry = BookmarkEntry(id: makeId(), url: url, title: title, addedAt: formatter.string(from: Date()))
        entries.insert(entry, at: 0)
        save()
        return entry.id
    }

    /// Return all bookmarks most-recent-first.
    func list() -> [BookmarkEntry] {
        return entries
    }

    /// Delete by positional index: "b1" = index 0, "b2" = index 1.
    func delete(id: String) {
        guard id.hasPrefix("b"), let n = Int(id.dropFirst()) else { return }
        let idx = n - 1
        guard idx >= 0 && idx < entries.count else { return }
        entries.remove(at: idx)
        save()
    }

    func clear() {
        entries = []
        save()
    }
}
