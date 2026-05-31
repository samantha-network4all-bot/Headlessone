import AppKit
import Foundation
import CryptoKit
import CommonCrypto

final class PasswordController: NSViewController {
    let vault = Vault()

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        TestAPIRouter.shared.register(controller: self)
    }
}

extension PasswordController: TestAPIControllerRoutes {
    static var routePrefix: String { "password" }

    func registerRoutes(on router: TestAPIRouter) {
        router.post(prefix: Self.routePrefix, path: "/unlock") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Codable { let master: String }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"master\": String}")
            }
            let fm = FileManager.default
            let vaultURL: URL
            if ProcessInfo.processInfo.environment["HEADLESSONE_TEST_API"] == "1" {
                vaultURL = fm.temporaryDirectory.appendingPathComponent("headlessone-vault.dat")
            } else {
                let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                vaultURL = appSupport.appendingPathComponent("Headlessone/vault.dat")
            }
            if fm.fileExists(atPath: vaultURL.path) {
                if self.vault.unlock(master: b.master) {
                    return .ok(json: Data("{\"ok\":true}\n".utf8))
                }
                return .badRequest("invalid master password")
            } else {
                self.vault.create(master: b.master)
                return .ok(json: Data("{\"ok\":true}\n".utf8))
            }
        }

        router.post(prefix: Self.routePrefix, path: "/lock") { [weak self] req in
            guard let self else { return .notFound() }
            self.vault.lock()
            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }

        router.post(prefix: Self.routePrefix, path: "/save") { [weak self] req in
            guard let self else { return .notFound() }
            struct Body: Codable { let origin: String; let username: String; let password: String }
            guard let b = try? JSONDecoder().decode(Body.self, from: req.body) else {
                return .badRequest("body must be {\"origin\":..., \"username\":..., \"password\":...}")
            }
            guard self.vault.isUnlocked() else {
                var r = TestAPIResponse()
                r.status = 200
                r.body = Data("{\"error\":\"vault is locked\"}\n".utf8)
                return r
            }
            self.vault.save(origin: b.origin, username: b.username, password: b.password)
            return .ok(json: Data("{\"ok\":true}\n".utf8))
        }

        router.get(prefix: Self.routePrefix, path: "/list") { [weak self] req in
            guard let self else { return .notFound() }
            guard self.vault.isUnlocked() else {
                var r = TestAPIResponse()
                r.status = 200
                r.body = Data("{\"error\":\"vault is locked\"}\n".utf8)
                return r
            }
            let origin = req.query["origin"]
            let items = self.vault.list(origin: origin)
            struct Item: Codable { let origin: String; let username: String }
            let output = items.compactMap { dict -> Item? in
                guard let o = dict["origin"], let u = dict["username"] else { return nil }
                return Item(origin: o, username: u)
            }
            var data = Data("[\n".utf8)
            for (i, item) in output.enumerated() {
                if let encoded = try? JSONEncoder().encode(item) {
                    data.append(encoded)
                    if i < output.count - 1 {
                        data.append(Data(",\n".utf8))
                    } else {
                        data.append(Data("\n".utf8))
                    }
                }
            }
            data.append(Data("]\n".utf8))
            return .ok(json: data)
        }

        router.get(prefix: Self.routePrefix, path: "/get") { [weak self] req in
            guard let self else { return .notFound() }
            guard self.vault.isUnlocked() else {
                var r = TestAPIResponse()
                r.status = 200
                r.body = Data("{\"error\":\"vault is locked\"}\n".utf8)
                return r
            }
            var origin = req.query["origin"]
            var username = req.query["username"]
            if origin == nil || username == nil {
                struct QBody: Codable { let origin: String; let username: String }
                if let b = try? JSONDecoder().decode(QBody.self, from: req.body) {
                    origin = origin ?? b.origin
                    username = username ?? b.username
                }
            }
            guard let origin = origin, let username = username else {
                return .badRequest("required query params: origin, username")
            }
            guard let password = self.vault.get(origin: origin, username: username) else {
                return .notFound()
            }
            struct Response: Codable { let password: String }
            let resp = Response(password: password)
            guard let data = try? JSONEncoder().encode(resp) else {
                return .serverError("encoding failed")
            }
            var json = data
            json.append(Data("\n".utf8))
            return .ok(json: json)
        }
    }
}
