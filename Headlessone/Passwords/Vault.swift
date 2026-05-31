import Foundation
import CryptoKit
import CommonCrypto

struct PasswordEntry: Codable, Equatable {
    let origin: String
    let username: String
    let password: String
}

final class Vault {
    private let iterations: UInt32 = 200_000
    private let saltLength = 16
    private let nonceLength = 12
    private let keyLength = 32

    private var entries: [PasswordEntry] = []
    private var key: Data?

    private var vaultURL: URL {
        if ProcessInfo.processInfo.environment["HEADLESSONE_TEST_API"] == "1" {
            let tempDir = FileManager.default.temporaryDirectory
            return tempDir.appendingPathComponent("headlessone-vault.dat")
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Headlessone", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("vault.dat")
    }

    private func deriveKey(master: String, salt: Data) -> Data {
        var derived = Data(count: keyLength)
        let masterData = Data(master.utf8)
        derived.withUnsafeMutableBytes { derivedBytes in
            salt.withUnsafeBytes { saltBytes in
                masterData.withUnsafeBytes { masterBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        masterBytes.bindMemory(to: Int8.self).baseAddress,
                        masterData.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        iterations,
                        derivedBytes.bindMemory(to: UInt8.self).baseAddress,
                        keyLength
                    )
                }
            }
        }
        return derived
    }

    func create(master: String) {
        let salt = Data((0..<saltLength).map { _ in UInt8.random(in: 0...255) })
        key = deriveKey(master: master, salt: salt)
        entries = []
        persist(salt: salt)
    }

    func unlock(master: String) -> Bool {
        let data = try? Data(contentsOf: vaultURL)
        guard let data = data, data.count > saltLength else { return false }

        let salt = data.prefix(saltLength)
        let keyCandidate = deriveKey(master: master, salt: Data(salt))

        let ciphertext = data.dropFirst(saltLength)
        guard ciphertext.count > nonceLength else { return false }

        let nonceData = ciphertext.prefix(nonceLength)
        let sealedData = ciphertext.dropFirst(nonceLength)

        guard let nonce = try? AES.GCM.Nonce(data: nonceData),
              let sealedBox = try? AES.GCM.SealedBox(combined: nonceData + sealedData),
              let decrypted = try? AES.GCM.open(sealedBox, using: SymmetricKey(data: keyCandidate)) else {
            return false
        }

        guard let decoded = try? JSONDecoder().decode([PasswordEntry].self, from: decrypted) else {
            return false
        }

        key = keyCandidate
        entries = decoded
        return true
    }

    func lock() {
        key = nil
        entries = []
    }

    func isUnlocked() -> Bool {
        return key != nil
    }

    func save(origin: String, username: String, password: String) {
        guard isUnlocked() else { return }
        entries.removeAll { $0.origin == origin && $0.username == username }
        entries.append(PasswordEntry(origin: origin, username: username, password: password))
        persistWithExistingSalt()
    }

    func list(origin: String? = nil) -> [[String: String]] {
        guard isUnlocked() else { return [] }
        let filtered = origin != nil
            ? entries.filter { $0.origin == origin }
            : entries
        return filtered.map { ["origin": $0.origin, "username": $0.username] }
    }

    func get(origin: String, username: String) -> String? {
        guard isUnlocked() else { return nil }
        return entries.first { $0.origin == origin && $0.username == username }?.password
    }

    func get(origin: String? = nil, username: String? = nil) -> String? {
        guard isUnlocked() else { return nil }
        if let origin = origin, let username = username {
            return entries.first { $0.origin == origin && $0.username == username }?.password
        }
        if let origin = origin {
            return entries.first { $0.origin == origin }?.password
        }
        if let username = username {
            return entries.first { $0.username == username }?.password
        }
        return entries.first?.password
    }

    func delete(origin: String, username: String) {
        guard isUnlocked() else { return }
        entries.removeAll { $0.origin == origin && $0.username == username }
        persistWithExistingSalt()
    }

    func clear() {
        guard isUnlocked() else { return }
        entries = []
        persistWithExistingSalt()
    }

    private func persist(salt: Data) {
        guard let key = key else { return }
        guard let encoded = try? JSONEncoder().encode(entries) else { return }
        let nonce = AES.GCM.Nonce()
        guard let sealed = try? AES.GCM.seal(encoded, using: SymmetricKey(data: key), nonce: nonce) else { return }
        var data = Data()
        data.append(salt)
        data.append(sealed.combined!)
        try? data.write(to: vaultURL)
    }

    private func persistWithExistingSalt() {
        let existing = try? Data(contentsOf: vaultURL)
        let salt: Data
        if let existing = existing, existing.count >= saltLength {
            salt = Data(existing.prefix(saltLength))
        } else {
            salt = Data((0..<saltLength).map { _ in UInt8.random(in: 0...255) })
        }
        persist(salt: salt)
    }
}
