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
    private var nextId: Int = 0

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
            nextId = 0
            return
        }
        entries = decoded
        nextId = (entries.compactMap { extractNumericId(from: $0.id) }.max() ?? -1) + 1
    }

    private func extractNumericId(from id: String) -> Int? {
        // Supports ".d5", "d5", or plain "5" formats
        let numericPart = id.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return Int(numericPart)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL)
    }

    @discardableResult
    func add(id: String? = nil, url: String, filename: String) -> String {
        let effectiveId: String
        if let provided = id, !provided.isEmpty {
            effectiveId = provided
            // Advance nextId if the provided id has a numeric component
            if let n = extractNumericId(from: provided), n >= nextId {
                nextId = n + 1
            }
        } else {
            effectiveId = ".d\(nextId)"
            nextId += 1
        }
        let entry = DownloadEntry(id: effectiveId, url: url, filename: filename, state: "running", bytesReceived: 0)
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
        nextId = 0
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
