# PROJECT GUIDELINES (AgQuotaBar)

## OVERVIEW
- Native macOS menubar app (Swift + SwiftUI + limited AppKit).
- Focus on menu bar UX, settings window, quota polling, and secure token storage.

## STACK
- Swift 5.9+
- SwiftUI (primary UI)
- AppKit (NSStatusItem/NSImage for menubar rendering if needed)
- Keychain for secrets, UserDefaults for preferences

## STRUCTURE (EXPECTED)
- `App/` App entry, AppState, lifecycle
- `UI/` SwiftUI views (MenuBar, Settings, About)
- `Services/` Quota providers, polling, OAuth
- `Models/` Data models and DTOs
- `Storage/` Keychain + UserDefaults wrappers

## CODING CONVENTIONS
- Prefer SwiftUI first; use AppKit only when SwiftUI is insufficient.
- No force unwraps (`!`) unless proven safe and localized; avoid globally.
- Avoid `fatalError` in runtime paths.
- Use `@MainActor` for UI state, background tasks for networking.
- Keep providers pure: no UI logic inside service layer.
- Prefer immutable structs for models; avoid reference types unless needed.

## NAMING
- Types: `PascalCase`, methods/vars: `camelCase`.
- Protocols: `*Providing` or `*Provider`.
- Files match primary type name.

## ERROR HANDLING
- Always surface actionable errors to UI via state (e.g., `isStale`, `authState`).
- Use typed errors (enum) for provider failures.
- Retry only on 5xx/429 or transient network errors.

## SECURITY
- OAuth tokens MUST be stored in Keychain.
- Never log access/refresh tokens.
- Avoid committing secrets or OAuth client secrets to repo.

## UI BEHAVIOR
- Menubar icon must be crisp at macOS 13+ sizes.
- Keep menus short; cap model list to 7 items.
- Settings window is independent; no main window.

## TESTING
- Add tests only if a test framework is already present.
- Prefer unit tests for parsing and model filtering logic.

## COMMON COMMANDS
- (TBD) Add build/run commands when Xcode project exists.
