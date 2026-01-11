import AppKit
import SwiftUI

struct MenuDropdown: View {
    @ObservedObject var appState: AppState

    private var displayModels: ArraySlice<(account: Account, model: QuotaModel)> {
        appState.displayModels.prefix(7)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Models")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ForEach(displayModels, id: \.model.id) { item in
                Button {
                    appState.selectModel(item.model)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: appState.selectedModelId == item.model.id ? "checkmark" : "")
                            .frame(width: 14)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.model.name)
                            Text(item.account.email)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(item.model.remainingPercentage)%")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }

            Divider().padding(.vertical, 4)

            HStack(spacing: 8) {
                Text("Update")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $appState.pollingInterval) {
                    Text("30s").tag(30.0)
                    Text("2m").tag(120.0)
                    Text("1h").tag(3600.0)
                }
                .labelsHidden()
                Spacer()
                Button {
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider().padding(.vertical, 4)

            Button("Settings") {
                appState.openSettingsWindow()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .buttonStyle(.plain)

            Button("Quit AgQuotaBar") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .padding(.bottom, 6)
            .buttonStyle(.plain)
        }
        .frame(width: 260)
    }
}
