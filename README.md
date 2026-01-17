# AgQuotaBar

AgQuotaBar is a lightweight macOS menu bar application designed to help developers monitor their Google Antigravity quota in real-time. It provides a visual indicator directly in your system menu bar, ensuring you're always aware of your remaining usage.

## Features

- **Visual Quota Indicator**: A sleek, circular ring icon in the menu bar showing your current quota percentage.
- **Real-time Monitoring**: Automatic polling to keep your quota information up-to-date.
- **Dual Fetching Modes**:
  - **Local Mode**: Automatically detects and connects to a running `language_server` (Antigravity IDE) to fetch local quota data.
  - **Remote Mode**: Authenticate via OAuth to fetch quota data directly from the Cloud Code API.
- **Multi-Account Support**: Manage and toggle between multiple accounts.
- **Customizable UI**:
  - Toggle percentage display.
  - Monochrome mode for a minimalist look.
  - Customizable polling intervals (30s, 2m, 1h).
- **Localization**: Fully localized in English and Chinese.
- **Launch at Login**: Option to start the app automatically when you log in.

## Installation & Setup

### Prerequisites

- macOS 14.0 (Sonoma) or later.
- Xcode 15.0+ (for building from source).

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yeuleh/AgQuotaBar.git
   cd AgQuotaBar
   ```

2. Build using `xcodebuild`:
   ```bash
   xcodebuild -project AgQuotaBar.xcodeproj -scheme AgQuotaBar -configuration Debug build
   ```

3. Alternatively, open the project in Xcode:
   ```bash
   open AgQuotaBar.xcodeproj
   ```
   Then press `Cmd + R` to run.

### Setup

Upon first launch, the app will automatically open the Settings window.
- **Local Mode**: Requires a running `language_server`. The app detects its port and CSRF token automatically.
- **Remote Mode**: Navigate to the "Antigravity" tab in Settings, switch to "Remote" mode, and follow the OAuth login flow.

## Keyboard Shortcuts

- `Cmd + R`: Refresh quota data immediately.
- `Cmd + Q`: Quit the application.

## Architecture

- **App Layer**: `AgQuotaBarApp` serves as the entry point using SwiftUI's `MenuBarExtra`.
- **State Management**: `AppState` handles central data flow, polling, and user preferences.
- **Services**:
    - `LocalQuotaService`: Handles port detection (via `ps` and `lsof`) and local API requests.
    - `RemoteQuotaService`: Manages Cloud Code API interactions.
    - `OAuthService`: Handles the OAuth2 flow with PKCE.
    - `LocalizationManager`: Manages runtime language switching.
- **UI**: Pure SwiftUI components for settings and menu dropdown, with AppKit-based rendering for the menu bar icon.

## Debugging

Debug logs are written to `/tmp/agquotabar_debug.log`. You can monitor them using:
```bash
tail -f /tmp/agquotabar_debug.log
```

## License

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for details.
