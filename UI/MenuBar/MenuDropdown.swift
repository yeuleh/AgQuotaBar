import AppKit
import SwiftUI

struct MenuDropdown: View {
    @ObservedObject var appState: AppState

    private var displayModels: ArraySlice<(account: Account, model: QuotaModel)> {
        appState.displayModels.prefix(7)
    }

    var body: some View {
        Group {
            Text("Models")
                .font(.caption)
                .foregroundStyle(.secondary)

            if displayModels.isEmpty {
                Text("No models configured")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(displayModels, id: \.model.id) { item in
                    let percentageText = item.model.remainingPercentage.map { "\($0)%" } ?? "--"
                    Button {
                        appState.selectModel(item.model)
                    } label: {
                        Label {
                            Text("\(item.model.name)  \(percentageText)")
                        } icon: {
                            if appState.selectedModelId == item.model.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            Picker("Update", selection: $appState.pollingInterval) {
                Text("30s").tag(30.0)
                Text("2m").tag(120.0)
                Text("1h").tag(3600.0)
            }

            Button("Refresh") {
                Task {
                    await appState.refreshNow()
                }
            }

            Divider()

            Button("Settings") {
                appState.openSettingsWindow()
            }

            Button("Quit AgQuotaBar") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
