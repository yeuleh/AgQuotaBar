import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var l10n = LocalizationManager.shared

    var body: some View {
        TabView(selection: $appState.selectedSettingsTab) {
            GeneralSettingsView()
                .tabItem { Label(L10n.Settings.general, systemImage: "gearshape.fill") }
                .tag(AppState.SettingsTab.general)

            AntigravitySettingsView()
                .tabItem { Label(L10n.Settings.antigravity, systemImage: "bolt.horizontal.fill") }
                .tag(AppState.SettingsTab.antigravity)

            AboutSettingsView()
                .tabItem { Label(L10n.Settings.about, systemImage: "info.circle.fill") }
                .tag(AppState.SettingsTab.about)
        }
        .frame(width: 520, height: 420)
        .id(l10n.refreshId)
    }
}
