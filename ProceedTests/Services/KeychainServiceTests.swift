import Testing
import Foundation
@testable import Proceed

/// Tests for KeychainService using real Keychain with a unique test prefix.
/// Each test uses a unique key and cleans up via defer.
@Suite("KeychainService")
struct KeychainServiceTests {

    private let service = KeychainService.shared

    /// Generate a unique test key to avoid collisions
    private func testKey(_ suffix: String = "") -> String {
        "proceed_test_\(UUID().uuidString)\(suffix)"
    }

    @Test("Save and load round-trip")
    func saveAndLoad() throws {
        let key = testKey()
        defer { service.delete(key: key) }

        try service.save(key: key, value: "secret123")
        let loaded = service.load(key: key)
        #expect(loaded == "secret123")
    }

    @Test("Load non-existent key returns nil")
    func loadNonExistent() {
        let loaded = service.load(key: testKey("_nonexistent"))
        #expect(loaded == nil)
    }

    @Test("Delete removes value")
    func deleteRemoves() throws {
        let key = testKey()
        defer { service.delete(key: key) }

        try service.save(key: key, value: "toDelete")
        service.delete(key: key)
        #expect(service.load(key: key) == nil)
    }

    @Test("Save overwrites existing value")
    func saveOverwrites() throws {
        let key = testKey()
        defer { service.delete(key: key) }

        try service.save(key: key, value: "first")
        try service.save(key: key, value: "second")
        #expect(service.load(key: key) == "second")
    }

    @Test("hasValue returns true when value exists")
    func hasValueTrue() throws {
        let key = testKey()
        defer { service.delete(key: key) }

        try service.save(key: key, value: "exists")
        #expect(service.hasValue(for: key) == true)
    }

    @Test("hasValue returns false when no value")
    func hasValueFalse() {
        #expect(service.hasValue(for: testKey("_missing")) == false)
    }

    @Test("Unicode value round-trip")
    func unicodeRoundTrip() throws {
        let key = testKey()
        defer { service.delete(key: key) }

        let unicode = "日本語テスト 🔑 résumé"
        try service.save(key: key, value: unicode)
        #expect(service.load(key: key) == unicode)
    }

    @Test("Delete non-existent key is safe")
    func deleteNonExistentIsSafe() {
        // Should not throw
        service.delete(key: testKey("_ghost"))
    }

    @Test("Empty string value round-trip")
    func emptyStringRoundTrip() throws {
        let key = testKey()
        defer { service.delete(key: key) }

        try service.save(key: key, value: "")
        #expect(service.load(key: key) == "")
    }
}
