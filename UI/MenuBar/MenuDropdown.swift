import AppKit
import SwiftUI

struct MenuDropdown: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var l10n = LocalizationManager.shared

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
            Text(L10n.Menu.models)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if appState.quotaMode == .remote {
                remoteModelsSection
            } else {
                localModelsSection
            }

            Divider()

            Picker(L10n.Menu.updateInterval, selection: $appState.pollingInterval) {
                Text(L10n.Menu.interval30s).tag(30.0)
                Text(L10n.Menu.interval2m).tag(120.0)
                Text(L10n.Menu.interval1h).tag(3600.0)
            }

            Button {
                Task {
                    await appState.refreshNow()
                }
            } label: {
                Label(L10n.Menu.refreshNow, systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)

            Divider()

            if #available(macOS 14, *) {
                SettingsLink {
                    Label(L10n.Menu.settings, systemImage: "gearshape")
                }
            } else {
                Button {
                    appState.openSettingsWindow()
                } label: {
                    Label(L10n.Menu.settings, systemImage: "gearshape")
                }
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label(L10n.Menu.quit, systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .id(l10n.refreshId)
    }
    
    @ViewBuilder
    private var remoteModelsSection: some View {
        let models = visibleRemoteModelsSliced
        if models.isEmpty {
            if appState.oauthService.isAuthenticated {
                Text(L10n.Menu.noModels)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(L10n.Menu.notLoggedIn)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button {
                    Task {
                        _ = await appState.login()
                    }
                } label: {
                    Label(L10n.Menu.loginWithGoogle, systemImage: "person.badge.key")
                }
            }
        } else {
            if let email = appState.remoteUserEmail {
                Label(email, systemImage: "person.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            ForEach(models) { model in
                Button {
                    appState.selectRemoteModel(model)
                } label: {
                    HStack(spacing: 8) {
                        if appState.selectedModelId == model.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                        }
                        Text(model.displayName)
                        Spacer()
                        Text("\(model.remainingPercentage)%")
                            .monospacedDigit()
                            .foregroundStyle(quotaColor(for: model.remainingPercentage))
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var localModelsSection: some View {
        let groups = groupedDisplayModels
        if groups.isEmpty {
            Text(L10n.Menu.noModelsConfigured)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(groups, id: \.account.id) { group in
                Label(group.account.email, systemImage: "person.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(group.models, id: \.id) { model in
                    let percentageText = model.remainingPercentage.map { "\($0)%" } ?? "--"
                    Button {
                        appState.selectModel(model, accountId: group.account.id)
                    } label: {
                        HStack(spacing: 8) {
                            if appState.selectedModelId == model.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                            }
                            Text(model.name)
                            Spacer()
                            Text(percentageText)
                                .monospacedDigit()
                                .foregroundStyle(model.remainingPercentage.map { quotaColor(for: $0) } ?? .secondary)
                        }
                    }
                }
            }
        }
    }
    
    private func quotaColor(for percentage: Int) -> Color {
        if percentage >= 50 {
            return .green
        } else if percentage >= 30 {
            return .yellow
        } else if percentage > 0 {
            return .red
        } else {
            return .gray
        }
    }
}
