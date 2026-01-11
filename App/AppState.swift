import AppKit
import Combine
import ServiceManagement
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

private enum PreferenceKey {
    static let showPercentage = "showPercentage"
    static let isMonochrome = "isMonochrome"
    static let language = "language"
    static let launchAtLogin = "launchAtLogin"
    static let hiddenModelIds = "hiddenModelIds"
    static let pollingInterval = "pollingInterval"
    static let selectedModelId = "selectedModelId"
    static let accounts = "accounts"
    static let defaultAccountId = "defaultAccountId"
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case chinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .chinese:
            return "中文"
        }
    }
}

struct StoredAccount: Identifiable, Codable, Hashable {
    let id: String
    let email: String
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
    @Published private var storedAccounts: [StoredAccount]
    @Published var pollingInterval: TimeInterval = 120 {
        didSet {
            if oldValue != pollingInterval {
                UserDefaults.standard.set(pollingInterval, forKey: PreferenceKey.pollingInterval)
                restartPolling()
            }
        }
    }
    @Published var selectedModelId: String? {
        didSet {
            if oldValue != selectedModelId {
                UserDefaults.standard.set(selectedModelId, forKey: PreferenceKey.selectedModelId)
            }
        }
    }
    @Published var defaultAccountId: String? {
        didSet {
            if oldValue != defaultAccountId {
                UserDefaults.standard.set(defaultAccountId, forKey: PreferenceKey.defaultAccountId)
                reorderAccounts()
            }
        }
    }
    @Published var showPercentage: Bool {
        didSet {
            if oldValue != showPercentage {
                UserDefaults.standard.set(showPercentage, forKey: PreferenceKey.showPercentage)
            }
        }
    }
    @Published var isMonochrome: Bool {
        didSet {
            if oldValue != isMonochrome {
                UserDefaults.standard.set(isMonochrome, forKey: PreferenceKey.isMonochrome)
            }
        }
    }
    @Published var language: AppLanguage {
        didSet {
            if oldValue != language {
                UserDefaults.standard.set(language.rawValue, forKey: PreferenceKey.language)
            }
        }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            if oldValue != launchAtLogin {
                updateLaunchAtLogin()
            }
        }
    }
    @Published private var hiddenModelIdsByAccount: [String: Set<String>]
    @Published var isStale: Bool = false

    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false

    private let quotaService = LocalQuotaService()
    private var pollingTask: Task<Void, Never>?
    private var isUpdatingLaunchAtLogin = false

    init() {
        let defaults = UserDefaults.standard
        showPercentage = defaults.object(forKey: PreferenceKey.showPercentage) as? Bool ?? true
        isMonochrome = defaults.object(forKey: PreferenceKey.isMonochrome) as? Bool ?? false
        let languageRaw = defaults.string(forKey: PreferenceKey.language) ?? AppLanguage.english.rawValue
        language = AppLanguage(rawValue: languageRaw) ?? .english
        launchAtLogin = defaults.object(forKey: PreferenceKey.launchAtLogin) as? Bool ?? (SMAppService.mainApp.status == .enabled)
        hiddenModelIdsByAccount = Self.loadHiddenModelIds()
        storedAccounts = Self.loadStoredAccounts()
        let storedInterval = defaults.object(forKey: PreferenceKey.pollingInterval) as? Double
        pollingInterval = storedInterval ?? 120
        selectedModelId = defaults.string(forKey: PreferenceKey.selectedModelId)
        defaultAccountId = defaults.string(forKey: PreferenceKey.defaultAccountId)
        accounts = storedAccounts.map { Account(id: $0.id, email: $0.email, models: []) }

        log("AppState init")
        reorderAccounts()
        syncLaunchAtLogin()
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
        if let defaultAccountId,
           let account = accounts.first(where: { $0.id == defaultAccountId }),
           let model = account.models.first(where: { $0.id == selectedModelId }) {
            return model.remainingPercentage
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

    var visibleDisplayModels: [(account: Account, model: QuotaModel)] {
        displayModels.filter { item in
            isModelVisible(accountId: item.account.id, modelId: item.model.id)
        }
    }

    func selectModel(_ model: QuotaModel, accountId: String) {
        selectedModelId = model.id
        defaultAccountId = accountId
    }

    func addAccount(email: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.isEmpty == false else {
            return
        }
        let account = StoredAccount(id: "manual-\(UUID().uuidString)", email: trimmedEmail)
        storedAccounts.append(account)
        persistStoredAccounts()
        rebuildAccounts(snapshot: Optional<QuotaSnapshot>.none)
    }

    func removeAccount(id: String) {
        storedAccounts.removeAll { $0.id == id }
        hiddenModelIdsByAccount.removeValue(forKey: id)
        if defaultAccountId == id {
            defaultAccountId = nil
        }
        persistHiddenModelIds()
        persistStoredAccounts()
        rebuildAccounts(snapshot: Optional<QuotaSnapshot>.none)
    }

    func setDefaultAccount(id: String) {
        defaultAccountId = id
    }

    func isDefaultAccount(id: String) -> Bool {
        defaultAccountId == id
    }

    func modelVisibilityBinding(accountId: String, modelId: String) -> Binding<Bool> {
        Binding(
            get: { [weak self] in
                self?.isModelVisible(accountId: accountId, modelId: modelId) ?? true
            },
            set: { [weak self] newValue in
                self?.setModelVisible(accountId: accountId, modelId: modelId, visible: newValue)
            }
        )
    }

    func isModelVisible(accountId: String, modelId: String) -> Bool {
        guard let hiddenIds = hiddenModelIdsByAccount[accountId] else {
            return true
        }
        return hiddenIds.contains(modelId) == false
    }

    func setModelVisible(accountId: String, modelId: String, visible: Bool) {
        var hiddenIds = hiddenModelIdsByAccount[accountId] ?? Set<String>()
        if visible {
            hiddenIds.remove(modelId)
        } else {
            hiddenIds.insert(modelId)
        }
        hiddenModelIdsByAccount[accountId] = hiddenIds
        persistHiddenModelIds()
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

    private static func loadHiddenModelIds() -> [String: Set<String>] {
        let raw = UserDefaults.standard.dictionary(forKey: PreferenceKey.hiddenModelIds) ?? [:]
        var result: [String: Set<String>] = [:]
        for (key, value) in raw {
            if let ids = value as? [String] {
                result[key] = Set(ids)
            }
        }
        return result
    }

    private static func loadStoredAccounts() -> [StoredAccount] {
        guard let data = UserDefaults.standard.data(forKey: PreferenceKey.accounts) else {
            return []
        }
        return (try? JSONDecoder().decode([StoredAccount].self, from: data)) ?? []
    }

    private func persistHiddenModelIds() {
        let raw = hiddenModelIdsByAccount.mapValues { Array($0) }
        UserDefaults.standard.set(raw, forKey: PreferenceKey.hiddenModelIds)
    }

    private func persistStoredAccounts() {
        guard let data = try? JSONEncoder().encode(storedAccounts) else {
            return
        }
        UserDefaults.standard.set(data, forKey: PreferenceKey.accounts)
    }

    private func rebuildAccounts(snapshot: QuotaSnapshot?) {
        var currentAccounts = storedAccounts
        if let snapshot {
            let email = snapshot.userEmail ?? "Local"
            if let index = currentAccounts.firstIndex(where: { $0.id == "local" }) {
                currentAccounts[index] = StoredAccount(id: "local", email: email)
            } else {
                currentAccounts.insert(StoredAccount(id: "local", email: email), at: 0)
            }
        }
        storedAccounts = currentAccounts
        persistStoredAccounts()

        let localModels: [QuotaModel]
        if let snapshot {
            localModels = snapshot.models
        } else {
            localModels = accounts.first(where: { $0.id == "local" })?.models ?? []
        }
        let modelMap = ["local": localModels]
        accounts = orderedAccounts(from: currentAccounts, modelMap: modelMap)
    }

    private func orderedAccounts(from accounts: [StoredAccount], modelMap: [String: [QuotaModel]]) -> [Account] {
        let sorted = accounts.sorted { lhs, rhs in
            if lhs.id == defaultAccountId {
                return true
            }
            if rhs.id == defaultAccountId {
                return false
            }
            return lhs.email.localizedCaseInsensitiveCompare(rhs.email) == .orderedAscending
        }
        return sorted.map { account in
            let models = modelMap[account.id] ?? []
            return Account(id: account.id, email: account.email, models: models)
        }
    }

    private func reorderAccounts() {
        accounts = orderedAccounts(from: storedAccounts, modelMap: ["local": accounts.first(where: { $0.id == "local" })?.models ?? []])
    }

    private func syncLaunchAtLogin() {
        let statusEnabled = SMAppService.mainApp.status == .enabled
        if statusEnabled != launchAtLogin {
            updateLaunchAtLogin()
        } else {
            UserDefaults.standard.set(launchAtLogin, forKey: PreferenceKey.launchAtLogin)
        }
    }

    private func updateLaunchAtLogin() {
        guard isUpdatingLaunchAtLogin == false else {
            return
        }
        isUpdatingLaunchAtLogin = true
        defer { isUpdatingLaunchAtLogin = false }

        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log("launchAtLogin: \(error)")
        }

        UserDefaults.standard.set(launchAtLogin, forKey: PreferenceKey.launchAtLogin)
    }

    private func apply(snapshot: QuotaSnapshot) {
        rebuildAccounts(snapshot: snapshot)
        let availableModels = accounts.flatMap { $0.models }
        if selectedModelId == nil || availableModels.contains(where: { $0.id == selectedModelId }) == false {
            selectedModelId = availableModels.first?.id
        }
        if selectedModelId == nil {
            UserDefaults.standard.removeObject(forKey: PreferenceKey.selectedModelId)
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
