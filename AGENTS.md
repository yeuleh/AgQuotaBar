# PROJECT KNOWLEDGE BASE

**Generated:** 2026-02-13 22:13 CST
**Commit:** 155e2db
**Branch:** main

## OVERVIEW
macOS menubar app for monitoring Google Antigravity quota. Swift 5.9+ / SwiftUI / limited AppKit. Supports local (language_server) and remote (OAuth) quota modes.

## STRUCTURE
```
AgQuotaBar/
├── App/                    # Entry point, AppState, localization
├── UI/
│   ├── MenuBar/            # MenuBarIcon (ring renderer), MenuDropdown
│   └── Settings/           # TabView: General, Antigravity, About
├── Services/               # Local/Remote quota, OAuth flow, Keychain
├── Models/                 # QuotaModel, Account, QuotaSnapshot, OAuth models
├── Resources/              # Localizable.strings (.lproj)
└── AgQuotaBar/             # Xcode template remnants (ContentView unused)
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| App lifecycle, preferences | `App/AppState.swift` | @MainActor, polling, UserDefaults |
| Menubar icon rendering | `UI/MenuBar/MenuBarIcon.swift` | NSImage + ring drawing |
| Local quota fetching | `Services/LocalQuotaService.swift` | Detects ports via ps/lsof |
| Remote quota fetching | `Services/RemoteQuotaService.swift` | OAuth-backed API calls |
| OAuth flow | `Services/OAuthService.swift` | PKCE auth, token refresh |
| OAuth callback server | `Services/OAuthCallbackServer.swift` | Local HTTP listener |
| Keychain storage | `Services/KeychainService.swift` | Token persistence |
| Localization | `App/LocalizationManager.swift` | Runtime language switching |
| Localized strings | `App/L10n.swift` | Type-safe string keys |
| Data models | `Models/Placeholders.swift` | QuotaModel, Account, QuotaSnapshot |
| OAuth models | `Models/OAuthModels.swift` | Tokens, auth state, OAuth constants |
| Settings tabs | `UI/Settings/SettingsView.swift` | Routes to General/Antigravity/About |

## CODE MAP
| Symbol | Type | Location | Role |
|--------|------|----------|------|
| `AgQuotaBarApp` | struct | App/AgQuotaBarApp.swift | @main entry, MenuBarExtra scene |
| `AppState` | class | App/AppState.swift | @MainActor, accounts/polling/prefs |
| `PreferenceKey` | enum | App/AppState.swift | UserDefaults keys |
| `StoredAccount` | struct | App/AppState.swift | Persisted account data |
| `LocalQuotaService` | struct | Services/LocalQuotaService.swift | language_server quota fetch |
| `RemoteQuotaService` | class | Services/RemoteQuotaService.swift | Cloud Code API fetch |
| `OAuthService` | class | Services/OAuthService.swift | PKCE flow + token refresh |
| `OAuthCallbackServer` | class | Services/OAuthCallbackServer.swift | Local auth callback listener |
| `KeychainService` | class | Services/KeychainService.swift | Token storage |
| `LocalizationManager` | class | App/LocalizationManager.swift | Runtime l10n |
| `MenuBarIcon` | struct | UI/MenuBar/MenuBarIcon.swift | Renders percentage ring |
| `MenuDropdown` | struct | UI/MenuBar/MenuDropdown.swift | Model selector + settings |
| `QuotaModel` | struct | Models/Placeholders.swift | id, name, remainingPercentage |
| `Account` | struct | Models/Placeholders.swift | id, email, models |
| `QuotaSnapshot` | struct | Models/Placeholders.swift | Timestamped quota state |
| `LocalQuotaError` | enum | Services/LocalQuotaService.swift | Error types |
| `KeychainError` | enum | Services/KeychainService.swift | Keychain errors |

## CONVENTIONS
- **SwiftUI first**; AppKit only for NSStatusItem/NSImage rendering
- **@MainActor** on AppState; background Tasks for networking
- **UserDefaults** via `PreferenceKey` enum in AppState
- **No force unwraps** (`!`) unless proven safe
- **Immutable structs** for models; class only for AppState
- File names match primary type

## ANTI-PATTERNS (THIS PROJECT)
- **No `fatalError`** in runtime paths
- **No `as any`** equivalents - avoid type erasure
- **ContentView.swift is dead code** - unused SwiftUI template remnant

## UNIQUE STYLES
- Custom localization: `LocalizationManager` + `L10n` enum + `.lproj` bundles
- Duplicate `log(_:)` helpers in AppState and LocalQuotaService
- Quota color thresholds duplicated in MenuBarIcon and MenuDropdown

## COMMANDS
```bash
# Build
xcodebuild -project AgQuotaBar.xcodeproj -scheme AgQuotaBar -configuration Debug build

# Run
open AgQuotaBar.xcodeproj  # Then Cmd+R

# Debug log
tail -f /tmp/agquotabar_debug.log
```

## NOTES
- Polling logic in AppState.startPolling() - not in service layer
- Port detection uses ps + lsof to find language_server ports
- CSRF token required for API calls (extracted from process args)
- Model visibility persisted in hiddenModelIdsByAccount
- First launch auto-opens Settings to Antigravity tab
- No tests, no CI/CD - manual Xcode build/archive
- MenuBarExtra requires macOS 13+; SettingsLink requires macOS 14+
- Icon uses isTemplate for monochrome mode compatibility
- Cap visible models to 7 items in dropdown
