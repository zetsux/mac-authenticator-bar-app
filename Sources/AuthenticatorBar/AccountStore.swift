import AuthenticatorCore
import Foundation
import Security

enum KeychainResult {
    case found(Data)
    case missing
    case failed(OSStatus)
}

enum Keychain {
    private static let service = "com.local.authenticatorbar"
    private static let account = "accounts"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func read() -> KeychainResult {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        if status == errSecItemNotFound { return .missing }
        guard status == errSecSuccess, let data = out as? Data else { return .failed(status) }
        return .found(data)
    }

    static func write(_ data: Data) -> OSStatus {
        let status = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = baseQuery
            add[kSecValueData as String] = data
            return SecItemAdd(add as CFDictionary, nil)
        }
        return status
    }
}

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    /// Set when the Keychain could not be read or written. Saving is blocked so a failed read never overwrites stored secrets.
    @Published private(set) var storageError: String?

    init() { load() }

    func load() {
        switch Keychain.read() {
        case .missing:
            accounts = []
            storageError = nil
        case .found(let data):
            if let decoded = try? JSONDecoder().decode([Account].self, from: data) {
                accounts = decoded
                storageError = nil
            } else {
                storageError = "Stored accounts could not be decoded."
            }
        case .failed(let status):
            storageError = "Keychain access failed (\(status)). Click retry and choose Always Allow."
        }
    }

    func add(_ account: Account) throws {
        try account.validate()
        if accounts.contains(where: { $0.secret == account.secret && $0.issuer == account.issuer && $0.name == account.name }) {
            throw AccountError.duplicate
        }
        var next = accounts
        next.append(account)
        try save(next)
    }

    func remove(id: UUID) {
        try? save(accounts.filter { $0.id != id })
    }

    private func save(_ next: [Account]) throws {
        guard storageError == nil else { throw StoreError.blocked(storageError ?? "") }
        let data = try JSONEncoder().encode(next)
        let status = Keychain.write(data)
        guard status == errSecSuccess else { throw StoreError.keychain(status) }
        accounts = next
    }
}

enum StoreError: LocalizedError {
    case blocked(String)
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .blocked(let message): return message
        case .keychain(let status): return "Could not save to the Keychain (\(status))."
        }
    }
}
