import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var l10n = LocalizationManager.shared

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "power")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Toggle(L10n.General.launchAtLogin, isOn: $appState.launchAtLogin)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "percent")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Toggle(L10n.General.showPercentage, isOn: $appState.showPercentage)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Toggle(L10n.General.monochromeIcon, isOn: $appState.isMonochrome)
                }
            } header: {
                Label(L10n.General.display, systemImage: "display")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Picker(L10n.General.language, selection: Binding(
                        get: { l10n.currentLanguage },
                        set: { l10n.setLanguage($0) }
                    )) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                HStack(spacing: 12) {
                    Color.clear.frame(width: 20)
                    Text(L10n.General.languageRestartHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label(L10n.General.localization, systemImage: "character.bubble")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .id(l10n.refreshId)
    }
}
