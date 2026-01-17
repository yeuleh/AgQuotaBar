# PROJECT KNOWLEDGE BASE

**Generated:** 2026-01-17 11:36 Asia/Shanghai
**Commit:** 40d900c
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
├── AgQuotaBar/             # Xcode template remnants (ContentView unused)
└── docs/                   # Design docs
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| App lifecycle, preferences | `App/AppState.swift` | Central state, polling, UserDefaults |
| Menubar icon rendering | `UI/MenuBar/MenuBarIcon.swift` | NSImage + ring drawing |
| Local quota fetching | `Services/LocalQuotaService.swift` | Detects ports via ps/lsof, calls language_server |
| Remote quota fetching | `Services/RemoteQuotaService.swift` | OAuth-backed API calls |
| OAuth flow | `Services/OAuthService.swift` | Auth state, token refresh, user email |
| OAuth callback server | `Services/OAuthCallbackServer.swift` | Local HTTP listener for auth callback |
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
| `AppState` | class | App/AppState.swift | @MainActor, owns accounts/polling/prefs |
| `LocalQuotaService` | struct | Services/LocalQuotaService.swift | Fetches quota from local language_server |
| `RemoteQuotaService` | class | Services/RemoteQuotaService.swift | Fetches quota via OAuth API |
| `OAuthService` | class | Services/OAuthService.swift | OAuth flow + token refresh |
| `OAuthCallbackServer` | class | Services/OAuthCallbackServer.swift | Local auth callback listener |
| `KeychainService` | class | Services/KeychainService.swift | Token storage helpers |
| `LocalizationManager` | class | App/LocalizationManager.swift | Runtime localization manager |
| `MenuBarIcon` | struct | UI/MenuBar/MenuBarIcon.swift | Renders percentage ring icon |
| `MenuDropdown` | struct | UI/MenuBar/MenuDropdown.swift | Model selector + refresh + settings |
| `QuotaModel` | struct | Models/Placeholders.swift | id, name, remainingPercentage, resetTime |

## CONVENTIONS
- **SwiftUI first**; AppKit only for NSStatusItem/NSImage rendering
- **@MainActor** on AppState; background Tasks for networking
- **UserDefaults** via `PreferenceKey` enum in AppState (no separate Storage/ yet)
- **No force unwraps** (`!`) unless proven safe
- **Immutable structs** for models; class only for AppState
- File names match primary type

## ANTI-PATTERNS (THIS PROJECT)
- **No `fatalError`** in runtime paths
- **No `as any`/`@ts-ignore`** equivalents - avoid type erasure
- **No Keychain yet** - guidelines specify it for OAuth tokens (future work)
- **ContentView.swift is dead code** - unused SwiftUI template remnant

## UNIQUE STYLES
- Custom localization system: `LocalizationManager` + `L10n` enum + `.lproj` bundles
- Duplicate logging helpers in `App/AppState.swift` and `Services/LocalQuotaService.swift`
- Quota color thresholds duplicated in `UI/MenuBar/MenuBarIcon.swift` and `UI/MenuBar/MenuDropdown.swift`

## COMMANDS
```bash
# Build (Xcode)
xcodebuild -project AgQuotaBar.xcodeproj -scheme AgQuotaBar -configuration Debug build

# Run (Xcode)
open AgQuotaBar.xcodeproj  # Then Cmd+R

# Debug log location
tail -f /tmp/agquotabar_debug.log
```

## NOTES
- Swift version mismatch: Xcode project has SWIFT_VERSION=5.0, guidelines say 5.9+
- Polling logic embedded in AppState.startPolling() - not in service layer
- Port detection uses ps + lsof to find language_server process ports
- CSRF token required for API calls (extracted from process args)
- Model visibility persisted per-account in hiddenModelIdsByAccount
- First launch auto-opens Settings to Antigravity tab
- No tests, no CI/CD - manual Xcode build/archive
- No .swiftlint.yml/.swiftformat - conventions are manual
- MenuBarExtra requires macOS 13+; SettingsLink requires macOS 14+
- Icon uses isTemplate for monochrome mode compatibility
- Cap visible models to 7 items in dropdown
