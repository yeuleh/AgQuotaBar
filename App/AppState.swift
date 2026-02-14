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
    static let hiddenRemoteModelIds = "hiddenRemoteModelIds"
    static let pollingInterval = "pollingInterval"
    static let selectedModelId = "selectedModelId"
    static let accounts = "accounts"
    static let defaultAccountId = "defaultAccountId"
    static let quotaMode = "quotaMode"
    static let selectedServiceTab = "selectedServiceTab"
    static let displayedGroupId = "displayedGroupId"
}



struct StoredAccount: Identifiable, Codable, Hashable {
    let id: String
    let email: String
}

private struct IconDisplayOverride: Hashable {
    let percentage: Int
    let metric: IconDisplayMetric
    let sourceGroupId: String?
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
                if isReorderingAccounts == false {
                    reorderAccounts()
                }
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
                LocalizationManager.shared.setLanguage(language)
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
    @Published private var hiddenRemoteModelIds: Set<String>
    @Published var isStale: Bool = false
    
    @Published var quotaMode: QuotaMode {
        didSet {
            if oldValue != quotaMode {
                UserDefaults.standard.set(quotaMode.rawValue, forKey: PreferenceKey.quotaMode)
                restartPolling()
            }
        }
    }

    @Published var selectedServiceTab: ServiceTab {
        didSet {
            if oldValue != selectedServiceTab {
                UserDefaults.standard.set(selectedServiceTab.rawValue, forKey: PreferenceKey.selectedServiceTab)
            }
        }
    }
    
    @Published var remoteModels: [RemoteModelQuota] = []
    @Published var remoteUserEmail: String?
    @Published var remoteTier: String?
    @Published private(set) var localPlanName: String?
    @Published private(set) var lastAntigravityUpdatedAt: Date?
    @Published private var displayedGroupId: String? {
        didSet {
            if oldValue != displayedGroupId {
                UserDefaults.standard.set(displayedGroupId, forKey: PreferenceKey.displayedGroupId)
            }
        }
    }
    @Published private var iconDisplayOverride: IconDisplayOverride?
    @Published private(set) var codexSnapshot: ServicePanelSnapshot
    @Published private(set) var glmSnapshot: ServicePanelSnapshot

    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false

    private let localQuotaService = LocalQuotaService()
    private lazy var remoteQuotaService = RemoteQuotaService()
    let oauthService = OAuthService.shared
    
    private var pollingTask: Task<Void, Never>?
    private var isUpdatingLaunchAtLogin = false
    private var isReorderingAccounts = false

    init() {
        let defaults = UserDefaults.standard
        showPercentage = defaults.object(forKey: PreferenceKey.showPercentage) as? Bool ?? true
        isMonochrome = defaults.object(forKey: PreferenceKey.isMonochrome) as? Bool ?? false
        let languageRaw = defaults.string(forKey: PreferenceKey.language) ?? AppLanguage.english.rawValue
        language = AppLanguage(rawValue: languageRaw) ?? .english
        launchAtLogin = defaults.object(forKey: PreferenceKey.launchAtLogin) as? Bool ?? (SMAppService.mainApp.status == .enabled)
        hiddenModelIdsByAccount = Self.loadHiddenModelIds()
        hiddenRemoteModelIds = Self.loadHiddenRemoteModelIds()
        storedAccounts = Self.loadStoredAccounts()
        let storedInterval = defaults.object(forKey: PreferenceKey.pollingInterval) as? Double
        pollingInterval = storedInterval ?? 120
        selectedModelId = defaults.string(forKey: PreferenceKey.selectedModelId)
        defaultAccountId = defaults.string(forKey: PreferenceKey.defaultAccountId)
        
        let modeRaw = defaults.string(forKey: PreferenceKey.quotaMode) ?? QuotaMode.local.rawValue
        quotaMode = QuotaMode(rawValue: modeRaw) ?? .local

        let selectedServiceTabRaw = defaults.string(forKey: PreferenceKey.selectedServiceTab) ?? ServiceTab.antigravity.rawValue
        selectedServiceTab = ServiceTab(rawValue: selectedServiceTabRaw) ?? .antigravity

        let now = Date()
        localPlanName = nil
        lastAntigravityUpdatedAt = nil
        displayedGroupId = defaults.string(forKey: PreferenceKey.displayedGroupId)
        iconDisplayOverride = nil
        codexSnapshot = .codexPlaceholder(updatedAt: now)
        glmSnapshot = .glmPlaceholder(updatedAt: now)
        
        accounts = storedAccounts.map { Account(id: $0.id, email: $0.email, models: []) }

        log("AppState init")
        reorderAccounts()
        syncLaunchAtLogin()
        handleFirstLaunch()
        startPolling()
    }

    var selectedServiceSnapshot: ServicePanelSnapshot {
        switch selectedServiceTab {
        case .codex:
            return codexSnapshot
        case .antigravity:
            return antigravitySnapshot
        case .glm:
            return glmSnapshot
        }
    }

    var selectedDisplayPercentage: Int? {
        guard isStale == false else {
            return nil
        }

        if let iconDisplayOverride {
            switch iconDisplayOverride.metric {
            case .remaining:
                return iconDisplayOverride.percentage
            case .used:
                return max(0, min(100, 100 - iconDisplayOverride.percentage))
            }
        }
        
        if quotaMode == .remote {
            guard let selectedModelId else { return nil }
            return remoteModels.first(where: { $0.id == selectedModelId })?.remainingPercentage
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
    
    var allAvailableModels: [QuotaModel] {
        if quotaMode == .remote {
            return remoteModels.map { remote in
                QuotaModel(
                    id: remote.id,
                    name: remote.displayName,
                    remainingPercentage: remote.remainingPercentage,
                    resetTime: remote.resetTime,
                    isExhausted: remote.isExhausted
                )
            }
        } else {
            return accounts.flatMap { $0.models }
        }
    }

    func selectModel(_ model: QuotaModel, accountId: String) {
        selectedModelId = model.id
        defaultAccountId = accountId
    }
    
    func selectRemoteModel(_ model: RemoteModelQuota) {
        selectedModelId = model.id
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
    
    // MARK: - Remote Model Visibility
    
    var visibleRemoteModels: [RemoteModelQuota] {
        remoteModels.filter { isRemoteModelVisible(modelId: $0.id) }
    }
    
    func remoteModelVisibilityBinding(modelId: String) -> Binding<Bool> {
        Binding(
            get: { [weak self] in
                self?.isRemoteModelVisible(modelId: modelId) ?? true
            },
            set: { [weak self] newValue in
                self?.setRemoteModelVisible(modelId: modelId, visible: newValue)
            }
        )
    }
    
    func isRemoteModelVisible(modelId: String) -> Bool {
        hiddenRemoteModelIds.contains(modelId) == false
    }
    
    func setRemoteModelVisible(modelId: String, visible: Bool) {
        if visible {
            hiddenRemoteModelIds.remove(modelId)
        } else {
            hiddenRemoteModelIds.insert(modelId)
        }
        persistHiddenRemoteModelIds()
    }
    
    var visibleRemoteModelCount: Int {
        remoteModels.count - hiddenRemoteModelIds.count
    }

    func refreshNow() async {
        log("refreshNow: starting, mode=\(quotaMode)")
        
        if quotaMode == .remote {
            await refreshRemote()
        } else {
            await refreshLocal()
        }
    }

    func refreshSelectedService() async {
        switch selectedServiceTab {
        case .antigravity:
            await refreshNow()
        case .codex:
            refreshCodexSnapshot()
        case .glm:
            refreshGLMSnapshot()
        }
    }

    func displayGroupUsageInMenuBar(_ group: ServiceUsageGroup) {
        if displayUsageInMenuBar(usedPercentage: group.window.usedPercent, sourceGroupId: group.id) {
            displayedGroupId = group.id
        }
    }

    func isMenuBarShowingGroup(_ group: ServiceUsageGroup) -> Bool {
        if let sourceGroupId = iconDisplayOverride?.sourceGroupId {
            return sourceGroupId == group.id
        }
        return displayedGroupId == group.id
    }

    private func displayUsageInMenuBar(usedPercentage: Int?, sourceGroupId: String?) -> Bool {
        guard let usedPercentage else {
            return false
        }
        let clamped = min(100, max(0, usedPercentage))
        iconDisplayOverride = IconDisplayOverride(percentage: clamped, metric: .used, sourceGroupId: sourceGroupId)
        return true
    }
    
    private func refreshLocal() async {
        do {
            let snapshot = try await localQuotaService.fetchQuota()
            log("refreshLocal: got \(snapshot.models.count) models")
            apply(snapshot: snapshot)
        } catch {
            log("refreshLocal: error \(error)")
            markStale()
        }
    }
    
    private func refreshRemote() async {
        guard oauthService.isAuthenticated else {
            log("refreshRemote: not authenticated")
            markStale()
            return
        }
        
        do {
            let snapshot = try await remoteQuotaService.fetchQuota()
            log("refreshRemote: got \(snapshot.models.count) models")
            applyRemote(snapshot: snapshot)
        } catch {
            log("refreshRemote: error \(error)")
            if let oauthError = error as? OAuthError, oauthError.needsReauth {
                log("refreshRemote: token expired, need reauth")
            }
            markStale()
        }
    }
    
    private func applyRemote(snapshot: RemoteQuotaSnapshot) {
        remoteModels = snapshot.models
        remoteUserEmail = snapshot.userEmail
        remoteTier = snapshot.tier
        lastAntigravityUpdatedAt = snapshot.timestamp
        isStale = false
        
        if selectedModelId == nil || remoteModels.contains(where: { $0.id == selectedModelId }) == false {
            selectedModelId = remoteModels.first?.id
        }

        restoreDisplayedGroupOverrideIfPossible()
    }
    
    func login() async -> Bool {
        let success = await oauthService.login()
        if success {
            restartPolling()
        }
        return success
    }
    
    func logout() {
        _ = oauthService.logout()
        remoteModels = []
        remoteUserEmail = nil
        remoteTier = nil
        lastAntigravityUpdatedAt = nil
        isStale = true
    }

    func setRemoteAccount(id: String?) {
        let resolved = id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let accountId = resolved.isEmpty ? nil : resolved
        oauthService.setActiveAccount(id: accountId)
        remoteModels = []
        remoteUserEmail = oauthService.userEmail
        remoteTier = nil
        isStale = true
        Task { [weak self] in
            await self?.refreshNow()
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
    
    private static func loadHiddenRemoteModelIds() -> Set<String> {
        let raw = UserDefaults.standard.array(forKey: PreferenceKey.hiddenRemoteModelIds) as? [String] ?? []
        return Set(raw)
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
    
    private func persistHiddenRemoteModelIds() {
        UserDefaults.standard.set(Array(hiddenRemoteModelIds), forKey: PreferenceKey.hiddenRemoteModelIds)
    }

    private func persistStoredAccounts() {
        guard let data = try? JSONEncoder().encode(storedAccounts) else {
            return
        }
        UserDefaults.standard.set(data, forKey: PreferenceKey.accounts)
    }

    private func resolvedDefaultAccountId(from accounts: [StoredAccount]) -> String? {
        if let defaultAccountId,
           accounts.contains(where: { $0.id == defaultAccountId }) {
            return defaultAccountId
        }
        if let local = accounts.first(where: { $0.id == "local" }) {
            return local.id
        }
        return accounts.first?.id
    }

    private func setDefaultAccountId(_ newValue: String?) {
        guard newValue != defaultAccountId else {
            return
        }
        let wasReordering = isReorderingAccounts
        isReorderingAccounts = true
        defaultAccountId = newValue
        isReorderingAccounts = wasReordering
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

        let resolvedDefaultId = resolvedDefaultAccountId(from: currentAccounts)
        setDefaultAccountId(resolvedDefaultId)

        let localModels: [QuotaModel]
        if let snapshot {
            localModels = snapshot.models
        } else {
            localModels = accounts.first(where: { $0.id == "local" })?.models ?? []
        }
        let modelMap = ["local": localModels]
        accounts = orderedAccounts(from: currentAccounts, modelMap: modelMap, defaultAccountId: resolvedDefaultId)
    }

    private func orderedAccounts(from accounts: [StoredAccount], modelMap: [String: [QuotaModel]], defaultAccountId: String?) -> [Account] {
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
        isReorderingAccounts = true
        defer { isReorderingAccounts = false }
        let resolvedDefaultId = resolvedDefaultAccountId(from: storedAccounts)
        setDefaultAccountId(resolvedDefaultId)
        let localModels = accounts.first(where: { $0.id == "local" })?.models ?? []
        accounts = orderedAccounts(from: storedAccounts, modelMap: ["local": localModels], defaultAccountId: resolvedDefaultId)
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
        localPlanName = snapshot.planName
        lastAntigravityUpdatedAt = snapshot.timestamp
        let availableModels = accounts.flatMap { $0.models }
        if selectedModelId == nil || availableModels.contains(where: { $0.id == selectedModelId }) == false {
            selectedModelId = availableModels.first?.id
        }
        if selectedModelId == nil {
            UserDefaults.standard.removeObject(forKey: PreferenceKey.selectedModelId)
        }
        isStale = snapshot.isStale

        restoreDisplayedGroupOverrideIfPossible()
    }

    private func restoreDisplayedGroupOverrideIfPossible() {
        guard let displayedGroupId else {
            return
        }
        guard let group = antigravitySnapshot.groups.first(where: { $0.id == displayedGroupId }) else {
            iconDisplayOverride = nil
            return
        }
        _ = displayUsageInMenuBar(usedPercentage: group.window.usedPercent, sourceGroupId: displayedGroupId)
    }

    private func markStale() {
        isStale = true
    }

    private func refreshCodexSnapshot() {
        codexSnapshot = .codexPlaceholder(updatedAt: Date())
    }

    private func refreshGLMSnapshot() {
        glmSnapshot = .glmPlaceholder(updatedAt: Date())
    }

    private var antigravitySnapshot: ServicePanelSnapshot {
        if quotaMode == .remote && oauthService.isAuthenticated == false {
            return ServicePanelSnapshot(
                service: .antigravity,
                state: .needsAuth,
                updatedAt: nil,
                account: antigravityAccountText,
                plan: antigravityPlanText,
                windows: [],
                groups: [],
                notes: ["Sign in with Google to load remote quota."]
            )
        }

        let models: [(id: String, name: String, remaining: Int?, reset: Date?)]
        if quotaMode == .remote {
            models = remoteModels.map { model in
                (id: model.id, name: model.displayName, remaining: model.remainingPercentage, reset: model.resetTime)
            }
        } else {
            models = visibleDisplayModels.map { item in
                (id: item.model.id, name: item.model.name, remaining: item.model.remainingPercentage, reset: item.model.resetTime)
            }
        }

        if models.isEmpty {
            let state: ServicePanelState = isStale ? .stale : .empty
            return ServicePanelSnapshot(
                service: .antigravity,
                state: state,
                updatedAt: nil,
                account: antigravityAccountText,
                plan: antigravityPlanText,
                windows: [],
                groups: [],
                notes: ["No model quota data available."]
            )
        }

        let grouped = Dictionary(grouping: models) { model in
            AppState.antigravityGroupName(for: model.name)
        }

        let groups = grouped.keys.sorted().map { groupName in
            let groupModels = grouped[groupName, default: []]
            let usageItems: [ServiceModelUsage] = groupModels.map { model in
                let used = model.remaining.map { max(0, min(100, 100 - $0)) }
                return ServiceModelUsage(
                    id: model.id,
                    name: model.name,
                    usedPercent: used,
                    detail: used.map { "\($0)% used" }
                )
            }

            let usedPercentValues = usageItems.compactMap(\.usedPercent)
            let averageUsed = usedPercentValues.isEmpty ? nil : usedPercentValues.reduce(0, +) / usedPercentValues.count
            let earliestReset = groupModels.compactMap(\.reset).min()

            let window = ServiceQuotaWindow(
                id: "antigravity-group-\(groupName.lowercased())",
                title: groupName,
                usedPercent: averageUsed,
                detail: nil,
                resetText: earliestReset.map { Self.relativeResetText(from: $0) }
            )

            return ServiceUsageGroup(
                id: window.id,
                title: groupName,
                window: window,
                models: usageItems.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            )
        }

        return ServicePanelSnapshot(
            service: .antigravity,
            state: isStale ? .stale : .ready,
            updatedAt: lastAntigravityUpdatedAt,
            account: antigravityAccountText,
            plan: antigravityPlanText,
            windows: [],
            groups: groups,
            notes: []
        )
    }

    private var antigravityAccountText: String? {
        if quotaMode == .remote {
            return remoteUserEmail
        }
        return accounts.first(where: { $0.id == "local" })?.email
    }

    private var antigravityPlanText: String? {
        if quotaMode == .remote {
            return remoteTier
        }
        return localPlanName
    }

    private static func antigravityGroupName(for modelName: String) -> String {
        let lowercased = modelName.lowercased()
        if lowercased.contains("claude") {
            return "Claude"
        }
        if lowercased.contains("gemini") {
            return "Gemini"
        }
        if lowercased.contains("gpt") {
            return "GPT"
        }
        return "Other"
    }

    private static func relativeResetText(from date: Date) -> String {
        let interval = max(0, Int(date.timeIntervalSinceNow))
        let day = 24 * 60 * 60
        let hour = 60 * 60
        let minute = 60

        if interval >= day {
            let days = interval / day
            let hours = (interval % day) / hour
            return "Resets in \(days)d \(hours)h"
        }

        if interval >= hour {
            let hours = interval / hour
            let minutes = (interval % hour) / minute
            return "Resets in \(hours)h \(minutes)m"
        }

        let minutes = max(1, interval / minute)
        return "Resets in \(minutes)m"
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
