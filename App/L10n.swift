import Foundation

@MainActor
enum L10n {
    
    enum Settings {
        static var general: String { "settings.general".localized }
        static var antigravity: String { "settings.antigravity".localized }
        static var about: String { "settings.about".localized }
    }
    
    enum General {
        static var display: String { "general.display".localized }
        static var launchAtLogin: String { "general.launchAtLogin".localized }
        static var showPercentage: String { "general.showPercentage".localized }
        static var monochromeIcon: String { "general.monochromeIcon".localized }
        static var localization: String { "general.localization".localized }
        static var language: String { "general.language".localized }
        static var languageRestartHint: String { "general.languageRestartHint".localized }
    }
    
    enum About {
        static func version(_ version: String) -> String {
            "about.version".localized(version)
        }
        static var description: String { "about.description".localized }
        static var madeWith: String { "about.madeWith".localized }
        static var forDevelopers: String { "about.forDevelopers".localized }
    }
    
    enum Menu {
        static var models: String { "menu.models".localized }
        static var updateInterval: String { "menu.updateInterval".localized }
        static var interval30s: String { "menu.interval30s".localized }
        static var interval2m: String { "menu.interval2m".localized }
        static var interval1h: String { "menu.interval1h".localized }
        static var refreshNow: String { "menu.refreshNow".localized }
        static var settings: String { "menu.settings".localized }
        static var quit: String { "menu.quit".localized }
        static var noModels: String { "menu.noModels".localized }
        static var notLoggedIn: String { "menu.notLoggedIn".localized }
        static var loginWithGoogle: String { "menu.loginWithGoogle".localized }
        static var noModelsConfigured: String { "menu.noModelsConfigured".localized }
    }
    
    enum Antigravity {
        static var mode: String { "antigravity.mode".localized }
        static var quotaFetchMethod: String { "antigravity.quotaFetchMethod".localized }
        static var localMode: String { "antigravity.localMode".localized }
        static var remoteMode: String { "antigravity.remoteMode".localized }
        static var localModeDesc: String { "antigravity.localModeDesc".localized }
        static var remoteModeDesc: String { "antigravity.remoteModeDesc".localized }
        static var loggedIn: String { "antigravity.loggedIn".localized }
        static var logout: String { "antigravity.logout".localized }
        static var loginPrompt: String { "antigravity.loginPrompt".localized }
        static var remoteModeHint: String { "antigravity.remoteModeHint".localized }
        static var loggingIn: String { "antigravity.loggingIn".localized }
        static var loginWithGoogle: String { "antigravity.loginWithGoogle".localized }
        static var googleAccount: String { "antigravity.googleAccount".localized }
        static var addAccount: String { "antigravity.addAccount".localized }
        static var email: String { "antigravity.email".localized }
        static var noModels: String { "antigravity.noModels".localized }
        static var modelVisibilityHint: String { "antigravity.modelVisibilityHint".localized }
        static var maxModelsReached: String { "antigravity.maxModelsReached".localized }
        static var modelQuotaDisplay: String { "antigravity.modelQuotaDisplay".localized }
        static var noAccounts: String { "antigravity.noAccounts".localized }
        static var modelVisibility: String { "antigravity.modelVisibility".localized }
        static var setAsDefault: String { "antigravity.setAsDefault".localized }
        static var defaultAccount: String { "antigravity.defaultAccount".localized }
        static var deleteAccount: String { "antigravity.deleteAccount".localized }
        static func accountTier(_ tier: String) -> String {
            "antigravity.accountTier".localized(tier)
        }
    }
    
    enum Auth {
        static var notAuthenticated: String { "auth.notAuthenticated".localized }
        static var authenticating: String { "auth.authenticating".localized }
        static var authenticated: String { "auth.authenticated".localized }
        static var tokenExpired: String { "auth.tokenExpired".localized }
        static var refreshing: String { "auth.refreshing".localized }
        static func error(_ message: String) -> String {
            "auth.error".localized(message)
        }
    }
    
    enum OAuth {
        static func callbackServerFailed(_ reason: String) -> String {
            "oauth.callbackServerFailed".localized(reason)
        }
        static var authorizationTimeout: String { "oauth.authorizationTimeout".localized }
        static var invalidState: String { "oauth.invalidState".localized }
        static func authorizationDenied(_ reason: String) -> String {
            "oauth.authorizationDenied".localized(reason)
        }
        static func tokenExchangeFailed(_ reason: String) -> String {
            "oauth.tokenExchangeFailed".localized(reason)
        }
        static func tokenRefreshFailed(_ reason: String) -> String {
            "oauth.tokenRefreshFailed".localized(reason)
        }
        static var noRefreshToken: String { "oauth.noRefreshToken".localized }
        static var notAuthenticated: String { "oauth.notAuthenticated".localized }
        static func networkError(_ reason: String) -> String {
            "oauth.networkError".localized(reason)
        }
        static func apiError(_ status: Int, _ message: String) -> String {
            String(format: LocalizationManager.shared.localized("oauth.apiError"), status, message)
        }
    }
}
