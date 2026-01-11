import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedSettingsTab) {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
                .tag(AppState.SettingsTab.general)

            AntigravitySettingsView()
                .tabItem { Label("Antigravity", systemImage: "cloud.fill") }
                .tag(AppState.SettingsTab.antigravity)

            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(AppState.SettingsTab.about)
        }
        .frame(width: 460, height: 320)
    }
}
