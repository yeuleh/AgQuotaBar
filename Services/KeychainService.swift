import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()
    
    private let service = "com.agquotabar.oauth"
    private let tokenAccount = "google-oauth-token"
    
    private init() {}
    
    func saveToken(_ token: TokenData) throws {
        let data = try JSONEncoder().encode(token)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]
        
        SecItemDelete(query as CFDictionary)
        
        var newItem = query
        newItem[kSecValueData as String] = data
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        
        let status = SecItemAdd(newItem as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    func getToken() -> TokenData? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        
        return try? JSONDecoder().decode(TokenData.self, from: data)
    }
    
    func hasToken() -> Bool {
        getToken() != nil
    }
    
    func isTokenExpired() -> Bool {
        guard let token = getToken() else {
            return true
        }
        return token.isExpired
    }
    
    func getAccessToken() -> String? {
        getToken()?.accessToken
    }
    
    func getRefreshToken() -> String? {
        getToken()?.refreshToken
    }
    
    func updateAccessToken(_ newAccessToken: String, expiresIn: Int) throws {
        guard let token = getToken() else {
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
        
        try saveToken(updatedToken)
    }
    
    func updateTokenSource(_ source: TokenSource) throws {
        guard let token = getToken() else {
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
        
        try saveToken(updatedToken)
    }
    
    func getTokenSource() -> TokenSource {
        getToken()?.source ?? .manual
    }
    
    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]
        
        SecItemDelete(query as CFDictionary)
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
