import AppKit
import Combine
import SwiftUI

@main
struct AgQuotaBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.appState)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController(appState: appState)
    }
}

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var appState: AppState
    private var iconHostingView: NSHostingView<MenuBarIcon>?
    private var cancellables = Set<AnyCancellable>()
    private var menuActionHandlers: [ObjectIdentifier: () -> Void] = [:]
    private let menuItemWidth: CGFloat = 290
    private let menuItemHeight: CGFloat = 28

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
        bindAppState()
        rebuildMenu()
        updateStatusIcon()
    }

    func updateAppState(_ appState: AppState) {
        self.appState = appState
        bindAppState()
        rebuildMenu()
        updateStatusIcon()
    }

    private func configureStatusItem() {
        statusItem.menu = menu
        guard let button = statusItem.button else { return }
        button.title = ""
        let hostingView = NSHostingView(
            rootView: MenuBarIcon(
                percentage: appState.selectedDisplayPercentage,
                isMonochrome: appState.isMonochrome,
                isStale: appState.isStale,
                showPercentage: appState.showPercentage
            )
        )
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.autoresizingMask = [.width, .height]
        button.addSubview(hostingView)
        iconHostingView = hostingView
        updateStatusItemLength()
    }

    private func bindAppState() {
        cancellables.removeAll()
        appState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshUI()
            }
            .store(in: &cancellables)
    }

    private func refreshUI() {
        updateStatusIcon()
        rebuildMenu()
    }

    private func updateStatusIcon() {
        iconHostingView?.rootView = MenuBarIcon(
            percentage: appState.selectedDisplayPercentage,
            isMonochrome: appState.isMonochrome,
            isStale: appState.isStale,
            showPercentage: appState.showPercentage
        )
        updateStatusItemLength()
    }

    private func updateStatusItemLength() {
        guard let button = statusItem.button, let hostingView = iconHostingView else {
            return
        }
        let fittingSize = hostingView.fittingSize
        let width = max(fittingSize.width, 18)
        statusItem.length = width
        var frame = button.bounds
        frame.size.width = width
        frame.size.height = max(frame.size.height, fittingSize.height)
        hostingView.frame = frame
        button.frame.size.width = width
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        menuActionHandlers.removeAll()

        addHeaderItem(L10n.Menu.models)

        if appState.quotaMode == .remote {
            buildRemoteModelsSection()
        } else {
            buildLocalModelsSection()
        }

        menu.addItem(.separator())
        menu.addItem(makeUpdateIntervalItem())
        menu.addItem(makeActionItem(title: L10n.Menu.refreshNow, keyEquivalent: "r") { [weak self] in
            guard let self else { return }
            Task { await self.appState.refreshNow() }
        })

        menu.addItem(.separator())

        menu.addItem(makeSettingsItem())

        menu.addItem(makeActionItem(title: L10n.Menu.quit, keyEquivalent: "q") {
            NSApplication.shared.terminate(nil)
        })
    }

    private func buildRemoteModelsSection() {
        let models = visibleRemoteModelsSliced
        if models.isEmpty {
            if appState.oauthService.isAuthenticated {
                addMessageItem(L10n.Menu.noModels)
            } else {
                addMessageItem(L10n.Menu.notLoggedIn)
                menu.addItem(makeActionItem(title: L10n.Menu.loginWithGoogle) { [weak self] in
                    guard let self else { return }
                    Task { _ = await self.appState.login() }
                })
            }
        } else {
            if let email = appState.remoteUserEmail {
                addHeaderItem(email)
            }
            for model in models {
                let item = makeModelItem(
                    name: model.displayName,
                    remainingPercentage: model.remainingPercentage,
                    usedPercentageText: "\(model.remainingPercentage)%",
                    isSelected: appState.selectedModelId == model.id
                ) { [weak self] in
                    self?.appState.selectRemoteModel(model)
                }
                menu.addItem(item)
            }
        }
    }

    private func buildLocalModelsSection() {
        let groups = groupedDisplayModels
        if groups.isEmpty {
            addMessageItem(L10n.Menu.noModelsConfigured)
            return
        }

        for group in groups {
            addHeaderItem(group.account.email)
            for model in group.models {
                let percentageText = model.remainingPercentage.map { "\($0)%" } ?? "--"
                let item = makeModelItem(
                    name: model.name,
                    remainingPercentage: model.remainingPercentage,
                    usedPercentageText: percentageText,
                    isSelected: appState.selectedModelId == model.id
                ) { [weak self] in
                    self?.appState.selectModel(model, accountId: group.account.id)
                }
                menu.addItem(item)
            }
        }
    }

    private func makeUpdateIntervalItem() -> NSMenuItem {
        let item = NSMenuItem(title: L10n.Menu.updateInterval, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.addItem(makeIntervalOption(title: L10n.Menu.interval30s, value: 30))
        submenu.addItem(makeIntervalOption(title: L10n.Menu.interval2m, value: 120))
        submenu.addItem(makeIntervalOption(title: L10n.Menu.interval1h, value: 3600))
        item.submenu = submenu
        return item
    }

    private func makeSettingsItem() -> NSMenuItem {
        if #available(macOS 14, *) {
            let settingsView = SettingsLink {
                Label(L10n.Menu.settings, systemImage: "gearshape")
            }
            .labelStyle(.titleAndIcon)
            .frame(maxWidth: .infinity, alignment: .leading)
            let hostingView = NSHostingView(rootView: settingsView)
            hostingView.frame = NSRect(x: 0, y: 0, width: menuItemWidth, height: menuItemHeight)
            let item = NSMenuItem()
            item.view = hostingView
            return item
        }
        return makeActionItem(title: L10n.Menu.settings) { [weak self] in
            self?.appState.openSettingsWindow()
        }
    }

    @objc private func showSettingsWindow() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeIntervalOption(title: String, value: TimeInterval) -> NSMenuItem {
        let item = makeActionItem(title: title) { [weak self] in
            self?.appState.pollingInterval = value
        }
        if appState.pollingInterval == value {
            item.state = .on
        }
        return item
    }

    private func makeModelItem(
        name: String,
        remainingPercentage: Int?,
        usedPercentageText: String,
        isSelected: Bool,
        onSelect: @escaping () -> Void
    ) -> NSMenuItem {
        let rowView = MenuModelRowView(
            isSelected: isSelected,
            name: name,
            remainingPercentage: remainingPercentage,
            usedPercentageText: usedPercentageText
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        let hostingView = MenuRowHostingView(rootView: rowView, onSelect: onSelect)
        hostingView.frame = NSRect(x: 0, y: 0, width: menuItemWidth, height: menuItemHeight)
        let item = NSMenuItem()
        item.target = self
        item.action = #selector(handleMenuItemAction(_:))
        item.view = hostingView
        menuActionHandlers[ObjectIdentifier(item)] = onSelect
        return item
    }

    private func addHeaderItem(_ title: String) {
        let item = NSMenuItem(title: title.uppercased(), action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = NSAttributedString(
            string: title.uppercased(),
            attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        menu.addItem(item)
    }

    private func addMessageItem(_ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        menu.addItem(item)
    }

    private func makeActionItem(
        title: String,
        keyEquivalent: String = "",
        action: @escaping () -> Void
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(handleMenuItemAction(_:)), keyEquivalent: keyEquivalent)
        item.target = self
        menuActionHandlers[ObjectIdentifier(item)] = action
        return item
    }

    @objc private func handleMenuItemAction(_ sender: NSMenuItem) {
        menuActionHandlers[ObjectIdentifier(sender)]?()
    }

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
}

final class MenuRowHostingView<Content: View>: NSHostingView<Content> {
    private let onSelect: () -> Void

    init(rootView: Content, onSelect: @escaping () -> Void) {
        self.onSelect = onSelect
        super.init(rootView: rootView)
    }

    required override init(rootView: Content) {
        self.onSelect = {}
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        self.onSelect = {}
        super.init(coder: coder)
    }

    override func mouseDown(with event: NSEvent) {
        onSelect()
        enclosingMenuItem?.menu?.cancelTracking()
    }
}
