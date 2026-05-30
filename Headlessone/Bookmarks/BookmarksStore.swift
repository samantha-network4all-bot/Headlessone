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

    /// Append a new bookmark. Returns the internal UUID.
    @discardableResult
    func add(url: String, title: String) -> String {
        let id = UUID().uuidString
        let formatter = ISO8601DateFormatter()
        let entry = BookmarkEntry(id: id, url: url, title: title, addedAt: formatter.string(from: Date()))
        entries.append(entry)
        save()
        return id
    }

    /// Return bookmarks most-recent-first (reversed insertion order).
    /// `displayId` is the 1-based positional index ("b1", b2", …) for the API.
    func list() -> [(entry: BookmarkEntry, displayId: String)] {
        let reversed = entries.reversed()
        return reversed.enumerated().map { (index, entry) in
            (entry: entry, displayId: "b\(index + 1)")
        }
    }

    /// Delete by positional display id ("b1" = first in most-recent-first list).
    func delete(displayId: String) {
        guard let idx = Int(displayId.dropFirst()), idx >= 1 else { return }
        // Convert display position (1-based, most-recent-first) to entries array index.
        // Most-recent-first index 1 → last element of entries → entries.count - 1
        // Most-recent-first index idx → entries.count - idx
        let arrIdx = entries.count - idx
        guard arrIdx >= 0 && arrIdx < entries.count else { return }
        entries.remove(at: arrIdx)
        save()
    }

    func clear() {
        entries = []
        save()
    }
}
