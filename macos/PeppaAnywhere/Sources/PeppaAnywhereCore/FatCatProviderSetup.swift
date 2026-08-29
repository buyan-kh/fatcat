import Foundation

public enum FatCatProviderStatus: String, Codable, Equatable, Sendable {
    case connected
    case needsSetup = "needs_setup"
    case error
    case unavailable
}

public struct FatCatProviderConnection: Codable, Equatable, Identifiable, Sendable {
    public let providerID: String
    public var displayName: String
    public var status: FatCatProviderStatus
    public var detail: String
    public var account: String?
    public var credentialReference: String?
    public var baseURL: String?
    public var models: [String]
    public var isDefault: Bool
    public var defaultModel: String?

    public var id: String { providerID }

    public init(
        providerID: String,
        displayName: String,
        status: FatCatProviderStatus = .unavailable,
        detail: String = "",
        account: String? = nil,
        credentialReference: String? = nil,
        baseURL: String? = nil,
        models: [String] = [],
        isDefault: Bool = false,
        defaultModel: String? = nil
    ) {
        self.providerID = providerID
        self.displayName = displayName
        self.status = status
        self.detail = detail
        self.account = account
        self.credentialReference = credentialReference
        self.baseURL = baseURL
        self.models = models
        self.isDefault = isDefault
        self.defaultModel = defaultModel
    }
}

public struct FatCatProviderValidation: Codable, Equatable, Sendable {
    public let providerID: String
    public let model: String
    public let usable: Bool
    public let detail: String

    public init(providerID: String, model: String, usable: Bool, detail: String) {
        self.providerID = providerID
        self.model = model
        self.usable = usable
        self.detail = detail
    }
}

public struct FatCatProviderSetupState: Codable, Equatable, Sendable {
    public var defaultProvider: String?
    public var defaultModel: String?
    public private(set) var connections: [FatCatProviderConnection]

    public init(defaultProvider: String? = nil, defaultModel: String? = nil, connections: [FatCatProviderConnection] = []) {
        self.defaultProvider = defaultProvider
        self.defaultModel = defaultModel
        self.connections = connections
        updateDefaultMarkers()
    }

    public func connection(providerID: String) -> FatCatProviderConnection? {
        connections.first { $0.providerID == providerID }
    }

    public mutating func applyInventory(_ rows: [[String: String]]) {
        let existing = Dictionary(uniqueKeysWithValues: connections.map { ($0.providerID, $0) })
        if let defaultRow = rows.first(where: { $0["is_default"] == "true" }),
           let providerID = nonEmpty(defaultRow["slug"]) {
            defaultProvider = providerID
            defaultModel = nonEmpty(defaultRow["default_model"]) ?? defaultModel
        }
        connections = rows.compactMap { row in
            guard let providerID = nonEmpty(row["slug"]) else { return nil }
            var connection = existing[providerID] ?? FatCatProviderConnection(providerID: providerID, displayName: providerID)
            connection.displayName = nonEmpty(row["name"]) ?? connection.displayName
            connection.status = FatCatProviderStatus(rawValue: row["status"] ?? "") ?? .unavailable
            connection.detail = row["detail"] ?? ""
            connection.account = nonEmpty(row["account"]) ?? connection.account
            connection.credentialReference = nonEmpty(row["credential_ref"]) ?? connection.credentialReference
            connection.baseURL = nonEmpty(row["base_url"]) ?? connection.baseURL
            return connection
        }
        updateDefaultMarkers()
    }

    public mutating func applyModels(providerID: String, models: [String]) {
        guard let index = connections.firstIndex(where: { $0.providerID == providerID }) else { return }
        connections[index].models = uniqueNonEmpty(models)
    }

    public mutating func applyValidation(_ validation: FatCatProviderValidation) {
        guard let index = connections.firstIndex(where: { $0.providerID == validation.providerID }) else { return }
        connections[index].status = validation.usable ? .connected : .error
        connections[index].detail = validation.detail
        updateDefaultMarkers()
    }

    public mutating func applyCredentialReference(providerID: String, reference: String) {
        guard let index = connections.firstIndex(where: { $0.providerID == providerID }) else { return }
        connections[index].credentialReference = reference
    }

    public mutating func applyBaseURL(providerID: String, baseURL: String) {
        guard let index = connections.firstIndex(where: { $0.providerID == providerID }) else { return }
        connections[index].baseURL = baseURL.isEmpty ? nil : baseURL
    }

    public mutating func setDefault(providerID: String, model: String) {
        defaultProvider = providerID
        defaultModel = model
        if let index = connections.firstIndex(where: { $0.providerID == providerID }) {
            connections[index].defaultModel = model
        }
        updateDefaultMarkers()
    }

    private mutating func updateDefaultMarkers() {
        for index in connections.indices {
            connections[index].isDefault = connections[index].providerID == defaultProvider
            if connections[index].isDefault, let defaultModel {
                connections[index].defaultModel = defaultModel
            }
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }

    private func uniqueNonEmpty(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty, seen.insert(cleaned).inserted else { return nil }
            return cleaned
        }
    }
}
