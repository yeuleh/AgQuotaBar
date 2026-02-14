import AppKit
import SwiftUI

struct MenuDropdown: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var l10n = LocalizationManager.shared

    var body: some View {
        VStack(spacing: 12) {
            serviceTabs

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    snapshotHeader
                    snapshotMeta

                    if appState.selectedServiceTab == .antigravity {
                        antigravitySourceSwitch
                    }

                    snapshotBody(appState.selectedServiceSnapshot)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            bottomActions
        }
        .padding(12)
        .frame(width: 420, height: 560)
        .background(
            LinearGradient(
                colors: [
                    Color(NSColor.windowBackgroundColor),
                    Color(NSColor.controlBackgroundColor).opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .id(l10n.refreshId)
    }

    private var snapshotMeta: some View {
        let snapshot = appState.selectedServiceSnapshot
        return HStack(spacing: 8) {
            metadataChip(title: L10n.Menu.account, value: snapshot.account ?? L10n.Menu.notConnected)
            metadataChip(title: L10n.Menu.plan, value: snapshot.plan ?? L10n.Menu.unknownPlan)
            Spacer()
        }
    }

    private func metadataChip(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.08))
        )
    }

    private var serviceTabs: some View {
        HStack(spacing: 8) {
            ForEach(ServiceTab.allCases) { tab in
                Button {
                    appState.selectedServiceTab = tab
                } label: {
                    Text(title(for: tab))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(appState.selectedServiceTab == tab ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(appState.selectedServiceTab == tab ? Color.accentColor : Color.primary.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var snapshotHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title(for: appState.selectedServiceTab))
                .font(.system(size: 22, weight: .medium, design: .rounded))

            Spacer()

            if let updatedAt = appState.selectedServiceSnapshot.updatedAt {
                Text(relativeUpdatedText(from: updatedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("--")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var antigravitySourceSwitch: some View {
        HStack(spacing: 8) {
            sourceChip(title: L10n.Antigravity.localMode, mode: .local)
            sourceChip(title: L10n.Antigravity.remoteMode, mode: .remote)
            Spacer()
        }
    }

    private func sourceChip(title: String, mode: QuotaMode) -> some View {
        Button {
            appState.quotaMode = mode
            Task {
                await appState.refreshNow()
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(appState.quotaMode == mode ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(appState.quotaMode == mode ? Color.accentColor : Color.primary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func snapshotBody(_ snapshot: ServicePanelSnapshot) -> some View {
        switch snapshot.state {
        case .loading:
            loadingCard
        case .needsAuth:
            needsAuthCard
        case .empty:
            messageCard(text: L10n.Menu.noData)
        case .stale:
            messageCard(text: L10n.Menu.staleData)
            readyContent(snapshot)
        case .failed(let message):
            messageCard(text: message)
        case .ready:
            readyContent(snapshot)
        }
    }

    @ViewBuilder
    private func readyContent(_ snapshot: ServicePanelSnapshot) -> some View {
        if snapshot.windows.isEmpty == false {
            ForEach(snapshot.windows) { window in
                quotaWindowCard(window)
            }
        }

        if snapshot.groups.isEmpty == false {
            ForEach(snapshot.groups) { group in
                quotaGroupCard(group)
            }
        }

        if snapshot.notes.isEmpty == false {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(snapshot.notes, id: \.self) { note in
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
        }
    }

    private func quotaWindowCard(_ window: ServiceQuotaWindow, actionTitle: String? = nil, action: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(window.title)
                    .font(.system(size: 18, weight: .semibold))

                Spacer()

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }

                if let resetText = window.resetText {
                    Text(resetText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let usedPercent = window.usedPercent {
                UsageProgressBar(usedPercent: usedPercent)
                Text("\(usedPercent)% used")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(usageColor(for: usedPercent))
            }

            if let detail = window.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private func quotaGroupCard(_ group: ServiceUsageGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            quotaWindowCard(group.window, actionTitle: L10n.Menu.show) {
                appState.displayGroupUsageInMenuBar(group)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(group.models) { model in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(usageColor(for: model.usedPercent ?? 0).opacity(0.9))
                            .frame(width: 8, height: 8)

                        Text(model.name)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer()

                        Text(model.detail ?? "--")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(L10n.Menu.loading)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private var needsAuthCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.Menu.notLoggedIn)
                .font(.headline)
            Text(L10n.Menu.connectAccountHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                Task {
                    _ = await appState.login()
                }
            } label: {
                Label(L10n.Menu.loginWithGoogle, systemImage: "person.badge.key")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }

    private func messageCard(text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
    }

    private var bottomActions: some View {
        HStack(spacing: 8) {
            Button {
                Task {
                    await appState.refreshSelectedService()
                }
            } label: {
                Label(L10n.Menu.refreshNow, systemImage: "arrow.clockwise")
            }

            Menu {
                Button(L10n.Menu.interval30s) { appState.pollingInterval = 30 }
                Button(L10n.Menu.interval2m) { appState.pollingInterval = 120 }
                Button(L10n.Menu.interval1h) { appState.pollingInterval = 3600 }
            } label: {
                Label(L10n.Menu.updateInterval, systemImage: "clock")
            }

            Spacer()

            Button {
                appState.openSettingsWindow()
            } label: {
                Label(L10n.Menu.settings, systemImage: "gearshape")
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label(L10n.Menu.quit, systemImage: "power")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func title(for tab: ServiceTab) -> String {
        switch tab {
        case .codex:
            return L10n.Menu.tabCodex
        case .antigravity:
            return L10n.Menu.tabAntigravity
        case .glm:
            return L10n.Menu.tabGLM
        }
    }

    private func usageColor(for usedPercent: Int) -> Color {
        _ = usedPercent
        return .secondary
    }

    private func relativeUpdatedText(from date: Date) -> String {
        let delta = max(0, Int(Date().timeIntervalSince(date)))
        if delta < 10 {
            return L10n.Menu.updatedJustNow
        }
        if delta < 60 {
            return L10n.Menu.updatedSeconds(delta)
        }
        if delta < 3600 {
            return L10n.Menu.updatedMinutes(delta / 60)
        }
        return L10n.Menu.updatedHours(delta / 3600)
    }
}

private struct UsageProgressBar: View {
    let usedPercent: Int

    var body: some View {
        GeometryReader { proxy in
            let width = max(0, proxy.size.width * CGFloat(clampedPercent) / 100)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.green.opacity(0.65))

                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.3))
                    .frame(width: width)
            }
        }
        .frame(height: 10)
    }

    private var clampedPercent: Int {
        min(100, max(0, usedPercent))
    }

}
