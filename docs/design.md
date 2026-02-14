# Multi-Service Popup Design Spec

Last updated: 2026-02-14
Status: Draft for implementation
Owner: AgQuotaBar

## 1. Goal

Build a custom menu popup UI with fixed service tabs:

- Codex
- Antigravity
- GLM

The popup should support quick tab switching and show quota and usage for each service in a consistent visual language.

## 2. Scope

### In scope (v1)

- Fixed service tabs in menu popup.
- Service-specific quota sections.
- Unified loading, auth, empty, stale, and error states.
- Refresh action and settings/quit actions.
- Antigravity supports both local and remote source modes.
- Antigravity usage shown by model groups.

### Out of scope (v1)

- New billing APIs.
- Historical charts beyond current quota windows.
- Multi-window desktop dashboard.

## 3. UX and Information Architecture

### 3.1 Popup structure

```text
+------------------------------------------------------------------+
| [Codex] [Antigravity] [GLM]                         Updated now   |
| ---------------------------------------------------------------- |
| <Service-specific content>                           [Refresh][S] |
| ---------------------------------------------------------------- |
| Usage Dashboard   Status Page   Settings...   Quit               |
+------------------------------------------------------------------+
```

### 3.2 Visual hierarchy

1. Top fixed tabs (service chips).
2. Primary quota blocks for current tab.
3. Secondary details (models, groups, costs).
4. Action row.

### 3.3 Tab behavior

- Tabs are fixed, not dynamic.
- Last selected tab is persisted.
- Switching tabs should not block on network if cached data exists.
- If data is stale, show stale badge and allow manual refresh.

## 4. Service UI Specifications

### 4.1 Codex tab

Quota windows expected:

- 5-hour usage limit
- Weekly usage limit
- Code review limit

UI layout:

```text
Codex
Updated: just now

5-hour usage        [#####------------------] 22%   Resets in 2h41m
Weekly usage        [#########--------------] 36%   Resets in 3d20h
Code review         [##---------------------] 8%    Resets in 6d04h

Optional: credits/cost section
```

### 4.2 Antigravity tab

Antigravity has two sources:

- Local (language server)
- Remote (Google OAuth)

Antigravity quota is shown by model group. Each group is independent.

```text
Antigravity   Source: [Local] [Remote]
Updated: just now

Group: Core         [#########------------] 34%  6.8k/20k  Reset 3h20m
Models: sonnet 3.1k, opus 2.2k, embed 1.5k

Group: Research     [#############--------] 56%  11.2k/20k Reset 1d12h
Models: sonnet 6.7k, opus 4.5k

Group: Ops          [##-------------------] 9%   1.8k/20k  Reset 5d2h
```

Rules:

- Do not force one global percentage if group limits differ.
- If needed, show weighted aggregate as optional summary only.
- Group card can be collapsed/expanded in later versions.

### 4.3 GLM tab

Quota windows expected:

- 5-hour usage quota
- MCP monthly quota

UI layout:

```text
GLM
Updated: just now

5-hour quota        [####-----------------] 18%   Resets in 1h10m
MCP monthly quota   [###------------------] 12%   Resets on 2026-03-01

Optional: usageDetails by model/tool
```

## 5. State Model (UI)

Every tab supports these states:

- loading
- ok
- need_auth
- empty
- stale
- error

State handling:

- loading: skeleton rows, disable refresh button.
- need_auth: show connect/login CTA.
- empty: clear message with retry action.
- stale: dim percentages and show stale timestamp.
- error: show brief error and retry.

## 6. Unified Internal Data Contract

To avoid coupling UI to each provider payload shape, normalize into a common model.

```swift
enum ServiceTab: String, CaseIterable {
    case codex
    case antigravity
    case glm
}

enum DataState {
    case loading
    case ok
    case needAuth
    case empty
    case stale
    case error(message: String)
}

struct QuotaWindow {
    let id: String
    let title: String
    let usedPercent: Double?
    let usedValue: Double?
    let limitValue: Double?
    let remainingValue: Double?
    let unit: String?
    let resetsAt: Date?
    let resetLabel: String?
}

struct GroupQuota {
    let id: String
    let title: String
    let window: QuotaWindow
    let modelRows: [ModelRow]
}

struct ModelRow {
    let id: String
    let name: String
    let usedValue: Double?
    let usedPercent: Double?
}

struct ServiceSnapshot {
    let service: ServiceTab
    let state: DataState
    let updatedAt: Date?
    let windows: [QuotaWindow]
    let groups: [GroupQuota]
    let notes: [String]
}
```

Notes:

- Codex and GLM primarily use `windows`.
- Antigravity primarily uses `groups`.
- Both can still include optional `windows` summary.

## 7. External API Contracts

This section documents discovered contracts for implementation reference.

### 7.1 Codex

Primary usage endpoint (used in CodexBar implementation):

- Method: `GET`
- URL: `https://chatgpt.com/backend-api/wham/usage`
- Auth: `Authorization: Bearer <token>`
- Optional header: `ChatGPT-Account-Id`

Observed key fields:

- `rate_limit.primary_window.used_percent`
- `rate_limit.primary_window.reset_at`
- `rate_limit.primary_window.limit_window_seconds`
- `rate_limit.secondary_window.*`
- `credits.balance`, `credits.has_credits`

Reliability:

- Tag: official-internal or OSS-inferred
- Reason: used by real clients, but not a stable public API contract.

Code review data:

- Often obtained from dashboard parsing (`chatgpt.com/codex/settings/usage`) in OSS tools.
- Treat as optional source, not guaranteed API field.

### 7.2 GLM (z.ai)

Quota endpoint (global):

- Method: `GET`
- URL: `https://api.z.ai/api/monitor/usage/quota/limit`
- Auth: `Authorization: Bearer <api_key>`

Quota endpoint (CN):

- Method: `GET`
- URL: `https://open.bigmodel.cn/api/monitor/usage/quota/limit`
- Auth: `Authorization: Bearer <api_key>`

Observed key fields:

- `data.limits[]`
- limit `type`: `TOKENS_LIMIT` or `TIME_LIMIT`
- `percentage`, `remaining`, `usage`, `currentValue`
- `nextResetTime`
- `usageDetails[]`
- `planName`

Reliability:

- Tag: provider-exposed and OSS-validated
- Region and payload differences should be expected.

### 7.3 Antigravity

Local source endpoint:

- Method: `POST`
- URL: `https://127.0.0.1:<port>/exa.language_server_pb.LanguageServerService/GetUserStatus`
- Headers: `X-Codeium-Csrf-Token`, `Connect-Protocol-Version`

Remote source (current app behavior):

- OAuth access token via Google flow
- Fetches available model quotas from Cloud Code internal endpoints

Observed key fields:

- model-level `remainingFraction`
- model-level `resetTime`

Reliability:

- Tag: local protocol/internal API
- Schema can change, add resilient decoding and fallback logic.

## 8. Polling and Refresh Policy

Recommended defaults:

- Auto polling: 120s.
- Manual refresh: always available unless in loading lock.
- Retry backoff for network/API errors.

Staleness:

- Mark snapshot stale if fetch fails.
- Keep last good values visible with stale indicator.

## 9. Security and Storage

- Store OAuth/API secrets in Keychain.
- Do not persist raw tokens in plain text preferences.
- Persist only non-sensitive UI preferences in UserDefaults.

## 10. Mapping to Current Project

Current relevant files:

- `App/AgQuotaBarApp.swift`
- `App/AppState.swift`
- `UI/MenuBar/MenuDropdown.swift`
- `Services/LocalQuotaService.swift`
- `Services/RemoteQuotaService.swift`
- `Models/Placeholders.swift`
- `Models/OAuthModels.swift`

Planned implementation direction:

1. Add normalized service snapshot model.
2. Add service tab selection state.
3. Replace menu-style popup body with custom tabbed popup view.
4. Implement per-service adapter layers:
   - Codex adapter
   - Antigravity adapter (local/remote + grouping)
   - GLM adapter

## 11. Open Questions Before Full Integration

1. Codex code review source in v1: API-only fallback or include dashboard parsing path.
2. GLM regional default: global first or auto-detect CN.
3. Antigravity grouping logic: backend-provided groups or local grouping rules.
4. Popup rendering style: keep `MenuBarExtra(.menu)` or migrate to `MenuBarExtra(.window)` for richer UI.

## 12. Reference Links

- `https://github.com/steipete/CodexBar`
- `https://raw.githubusercontent.com/steipete/CodexBar/2f5b6af0860a6b6881872e0001aea59ad3167806/docs/codex.md`
- `https://raw.githubusercontent.com/steipete/CodexBar/2f5b6af0860a6b6881872e0001aea59ad3167806/docs/zai.md`
- `https://raw.githubusercontent.com/steipete/CodexBar/2f5b6af0860a6b6881872e0001aea59ad3167806/Sources/CodexBarCore/Providers/Codex/CodexOAuth/CodexOAuthUsageFetcher.swift`
- `https://raw.githubusercontent.com/steipete/CodexBar/2f5b6af0860a6b6881872e0001aea59ad3167806/Sources/CodexBarCore/Providers/Zai/ZaiUsageStats.swift`
