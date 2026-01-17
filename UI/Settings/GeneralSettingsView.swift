import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "power")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Toggle("Launch at Login", isOn: $appState.launchAtLogin)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "percent")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Toggle("Show Percentage in Menu Bar", isOn: $appState.showPercentage)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Toggle("Monochrome Icon", isOn: $appState.isMonochrome)
                }
            } header: {
                Label("Display", systemImage: "display")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Picker("Language", selection: $appState.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                HStack(spacing: 12) {
                    Color.clear.frame(width: 20)
                    Text("Changes to language require a restart to take effect.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label("Localization", systemImage: "character.bubble")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
