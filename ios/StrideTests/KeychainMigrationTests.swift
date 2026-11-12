import XCTest
@testable import Stride

final class MemorySecretBox: AISecretBox {
    var values: [String: String] = [:]
    var acceptWrites = true

    func read(account: String) -> String? { values[account] }

    func write(_ value: String, account: String) -> Bool {
        guard acceptWrites else { return false }
        values[account] = value
        return true
    }

    func delete(account: String) { values[account] = nil }
}

final class KeychainMigrationTests: XCTestCase {

    private func defaults() -> (UserDefaults, String) {
        let name = "stride.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (defaults, name)
    }

    private func storedKey(_ defaults: UserDefaults) throws -> String {
        let data = try XCTUnwrap(defaults.data(forKey: AIKeyVault.defaultsKey))
        return try JSONDecoder().decode(AIConfig.self, from: data).apiKey
    }

    func testMigratesLegacyKeyOutOfUserDefaults() throws {
        let (defaults, name) = defaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let box = MemorySecretBox()
        let original = AIConfig(baseURL: "https://example.test/v1", apiKey: "sk-legacy", chatModel: "chat-a", visionModel: "vision-a", temperature: 0.4)
        defaults.set(try JSONEncoder().encode(original), forKey: AIKeyVault.defaultsKey)

        let loaded = AIKeyVault.load(defaults: defaults, box: box, account: "apiKey")

        XCTAssertEqual(loaded.apiKey, "sk-legacy")
        XCTAssertEqual(loaded.baseURL, "https://example.test/v1")
        XCTAssertEqual(loaded.chatModel, "chat-a")
        XCTAssertEqual(try storedKey(defaults), "")
        XCTAssertEqual(box.read(account: "apiKey"), "sk-legacy")
    }

    func testKeychainValueWinsAndClearsLeftoverDefault() throws {
        let (defaults, name) = defaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let box = MemorySecretBox()
        box.values["apiKey"] = "sk-from-keychain"
        let leftover = AIConfig(apiKey: "sk-still-in-defaults")
        defaults.set(try JSONEncoder().encode(leftover), forKey: AIKeyVault.defaultsKey)

        let loaded = AIKeyVault.load(defaults: defaults, box: box, account: "apiKey")

        XCTAssertEqual(loaded.apiKey, "sk-from-keychain")
        XCTAssertEqual(try storedKey(defaults), "")
        XCTAssertEqual(box.read(account: "apiKey"), "sk-from-keychain")
    }

    func testFailedKeychainWriteKeepsLegacyKey() throws {
        let (defaults, name) = defaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let box = MemorySecretBox()
        box.acceptWrites = false
        defaults.set(try JSONEncoder().encode(AIConfig(apiKey: "sk-keep")), forKey: AIKeyVault.defaultsKey)

        let loaded = AIKeyVault.load(defaults: defaults, box: box, account: "apiKey")

        XCTAssertEqual(loaded.apiKey, "sk-keep")
        XCTAssertEqual(try storedKey(defaults), "sk-keep")
        XCTAssertNil(box.read(account: "apiKey"))
    }

    func testSaveStoresKeyInBoxNotDefaults() throws {
        let (defaults, name) = defaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let box = MemorySecretBox()
        var config = AIConfig(baseURL: "https://example.test/v1", apiKey: "sk-new", chatModel: "m", visionModel: "v")

        AIKeyVault.save(config, defaults: defaults, box: box, account: "apiKey")

        XCTAssertEqual(box.read(account: "apiKey"), "sk-new")
        XCTAssertEqual(try storedKey(defaults), "")
        let stored = try JSONDecoder().decode(AIConfig.self, from: try XCTUnwrap(defaults.data(forKey: AIKeyVault.defaultsKey)))
        XCTAssertEqual(stored.baseURL, "https://example.test/v1")

        config.apiKey = ""
        AIKeyVault.save(config, defaults: defaults, box: box, account: "apiKey")
        XCTAssertNil(box.read(account: "apiKey"))
    }
}
