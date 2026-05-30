import Foundation

struct DownloadEntry: Codable, Equatable {
    let id: String
    let url: String
    let filename: String
    var state: String
    var bytesReceived: Int
}

final class DownloadsStore {
    private let fileURL: URL
    private var entries: [DownloadEntry] = []

    init() {
        let isTest = ProcessInfo.processInfo.environment["HEADLESSONE_TEST_API"] == "1"
        if isTest {
            let tmpDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("headlessone-test-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            self.fileURL = tmpDir.appendingPathComponent("downloads.json")
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("Headlessone")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("downloads.json")
        }
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([DownloadEntry].self, from: data) else {
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
    func add(id: String? = nil, url: String, filename: String) -> String {
        let entry = DownloadEntry(id: id ?? UUID().uuidString, url: url, filename: filename, state: "running", bytesReceived: 0)
        entries.append(entry)
        save()
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
                save()
                return
            }
        }
    }

    func clear() {
        entries = []
        save()
    }

    func filename(for id: String) -> String? {
        for e in entries {
            if e.id == id {
                return e.filename
            }
        }
        return nil
    }

    func bytesReceived(for id: String) -> Int {
        for e in entries {
            if e.id == id {
                return e.bytesReceived
            }
        }
        return 0
    }
}
