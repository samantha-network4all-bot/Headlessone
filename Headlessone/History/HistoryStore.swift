import Foundation

struct HistoryEntry: Codable, Equatable {
    let url: String
    let title: String
    let visitedAt: String
}

final class HistoryStore {
    private let fileURL: URL
    private var entries: [HistoryEntry] = []

    init() {
        let isTest = ProcessInfo.processInfo.environment["HEADLESSONE_TEST_API"] == "1"
        if isTest {
            let tmpDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("headlessone-test-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            self.fileURL = tmpDir.appendingPathComponent("history.json")
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("Headlessone")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("history.json")
        }
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
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
    func record(url: String, title: String) -> HistoryEntry {
        let formatter = ISO8601DateFormatter()
        let entry = HistoryEntry(url: url, title: title, visitedAt: formatter.string(from: Date()))
        entries.append(entry)
        save()
        return entry
    }

    func list() -> [HistoryEntry] {
        return entries.reversed()
    }

    func search(q: String) -> [HistoryEntry] {
        let lower = q.lowercased()
        return entries.reversed().filter {
            $0.url.lowercased().contains(lower) || $0.title.lowercased().contains(lower)
        }
    }

    func clear() {
        entries = []
        save()
    }
}
