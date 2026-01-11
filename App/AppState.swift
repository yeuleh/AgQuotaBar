import AppKit
import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum SettingsTab: Hashable {
        case general
        case antigravity
        case about
    }

    @Published var selectedSettingsTab: SettingsTab = .general
    @Published var accounts: [Account] = Account.placeholders
    @Published var pollingInterval: TimeInterval = 120
    @Published var selectedModelId: String?
    @Published var isMonochrome: Bool = false

    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false

    init() {
        if selectedModelId == nil {
            selectedModelId = accounts.first?.models.first?.id
        }
        handleFirstLaunch()
    }

    var selectedDisplayPercentage: Int? {
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

    func openSettingsWindow() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
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
