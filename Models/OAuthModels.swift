import Foundation

// MARK: - OAuth Constants

enum OAuthConstants {
    static let clientId = "1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com"
    static let clientSecret = "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"
    static let authEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    static let tokenEndpoint = "https://oauth2.googleapis.com/token"
    static let userInfoEndpoint = "https://www.googleapis.com/oauth2/v2/userinfo"
    
    static let scopes = [
        "https://www.googleapis.com/auth/cloud-platform",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile",
        "https://www.googleapis.com/auth/cclog",
        "https://www.googleapis.com/auth/experimentsandconfigs"
    ].joined(separator: " ")
    
    static let callbackHost = "127.0.0.1"
    static let callbackPath = "/callback"
    
    static let authTimeoutSeconds: TimeInterval = 180
    static let apiTimeoutSeconds: TimeInterval = 10
    static let tokenRefreshBufferSeconds: TimeInterval = 300 // 5 minutes before expiry
}

// MARK: - Google Cloud Code API Constants

enum CloudCodeAPIConstants {
    static let baseURL = "https://cloudcode-pa.googleapis.com"
    static let loadCodeAssistPath = "/v1internal:loadCodeAssist"
    static let fetchAvailableModelsPath = "/v1internal:fetchAvailableModels"
}

// MARK: - Authentication State

enum AuthState: Equatable {
    case notAuthenticated
    case authenticating
    case authenticated
    case tokenExpired
    case refreshing
    case error(String)
    
    var isLoggedIn: Bool {
        switch self {
        case .authenticated, .refreshing:
            return true
        default:
            return false
        }
    }
    
    var displayText: String {
        switch self {
        case .notAuthenticated:
            return "未登录"
        case .authenticating:
            return "登录中..."
        case .authenticated:
            return "已登录"
        case .tokenExpired:
            return "登录已过期"
        case .refreshing:
            return "刷新中..."
        case .error(let message):
            return "错误: \(message)"
        }
    }
    
    @MainActor
    var localizedDisplayText: String {
        switch self {
        case .notAuthenticated:
            return L10n.Auth.notAuthenticated
        case .authenticating:
            return L10n.Auth.authenticating
        case .authenticated:
            return L10n.Auth.authenticated
        case .tokenExpired:
            return L10n.Auth.tokenExpired
        case .refreshing:
            return L10n.Auth.refreshing
        case .error(let message):
            return L10n.Auth.error(message)
        }
    }
}

// MARK: - Token Data

struct TokenData: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let tokenType: String
    let scope: String
    let source: TokenSource
    
    var isExpired: Bool {
        Date().addingTimeInterval(OAuthConstants.tokenRefreshBufferSeconds) >= expiresAt
    }
    
    var timeUntilExpiry: TimeInterval {
        expiresAt.timeIntervalSinceNow
    }
}

enum TokenSource: String, Codable {
    case manual = "manual"       // Browser login
    case imported = "imported"   // Imported from Antigravity
}

// MARK: - OAuth Token Response

struct OAuthTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    let scope: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
    }
}

// MARK: - OAuth Error Response

struct OAuthErrorResponse: Decodable {
    let error: String
    let errorDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

// MARK: - User Info Response

struct UserInfoResponse: Decodable {
    let id: String
    let email: String
    let verifiedEmail: Bool
    let name: String?
    let picture: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case verifiedEmail = "verified_email"
        case name
        case picture
    }
}

// MARK: - Cloud Code API Responses

struct LoadCodeAssistResponse: Decodable {
    let cloudaicompanionProject: String?
    let currentTier: TierInfo?
    let paidTier: TierInfo?
    
    var projectId: String {
        cloudaicompanionProject ?? ""
    }
    
    var tier: String {
        paidTier?.id ?? currentTier?.id ?? "FREE"
    }
}

struct TierInfo: Decodable {
    let id: String?
    let name: String?
}

struct FetchAvailableModelsResponse: Decodable {
    let models: [String: ModelInfo]?
    
    struct ModelInfo: Decodable {
        let quotaInfo: QuotaInfo?
    }
    
    struct QuotaInfo: Decodable {
        let remainingFraction: Double?
        let resetTime: String?
    }
}

// MARK: - Remote Quota Model

struct RemoteModelQuota: Identifiable, Hashable {
    let id: String
    let modelName: String
    let displayName: String
    let remainingPercentage: Int
    let resetTime: Date?
    let isExhausted: Bool

    var usedPercentage: Int {
        min(100, max(0, 100 - remainingPercentage))
    }
    
    init(modelName: String, displayName: String, remainingFraction: Double, resetTimeString: String?) {
        self.id = modelName
        self.modelName = modelName
        self.displayName = displayName
        self.remainingPercentage = Int((remainingFraction * 100).rounded())
        self.isExhausted = remainingFraction <= 0
        
        if let resetTimeString {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            self.resetTime = formatter.date(from: resetTimeString)
                ?? ISO8601DateFormatter().date(from: resetTimeString)
        } else {
            self.resetTime = nil
        }
    }
}

// MARK: - Remote Quota Snapshot

struct RemoteQuotaSnapshot: Equatable {
    let timestamp: Date
    let models: [RemoteModelQuota]
    let userEmail: String?
    let tier: String?
    let projectId: String?
    
    static func == (lhs: RemoteQuotaSnapshot, rhs: RemoteQuotaSnapshot) -> Bool {
        lhs.timestamp == rhs.timestamp &&
        lhs.userEmail == rhs.userEmail &&
        lhs.tier == rhs.tier &&
        lhs.projectId == rhs.projectId &&
        lhs.models.map(\.id) == rhs.models.map(\.id) &&
        lhs.models.map(\.remainingPercentage) == rhs.models.map(\.remainingPercentage)
    }
}

// MARK: - Quota Mode

enum QuotaMode: String, CaseIterable, Identifiable {
    case local = "local"
    case remote = "remote"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .local:
            return "本地模式"
        case .remote:
            return "远程模式 (Google API)"
        }
    }
    
    var description: String {
        switch self {
        case .local:
            return "通过本地 Antigravity 语言服务器获取配额"
        case .remote:
            return "直接调用 Google API 获取配额，需要登录 Google 账号"
        }
    }
    
    @MainActor
    var localizedDisplayName: String {
        switch self {
        case .local:
            return L10n.Antigravity.localMode
        case .remote:
            return L10n.Antigravity.remoteMode
        }
    }
    
    @MainActor
    var localizedDescription: String {
        switch self {
        case .local:
            return L10n.Antigravity.localModeDesc
        case .remote:
            return L10n.Antigravity.remoteModeDesc
        }
    }
}

// MARK: - OAuth Errors

enum OAuthError: LocalizedError {
    case callbackServerFailed(String)
    case authorizationTimeout
    case invalidState
    case authorizationDenied(String)
    case tokenExchangeFailed(String)
    case tokenRefreshFailed(String)
    case noRefreshToken
    case notAuthenticated
    case networkError(String)
    case apiError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .callbackServerFailed(let reason):
            return "回调服务器启动失败: \(reason)"
        case .authorizationTimeout:
            return "授权超时，请重试"
        case .invalidState:
            return "无效的授权状态 (CSRF 保护)"
        case .authorizationDenied(let reason):
            return "授权被拒绝: \(reason)"
        case .tokenExchangeFailed(let reason):
            return "Token 交换失败: \(reason)"
        case .tokenRefreshFailed(let reason):
            return "Token 刷新失败: \(reason)"
        case .noRefreshToken:
            return "无可用的刷新令牌"
        case .notAuthenticated:
            return "未登录"
        case .networkError(let reason):
            return "网络错误: \(reason)"
        case .apiError(let status, let message):
            return "API 错误 (\(status)): \(message)"
        }
    }
    
    var needsReauth: Bool {
        switch self {
        case .tokenRefreshFailed, .noRefreshToken, .notAuthenticated:
            return true
        case .apiError(let status, _):
            return status == 401
        default:
            return false
        }
    }
}
