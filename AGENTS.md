# PROJECT KNOWLEDGE BASE

**Generated:** 2026-02-14 20:59 CST
**Commit:** fa71e24
**Branch:** main

## OVERVIEW
macOS menubar app for monitoring Google Antigravity quota. Swift 5.9+ / SwiftUI / limited AppKit. Multi-service tabs (Codex, Antigravity, GLM) with local (language_server) and remote (OAuth) quota modes. Color-coded usage indicators.

## STRUCTURE
```
AgQuotaBar/
├── App/                    # Entry point, AppState (845L), localization
├── UI/
│   ├── MenuBar/            # MenuBarIcon (GravityArc ring), MenuDropdown (tabbed panel)
│   └── Settings/           # TabView: General, Antigravity, About
├── Services/               # Local/Remote quota, OAuth flow, Keychain
├── Models/
│   ├── Placeholders.swift  # Domain models + ServicePanelSnapshot
│   └── OAuthModels.swift   # Tokens, auth state, API response types
├── Resources/              # Localizable.strings (en, zh-Hans, ja)
└── AgQuotaBar/             # Xcode template remnants (ContentView unused)
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| App lifecycle, preferences, polling | `App/AppState.swift` | @MainActor, 845 lines, central hub |
| Multi-service snapshot building | `App/AppState.swift` → `antigravitySnapshot`, `codexSnapshot`, `glmSnapshot` | Computed properties returning `ServicePanelSnapshot` |
| Menubar icon + color ring | `UI/MenuBar/MenuBarIcon.swift` | GravityArc SwiftUI shape, color-coded by remaining% |
| Tabbed dropdown panel | `UI/MenuBar/MenuDropdown.swift` | serviceTabs, snapshotHeader, UsageProgressBar |
| Local quota fetching | `Services/LocalQuotaService.swift` | ps/lsof port detection, CSRF token |
| Remote quota fetching | `Services/RemoteQuotaService.swift` | Cloud Code API, model name filtering |
| OAuth PKCE flow | `Services/OAuthService.swift` | Token refresh, multi-account keychain |
| OAuth callback server | `Services/OAuthCallbackServer.swift` | Local HTTP listener for redirect |
| Keychain storage | `Services/KeychainService.swift` | Token persistence |
| Localization | `App/LocalizationManager.swift` + `App/L10n.swift` | Runtime switching, type-safe keys |
| Domain models | `Models/Placeholders.swift` | QuotaModel, ServicePanelSnapshot, ServiceUsageGroup |
| OAuth/API models | `Models/OAuthModels.swift` | TokenData, RemoteModelQuota, API responses |
| Settings tabs | `UI/Settings/SettingsView.swift` | Routes to General/Antigravity/About |

## CODE MAP
| Symbol | Type | Location | Role |
|--------|------|----------|------|
| `AgQuotaBarApp` | struct | App/AgQuotaBarApp.swift | @main, MenuBarExtra + Settings scenes |
| `AppState` | class | App/AppState.swift | @MainActor, central state hub |
| `PreferenceKey` | enum | App/AppState.swift | UserDefaults key constants |
| `StoredAccount` | struct | App/AppState.swift | Persisted account (id, email) |
| `IconDisplayOverride` | struct | App/AppState.swift | Override menubar icon from group usage |
| `ServiceTab` | enum | Models/Placeholders.swift | .codex, .antigravity, .glm |
| `ServicePanelState` | enum | Models/Placeholders.swift | .loading, .ready, .needsAuth, .empty, .stale, .failed |
| `ServicePanelSnapshot` | struct | Models/Placeholders.swift | Full panel data: state, windows, groups, notes |
| `ServiceQuotaWindow` | struct | Models/Placeholders.swift | Usage window (title, usedPercent, resetText) |
| `ServiceUsageGroup` | struct | Models/Placeholders.swift | Group with window header + model list |
| `ServiceModelUsage` | struct | Models/Placeholders.swift | Single model usage (name, usedPercent) |
| `QuotaModel` | struct | Models/Placeholders.swift | Legacy: id, name, remainingPercentage |
| `Account` | struct | Models/Placeholders.swift | Legacy: id, email, models |
| `MenuBarIcon` | struct | UI/MenuBar/MenuBarIcon.swift | Color-coded ring icon |
| `GravityArc` | struct | UI/MenuBar/MenuBarIcon.swift | Arc + satellite dot renderer |
| `MenuDropdown` | struct | UI/MenuBar/MenuDropdown.swift | Tabbed popup panel |
| `UsageProgressBar` | struct | UI/MenuBar/MenuDropdown.swift | Gray/colored bar with remaining% |
| `LocalQuotaService` | struct | Services/LocalQuotaService.swift | language_server quota fetch |
| `RemoteQuotaService` | class | Services/RemoteQuotaService.swift | Cloud Code API fetch |
| `OAuthService` | class | Services/OAuthService.swift | PKCE + token refresh |
| `KeychainService` | class | Services/KeychainService.swift | Token storage |
| `LocalizationManager` | class | App/LocalizationManager.swift | Runtime l10n |
| `L10n` | enum | App/L10n.swift | Type-safe localization keys |

## CONVENTIONS
- **SwiftUI first**; AppKit only for NSImage rendering in `AgQuotaBarApp.renderIcon()`
- **@MainActor** on AppState + RemoteQuotaService; background Tasks for networking
- **UserDefaults** via `PreferenceKey` enum in AppState
- **No force unwraps** (`!`) unless proven safe
- **Immutable structs** for models; class only for stateful services (AppState, OAuth, Keychain)
- File names match primary type
- **Color convention**: remaining ≥70% → green, ≥30% → yellow, <30% → red; gray for used portion
- **usedPercent** is the standard metric (not remaining) in ServiceQuotaWindow, ServiceModelUsage, UsageProgressBar

## ANTI-PATTERNS (THIS PROJECT)
- **No `fatalError`** in runtime paths
- **No type erasure** — avoid `as any` / `any Protocol`
- **ContentView.swift is dead code** — unused Xcode template remnant
- **Don't add new log() helpers** — already triplicated (see UNIQUE STYLES)

## UNIQUE STYLES
- Custom localization: `LocalizationManager` + `L10n` enum + `.lproj` bundles (en, zh-Hans, ja)
- Triplicate `log(_:)` helpers in AppState, LocalQuotaService, and RemoteQuotaService (file-private)
- Color thresholds unified: `usageColor(for:)` in MenuDropdown and `ringColor` in MenuBarIcon use same logic
- `ServicePanelSnapshot` is computed per-tab in AppState (`antigravitySnapshot`, `codexSnapshot`, `glmSnapshot`)
- Codex/GLM snapshots use static placeholder factories; Antigravity builds from live data

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
- Polling in AppState.startPolling() — not in service layer
- Port detection: ps + lsof → language_server ports
- CSRF token extracted from process args for local API calls
- Model visibility: `hiddenModelIdsByAccount` (local), `hiddenRemoteModelIds` (remote) in UserDefaults
- First launch auto-opens Settings to Antigravity tab
- No tests, no CI/CD — manual Xcode build/archive
- MenuBarExtra requires macOS 13+; SettingsLink requires macOS 14+
- Menubar icon rendered via ImageRenderer → NSImage (not isTemplate)
- Cap visible models to 7 in dropdown
- `selectedServiceTab` and `displayedGroupId` persisted in UserDefaults
- `iconDisplayOverride` lets a group "pin" its usage to the menubar icon
- Remote service filters models: only gemini ≥2.0, claude, gpt (via regex in RemoteQuotaService)
- OAuthService is singleton (`shared`) with multi-account keychain support
