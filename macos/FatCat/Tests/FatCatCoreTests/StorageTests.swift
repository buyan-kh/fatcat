import Foundation
import Testing
@testable import FatCatCore

struct StorageTests {
    @Test func auditStorePersistsNativeEventsOnly() throws {
        let store = try FatCatAuditStore.inMemory()
        try store.recordObservation(activeApp: "Xcode", window: "ContentView.swift", redacted: false)
        try store.recordAction(id: "action-1", action: "open_file", risk: "low", status: "approved")
        try store.recordVerification(actionID: "action-1", success: true, detail: "file opened")

        #expect(try store.count(table: "observations") == 1)
        #expect(try store.count(table: "actions") == 1)
        #expect(try store.count(table: "verification_results") == 1)
        #expect(throws: StorageError.invalidTable) {
            try store.count(table: "goals")
        }
    }

    @Test func keychainStoreNeverReturnsAnEmptyDatabaseKey() throws {
        let store = InMemorySecretStore()
        let key = try store.loadOrCreateDatabaseKey()
        #expect(!key.isEmpty)
        #expect(try store.loadOrCreateDatabaseKey() == key)
    }
}
