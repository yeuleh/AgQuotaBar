import AppKit
import SwiftUI

struct MenuDropdown: View {
    @ObservedObject var appState: AppState

    private var groupedDisplayModels: [(account: Account, models: [QuotaModel])] {
        let sliced = appState.visibleDisplayModels.prefix(7)
        var result: [(account: Account, models: [QuotaModel])] = []
        for item in sliced {
            if var last = result.last, last.account.id == item.account.id {
                last.models.append(item.model)
                result[result.count - 1] = last
            } else {
                result.append((account: item.account, models: [item.model]))
            }
        }
        return result
    }
    
    private var visibleRemoteModelsSliced: [RemoteModelQuota] {
        Array(appState.visibleRemoteModels.prefix(7))
    }

    var body: some View {
        Group {
            Text("Models")
                .font(.caption)
                .foregroundStyle(.secondary)

            if appState.quotaMode == .remote {
                remoteModelsSection
            } else {
                localModelsSection
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

            if #available(macOS 14, *) {
                SettingsLink {
                    Text("Settings")
                }
            } else {
                Button("Settings") {
                    appState.openSettingsWindow()
                }
            }

            Button("Quit AgQuotaBar") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    @ViewBuilder
    private var remoteModelsSection: some View {
        let models = visibleRemoteModelsSliced
        if models.isEmpty {
            if appState.oauthService.isAuthenticated {
                Text("No models available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Not logged in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button("Login with Google") {
                    Task {
                        _ = await appState.login()
                    }
                }
            }
        } else {
            if let email = appState.remoteUserEmail {
                Text(email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            ForEach(models) { model in
                let percentageText = "\(model.remainingPercentage)%"
                Button {
                    appState.selectRemoteModel(model)
                } label: {
                    Label {
                        Text("\(model.displayName)  \(percentageText)")
                    } icon: {
                        if appState.selectedModelId == model.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var localModelsSection: some View {
        let groups = groupedDisplayModels
        if groups.isEmpty {
            Text("No models configured")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(groups, id: \.account.id) { group in
                Text(group.account.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(group.models, id: \.id) { model in
                    let percentageText = model.remainingPercentage.map { "\($0)%" } ?? "--"
                    Button {
                        appState.selectModel(model, accountId: group.account.id)
                    } label: {
                        Label {
                            Text("\(model.name)  \(percentageText)")
                        } icon: {
                            if appState.selectedModelId == model.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
    }
}
