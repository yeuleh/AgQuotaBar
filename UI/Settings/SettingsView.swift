import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedSettingsTab) {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape.fill") }
                .tag(AppState.SettingsTab.general)

            AntigravitySettingsView()
                .tabItem { Label("Antigravity", systemImage: "bolt.horizontal.fill") }
                .tag(AppState.SettingsTab.antigravity)

            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle.fill") }
                .tag(AppState.SettingsTab.about)
        }
        .frame(width: 520, height: 420)
    }
}
