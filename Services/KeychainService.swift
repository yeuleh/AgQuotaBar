import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()
    
    private let defaultAccount = "default"
    
    private var service: String {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.ulenium.agquotabar"
        return "\(bundleId).oauth"
    }
    
    private init() {}
    
    func saveToken(_ token: TokenData, account: String? = nil) throws {
        let accountName = resolvedAccount(account)
        let data = try JSONEncoder().encode(token)
        
        let query = baseQuery(service: service, account: accountName)
        SecItemDelete(query as CFDictionary)
        
        var newItem = query
        newItem[kSecValueData as String] = data
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        
        let status = SecItemAdd(newItem as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    func getToken(account: String? = nil) -> TokenData? {
        let accountName = resolvedAccount(account)
        return fetchToken(service: service, account: accountName)
    }
    
    func hasToken(account: String? = nil) -> Bool {
        getToken(account: account) != nil
    }
    
    func isTokenExpired(account: String? = nil) -> Bool {
        guard let token = getToken(account: account) else {
            return true
        }
        return token.isExpired
    }
    
    func getAccessToken(account: String? = nil) -> String? {
        getToken(account: account)?.accessToken
    }
    
    func getRefreshToken(account: String? = nil) -> String? {
        getToken(account: account)?.refreshToken
    }
    
    func updateAccessToken(_ newAccessToken: String, expiresIn: Int, account: String? = nil) throws {
        guard let token = getToken(account: account) else {
            throw KeychainError.tokenNotFound
        }
        
        let updatedToken = TokenData(
            accessToken: newAccessToken,
            refreshToken: token.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn)),
            tokenType: token.tokenType,
            scope: token.scope,
            source: token.source
        )
        
        try saveToken(updatedToken, account: account)
    }
    
    func updateTokenSource(_ source: TokenSource, account: String? = nil) throws {
        guard let token = getToken(account: account) else {
            throw KeychainError.tokenNotFound
        }
        
        let updatedToken = TokenData(
            accessToken: token.accessToken,
            refreshToken: token.refreshToken,
            expiresAt: token.expiresAt,
            tokenType: token.tokenType,
            scope: token.scope,
            source: source
        )
        
        try saveToken(updatedToken, account: account)
    }
    
    func getTokenSource(account: String? = nil) -> TokenSource {
        getToken(account: account)?.source ?? .manual
    }
    
    func deleteToken(account: String? = nil) {
        let accountName = resolvedAccount(account)
        let query = baseQuery(service: service, account: accountName)
        SecItemDelete(query as CFDictionary)
    }
    
    private func resolvedAccount(_ account: String?) -> String {
        let trimmed = account?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? defaultAccount : trimmed
    }
    
    private func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
    
    private func fetchToken(service: String, account: String) -> TokenData? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        
        return try? JSONDecoder().decode(TokenData.self, from: data)
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case tokenNotFound
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain 保存失败: \(status)"
        case .tokenNotFound:
            return "Token 不存在"
        }
    }
}
