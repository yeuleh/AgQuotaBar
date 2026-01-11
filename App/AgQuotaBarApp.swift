import SwiftUI

@main
struct AgQuotaBarApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuDropdown(appState: appState)
        } label: {
            MenuBarIcon(
                percentage: appState.selectedDisplayPercentage,
                isMonochrome: appState.isMonochrome,
                isStale: appState.isStale,
                showPercentage: appState.showPercentage
            )
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
