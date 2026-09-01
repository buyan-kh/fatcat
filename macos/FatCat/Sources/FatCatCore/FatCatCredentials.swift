import Foundation
import Security

public enum FatCatCredentialError: Error, Equatable, Sendable {
    case invalidProvider
    case keychain(OSStatus)
}

public struct FatCatCredentials: Sendable {
    public let service: String

    public init(service: String = "com.buyan.fatcat") {
        self.service = service
    }

    public func reference(providerID: String) -> String {
        "fatcat-key:\(providerID)"
    }

    public func save(providerID: String, secret: String) throws {
        guard isValidProviderID(providerID) else { throw FatCatCredentialError.invalidProvider }
        let query = baseQuery(providerID: providerID)
        let data = Data(secret.utf8)
        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw FatCatCredentialError.keychain(addStatus) }
        } else if updateStatus != errSecSuccess {
            throw FatCatCredentialError.keychain(updateStatus)
        }
    }

    public func read(providerID: String) throws -> String? {
        guard isValidProviderID(providerID) else { throw FatCatCredentialError.invalidProvider }
        var query = baseQuery(providerID: providerID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw FatCatCredentialError.keychain(status) }
        guard let data = result as? Data else { throw FatCatCredentialError.keychain(errSecDecode) }
        return String(data: data, encoding: .utf8)
    }

    public func delete(providerID: String) throws {
        guard isValidProviderID(providerID) else { throw FatCatCredentialError.invalidProvider }
        let status = SecItemDelete(baseQuery(providerID: providerID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw FatCatCredentialError.keychain(status) }
    }

    private func baseQuery(providerID: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerID
        ]
    }

    private func isValidProviderID(_ providerID: String) -> Bool {
        let value = providerID.trimmingCharacters(in: .whitespacesAndNewlines)
        return !value.isEmpty && value.count <= 128 && !value.contains("/")
    }
}
