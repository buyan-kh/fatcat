import Foundation
import GRDB
import Security

public protocol DatabaseSecretStore: Sendable {
    func loadOrCreateDatabaseKey() throws -> String
}

public final class InMemorySecretStore: DatabaseSecretStore, @unchecked Sendable {
    private var value: String?
    private let lock = NSLock()

    public init() {}

    public func loadOrCreateDatabaseKey() throws -> String {
        lock.lock()
        defer { lock.unlock() }
        if let value { return value }
        let generated = Data(UUID().uuidString.utf8).base64EncodedString()
        value = generated
        return generated
    }
}

public final class KeychainDatabaseKeyStore: DatabaseSecretStore, @unchecked Sendable {
    private let service: String
    private let account: String

    public init(service: String = "com.buyan.peppa-anywhere", account: String = "database-key") {
        self.service = service
        self.account = account
    }

    public func loadOrCreateDatabaseKey() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, let value = String(data: data, encoding: .utf8), !value.isEmpty { return value }
        guard status == errSecItemNotFound else { throw StorageError.keychain(status) }
        let value = Data(UUID().uuidString.utf8).base64EncodedString()
        var item = query
        item[kSecValueData as String] = Data(value.utf8)
        item.removeValue(forKey: kSecReturnData as String)
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else { throw StorageError.keychain(addStatus) }
        return value
    }
}

public enum StorageError: Error, Equatable, Sendable {
    case keychain(OSStatus)
    case encryptionUnavailable
    case invalidTable
}

public final class PeppaAuditStore: @unchecked Sendable {
    private let database: DatabaseQueue
    private static let tableNames = ["observations", "actions", "approvals", "verification_results", "privacy_decisions", "hermes_sessions"]

    public static func inMemory() throws -> Self {
        let store = try Self(database: DatabaseQueue(path: ":memory:"), encryptionKey: nil, requireSQLCipher: false)
        try store.migrate()
        return store
    }

    public convenience init(path: String, keyStore: DatabaseSecretStore = KeychainDatabaseKeyStore(), requireSQLCipher: Bool = false) throws {
        let key = try keyStore.loadOrCreateDatabaseKey()
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            let escaped = key.replacingOccurrences(of: "'", with: "''")
            try db.execute(sql: "PRAGMA key = '\(escaped)'")
            if requireSQLCipher {
                let version = try String.fetchOne(db, sql: "PRAGMA cipher_version") ?? ""
                guard !version.isEmpty else { throw StorageError.encryptionUnavailable }
            }
        }
        try self.init(database: DatabaseQueue(path: path, configuration: configuration), encryptionKey: key, requireSQLCipher: requireSQLCipher)
        try migrate()
    }

    private init(database: DatabaseQueue, encryptionKey: String?, requireSQLCipher: Bool) throws {
        self.database = database
        _ = encryptionKey
        _ = requireSQLCipher
    }

    public func recordObservation(activeApp: String, window: String, redacted: Bool) throws {
        try database.write { db in
            try db.execute(sql: "INSERT INTO observations (active_app, window_title, redacted, created_at) VALUES (?, ?, ?, ?)", arguments: [activeApp, window, redacted, Date().timeIntervalSince1970])
        }
    }

    public func recordAction(id: String, action: String, risk: String, status: String) throws {
        try database.write { db in
            try db.execute(sql: "INSERT INTO actions (id, action, risk, status, created_at) VALUES (?, ?, ?, ?, ?)", arguments: [id, action, risk, status, Date().timeIntervalSince1970])
        }
    }

    public func recordVerification(actionID: String, success: Bool, detail: String) throws {
        try database.write { db in
            try db.execute(sql: "INSERT INTO verification_results (action_id, success, detail, created_at) VALUES (?, ?, ?, ?)", arguments: [actionID, success, detail, Date().timeIntervalSince1970])
        }
    }

    public func count(table: String) throws -> Int {
        guard Self.tableNames.contains(table) else { throw StorageError.invalidTable }
        return try database.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)") ?? 0 }
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1-native-audit") { db in
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS observations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                active_app TEXT NOT NULL,
                window_title TEXT NOT NULL,
                redacted INTEGER NOT NULL,
                created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS actions (
                id TEXT PRIMARY KEY,
                action TEXT NOT NULL,
                risk TEXT NOT NULL,
                status TEXT NOT NULL,
                created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS approvals (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                action_id TEXT NOT NULL,
                decision TEXT NOT NULL,
                created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS verification_results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                action_id TEXT NOT NULL,
                success INTEGER NOT NULL,
                detail TEXT NOT NULL,
                created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS privacy_decisions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                subject TEXT NOT NULL,
                decision TEXT NOT NULL,
                created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS hermes_sessions (
                session_id TEXT PRIMARY KEY,
                provider TEXT,
                external_session_id TEXT,
                working_directory TEXT,
                created_at REAL NOT NULL
            );
            """)
        }
        try migrator.migrate(database)
    }
}
