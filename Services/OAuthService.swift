import AppKit
import Combine
import CryptoKit
import Foundation

@MainActor
final class OAuthService: ObservableObject {
    static let shared = OAuthService()
    
    @Published private(set) var authState: AuthState = .notAuthenticated
    @Published private(set) var userEmail: String?
    
    private let keychain = KeychainService.shared
    private let accountDefaultsKey = "oauth.keychain.account"
    private let defaultAccountId = "default"
    private var callbackServer: OAuthCallbackServer?
    private var activeAccountId: String? {
        didSet {
            if let activeAccountId {
                UserDefaults.standard.set(activeAccountId, forKey: accountDefaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: accountDefaultsKey)
            }
        }
    }
    
    private var keychainAccountId: String {
        activeAccountId ?? defaultAccountId
    }
    
    func setActiveAccount(id: String?) {
        let resolved = id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        activeAccountId = resolved.isEmpty ? nil : resolved
        userEmail = nil
        initializeState()
    }
    
    private init() {
        activeAccountId = UserDefaults.standard.string(forKey: accountDefaultsKey)
        initializeState()
    }
    
    private func initializeState() {
        let resolvedAccount = activeAccountId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if resolvedAccount.isEmpty {
            activeAccountId = nil
        }
        
        let accountId = keychainAccountId
        guard keychain.hasToken(account: accountId) else {
            authState = .notAuthenticated
            userEmail = nil
            return
        }
        
        if userEmail == nil, accountId != defaultAccountId {
            userEmail = accountId
        }
        
        if keychain.isTokenExpired(account: accountId) {
            Task {
                do {
                    try await refreshToken()
                    authState = .authenticated
                } catch {
                    authState = .tokenExpired
                }
            }
        } else {
            authState = .authenticated
        }
    }
    
    var isAuthenticated: Bool {
        authState.isLoggedIn
    }
    
    func login() async -> Bool {
        guard authState != .authenticating else {
            return false
        }
        
        authState = .authenticating
        
        do {
            let state = generateRandomString(length: 32)
            let codeVerifier = generateCodeVerifier()
            let codeChallenge = generateCodeChallenge(from: codeVerifier)
            
            callbackServer = OAuthCallbackServer()
            _ = try await callbackServer!.start()
            let redirectUri = callbackServer!.redirectUri
            
            let authURL = buildAuthURL(redirectUri: redirectUri, state: state, codeChallenge: codeChallenge)
            
            NSWorkspace.shared.open(authURL)
            
            let result = try await callbackServer!.waitForCallback(expectedState: state)
            
            let tokenData = try await exchangeCodeForToken(
                code: result.code,
                redirectUri: redirectUri,
                codeVerifier: codeVerifier
            )
            
            let resolvedAccountId = try? await fetchUserEmail(accessToken: tokenData.accessToken)
            let accountId = resolvedAccountId ?? defaultAccountId
            activeAccountId = accountId
            try keychain.saveToken(tokenData, account: accountId)
            if let email = resolvedAccountId {
                userEmail = email
            }
            
            authState = .authenticated
            return true
            
        } catch {
            log("Login failed: \(error)")
            authState = .error(error.localizedDescription)
            return false
        }
    }
    
    func loginWithRefreshToken(_ refreshToken: String) async -> Bool {
        guard authState != .authenticating && authState != .refreshing else {
            return false
        }
        
        authState = .refreshing
        
        do {
            let tokenResponse = try await performTokenRefresh(refreshToken: refreshToken)
            
            let tokenData = TokenData(
                accessToken: tokenResponse.accessToken,
                refreshToken: refreshToken,
                expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
                tokenType: tokenResponse.tokenType,
                scope: tokenResponse.scope,
                source: .imported
            )
            
            let resolvedAccountId = try? await fetchUserEmail(accessToken: tokenData.accessToken)
            let accountId = resolvedAccountId ?? defaultAccountId
            activeAccountId = accountId
            try keychain.saveToken(tokenData, account: accountId)
            if let email = resolvedAccountId {
                userEmail = email
            }
            
            authState = .authenticated
            return true
            
        } catch {
            log("Login with refresh token failed: \(error)")
            keychain.deleteToken(account: keychainAccountId)
            userEmail = nil
            authState = .notAuthenticated
            return false
        }
    }
    
    func logout() -> Bool {
        let wasAuthenticated = authState.isLoggedIn
        keychain.deleteToken(account: keychainAccountId)
        userEmail = nil
        activeAccountId = nil
        authState = .notAuthenticated
        return wasAuthenticated
    }
    
    func getValidAccessToken() async throws -> String {
        guard let token = keychain.getToken(account: keychainAccountId) else {
            authState = .notAuthenticated
            throw OAuthError.notAuthenticated
        }
        
        if token.isExpired {
            try await refreshToken()
        }
        
        guard let accessToken = keychain.getAccessToken(account: keychainAccountId) else {
            throw OAuthError.notAuthenticated
        }
        
        return accessToken
    }
    
    private func refreshToken() async throws {
        guard let refreshToken = keychain.getRefreshToken(account: keychainAccountId) else {
            authState = .notAuthenticated
            throw OAuthError.noRefreshToken
        }
        
        authState = .refreshing
        
        do {
            let tokenResponse = try await performTokenRefresh(refreshToken: refreshToken)
            try keychain.updateAccessToken(tokenResponse.accessToken, expiresIn: tokenResponse.expiresIn, account: keychainAccountId)
            authState = .authenticated
        } catch {
            if isReauthRequired(error) {
                authState = .tokenExpired
            } else {
                authState = .error(error.localizedDescription)
            }
            throw error
        }
    }
    
    private func buildAuthURL(redirectUri: String, state: String, codeChallenge: String) -> URL {
        var components = URLComponents(string: OAuthConstants.authEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: OAuthConstants.clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: OAuthConstants.scopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components.url!
    }
    
    private func exchangeCodeForToken(code: String, redirectUri: String, codeVerifier: String) async throws -> TokenData {
        let params = [
            "client_id": OAuthConstants.clientId,
            "client_secret": OAuthConstants.clientSecret,
            "code": code,
            "redirect_uri": redirectUri,
            "grant_type": "authorization_code",
            "code_verifier": codeVerifier
        ]
        
        let tokenResponse = try await performTokenRequest(params: params)
        
        guard let refreshToken = tokenResponse.refreshToken else {
            throw OAuthError.tokenExchangeFailed("No refresh token in response")
        }
        
        return TokenData(
            accessToken: tokenResponse.accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
            tokenType: tokenResponse.tokenType,
            scope: tokenResponse.scope,
            source: .manual
        )
    }
    
    private func performTokenRefresh(refreshToken: String) async throws -> OAuthTokenResponse {
        let params = [
            "client_id": OAuthConstants.clientId,
            "client_secret": OAuthConstants.clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        
        return try await performTokenRequest(params: params)
    }
    
    private func performTokenRequest(params: [String: String]) async throws -> OAuthTokenResponse {
        guard let url = URL(string: OAuthConstants.tokenEndpoint) else {
            throw OAuthError.tokenExchangeFailed("Invalid token endpoint")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.tokenExchangeFailed("Invalid response")
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
                throw OAuthError.tokenExchangeFailed("\(errorResponse.error): \(errorResponse.errorDescription ?? "")")
            }
            throw OAuthError.tokenExchangeFailed("HTTP \(httpResponse.statusCode)")
        }
        
        return try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
    }
    
    private func fetchUserEmail(accessToken: String) async throws -> String {
        guard let url = URL(string: OAuthConstants.userInfoEndpoint) else {
            throw OAuthError.networkError("Invalid userinfo endpoint")
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw OAuthError.networkError("Failed to fetch user info")
        }
        
        let userInfo = try JSONDecoder().decode(UserInfoResponse.self, from: data)
        return userInfo.email
    }
    
    private func generateRandomString(length: Int) -> String {
        let bytes = (0..<length).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .prefix(length)
            .description
    }
    
    private func generateCodeVerifier() -> String {
        let bytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private func isReauthRequired(_ error: Error) -> Bool {
        if let oauthError = error as? OAuthError {
            return oauthError.needsReauth
        }
        let message = error.localizedDescription.lowercased()
        return message.contains("invalid_grant") || message.contains("invalid_rapt")
    }
}

private func log(_ message: String) {
    let logFile = "/tmp/agquotabar_debug.log"
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] [OAuthService] \(message)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logFile) {
            if let handle = FileHandle(forWritingAtPath: logFile) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: logFile, contents: data)
        }
    }
}
