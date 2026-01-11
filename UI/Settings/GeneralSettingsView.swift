import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Toggle("Launch at Login", isOn: $appState.launchAtLogin)
            Toggle("Show Percentage in Menu Bar", isOn: $appState.showPercentage)
            Toggle("Monochrome Icon", isOn: $appState.isMonochrome)
            
            Divider()
                .padding(.vertical, 4)
            
            Picker("Language", selection: $appState.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(.menu)
            
            Text("Changes to language require a restart to take effect.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}
