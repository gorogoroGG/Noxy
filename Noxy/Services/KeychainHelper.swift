import Foundation
import Security

// MARK: - KeychainHelper (#3: トークンを UserDefaults ではなく Keychain に保存)

enum KeychainHelper {
    private static let service = Bundle.main.bundleIdentifier ?? "com.Noxy"

    // MARK: - Save

    @discardableResult
    nonisolated static func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        // 既存エントリを更新 or 新規追加
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            return addStatus == errSecSuccess
        }
        return updateStatus == errSecSuccess
    }

    // MARK: - Load

    nonisolated static func load(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete

    @discardableResult
    nonisolated static func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Migrate from UserDefaults

    /// アプリ起動時に一度呼ぶ。UserDefaults にトークンが残っていれば Keychain に移行してから削除する
    nonisolated static func migrateFromUserDefaults() {
        let keys = [
            "supabase_access_token",
            "supabase_refresh_token",
            "discord_access_token",
            "discord_user_id",
            "discord_username",
            "discord_avatar",
        ]
        for key in keys {
            if let value = UserDefaults.standard.string(forKey: key), !value.isEmpty {
                save(value, forKey: key)
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}
