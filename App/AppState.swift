import AppKit
import Combine
import SwiftUI

private func log(_ message: String) {
    let logFile = "/tmp/agquotabar_debug.log"
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logFile) {
            if let handle = FileHandle(forWritingAtPath: logFile) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: logFile, contents: data)
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    enum SettingsTab: Hashable {
        case general
        case antigravity
        case about
    }

    @Published var selectedSettingsTab: SettingsTab = .general
    @Published var accounts: [Account] = []
    @Published var pollingInterval: TimeInterval = 120 {
        didSet {
            if oldValue != pollingInterval {
                restartPolling()
            }
        }
    }
    @Published var selectedModelId: String?
    @Published var isMonochrome: Bool = false
    @Published var isStale: Bool = false

    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false

    private let quotaService = LocalQuotaService()
    private var pollingTask: Task<Void, Never>?

    init() {
        log("AppState init")
        handleFirstLaunch()
        startPolling()
    }

    var selectedDisplayPercentage: Int? {
        guard isStale == false else {
            return nil
        }
        guard let selectedModelId else {
            return nil
        }
        for account in accounts {
            if let model = account.models.first(where: { $0.id == selectedModelId }) {
                return model.remainingPercentage
            }
        }
        return nil
    }

    var displayModels: [(account: Account, model: QuotaModel)] {
        accounts.flatMap { account in
            account.models.map { model in
                (account: account, model: model)
            }
        }
    }

    func selectModel(_ model: QuotaModel) {
        selectedModelId = model.id
    }

    func refreshNow() async {
        log("refreshNow: starting")
        do {
            let snapshot = try await quotaService.fetchQuota()
            log("refreshNow: got \(snapshot.models.count) models")
            apply(snapshot: snapshot)
        } catch {
            log("refreshNow: error \(error)")
            markStale()
        }
    }

    func openSettingsWindow() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func apply(snapshot: QuotaSnapshot) {
        let email = snapshot.userEmail ?? "Local"
        let account = Account(id: "local", email: email, models: snapshot.models)
        accounts = snapshot.models.isEmpty ? [] : [account]
        if selectedModelId == nil || accounts.first?.models.contains(where: { $0.id == selectedModelId }) == false {
            selectedModelId = accounts.first?.models.first?.id
        }
        isStale = snapshot.isStale
    }

    private func markStale() {
        isStale = true
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else {
                return
            }
            while !Task.isCancelled {
                await self.refreshNow()
                let interval = max(10, self.pollingInterval)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    private func restartPolling() {
        startPolling()
    }

    private func handleFirstLaunch() {
        guard hasLaunchedBefore == false else {
            return
        }
        hasLaunchedBefore = true
        selectedSettingsTab = .antigravity
        openSettingsWindow()
    }
}
