import SwiftUI
import AppKit

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
        return result.map { group in
            let sortedModels = group.models.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return (account: group.account, models: sortedModels)
        }
    }
    
    private var visibleRemoteModelsSliced: [RemoteModelQuota] {
        let sliced = appState.visibleRemoteModels.prefix(7)
        return sliced.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
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

            SettingsLink {
                Label(L10n.Menu.settings, systemImage: "gearshape")
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
                    HStack(spacing: 10) {
                        if appState.selectedModelId == model.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.tertiary)
                        }
                        Text(model.displayName)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        QuotaRing(percentage: Double(model.remainingPercentage))
                        Text("\(model.remainingPercentage)%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .monospacedDigit()
                            .layoutPriority(1)
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
                        HStack(spacing: 10) {
                            if appState.selectedModelId == model.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.tertiary)
                            }
                            Text(model.name)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            if let remaining = model.remainingPercentage {
                                QuotaRing(percentage: Double(remaining))
                            }
                            Text(percentageText)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .monospacedDigit()
                                .layoutPriority(1)
                                .foregroundStyle(model.remainingPercentage.map { quotaColor(for: $0) } ?? .secondary)
                        }
                    }
                }
            }
        }
    }
    
    private func quotaColor(for percentage: Int) -> Color {
        if percentage >= 70 {
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

struct MenuModelRowView: View {
    let isSelected: Bool
    let name: String
    let remainingPercentage: Int?
    let usedPercentageText: String

    var body: some View {
        HStack(spacing: 12) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.blue)
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }

            Text(name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)
            
            Spacer()

            if let remaining = remainingPercentage {
                QuotaRing(percentage: Double(remaining))
            }

            Text(remainingPercentage.map { "\($0)%" } ?? "--")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .layoutPriority(1)
                .foregroundStyle(quotaColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(usedPercentageText)
    }
    
    private var quotaColor: Color {
        guard let percentage = remainingPercentage else { return .secondary }
        if percentage >= 70 {
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

private struct QuotaRing: View {
    let percentage: Double

    var body: some View {
        GravityArc(
            percentage: percentage,
            ringColor: ringColor,
            trackColor: Color.primary.opacity(0.25),
            lineWidth: 2.5
        )
        .frame(width: 14, height: 14)
    }

    private var ringColor: Color {
        if percentage >= 70 { return .green }
        else if percentage >= 30 { return .yellow }
        else if percentage > 0 { return .red }
        else { return .gray }
    }
}
