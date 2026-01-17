import SwiftUI

struct AntigravitySettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var newAccountEmail = ""
    @State private var isLoggingIn = false

    var body: some View {
        Form {
            quotaModeSection
            
            if appState.quotaMode == .remote {
                remoteAccountSection
            } else {
                localAccountSection
            }
            
            modelVisibilitySection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
    
    private var quotaModeSection: some View {
        Section {
            Picker("模式", selection: $appState.quotaMode) {
                ForEach(QuotaMode.allCases) { mode in
                    HStack(spacing: 8) {
                        Image(systemName: mode == .remote ? "cloud.fill" : "desktopcomputer")
                            .foregroundStyle(mode == .remote ? .blue : .green)
                        Text(mode.displayName)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            
            Text(appState.quotaMode.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 24)
        } header: {
            Label("配额获取方式", systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }
    
    private var remoteAccountSection: some View {
        Section {
            if appState.oauthService.isAuthenticated {
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.green.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("已登录")
                            .font(.headline)
                        
                        if let email = appState.remoteUserEmail {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let tier = appState.remoteTier {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Text("账号级别: \(tier)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button("登出") {
                        appState.logout()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(.orange.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.title2)
                                .foregroundStyle(.orange)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.oauthService.authState.displayText)
                                .font(.headline)
                            Text("登录 Google 账号以获取配额信息")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Text("远程模式不依赖本地 Antigravity 环境。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 52)
                    
                    Button {
                        isLoggingIn = true
                        Task {
                            _ = await appState.login()
                            isLoggingIn = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isLoggingIn {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "person.badge.key.fill")
                            }
                            Text(isLoggingIn ? "登录中..." : "使用 Google 账号登录")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isLoggingIn)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Label("Google 账号", systemImage: "person.crop.circle")
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }
    
    private var localAccountSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                TextField("Email", text: $newAccountEmail)
                    .textFieldStyle(.roundedBorder)
                Button {
                    appState.addAccount(email: newAccountEmail)
                    newAccountEmail = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .disabled(newAccountEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            Label("添加账号", systemImage: "person.badge.plus")
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }
    
    private var modelVisibilitySection: some View {
        Group {
            if appState.quotaMode == .remote {
                remoteModelVisibilitySection
            } else {
                localModelVisibilitySection
            }
        }
    }
    
    private var remoteModelVisibilitySection: some View {
        Section {
            if appState.remoteModels.isEmpty {
                HStack {
                    Image(systemName: "tray")
                        .foregroundStyle(.secondary)
                    Text("暂无模型")
                        .foregroundStyle(.secondary)
                }
            } else {
                let visibleCount = appState.visibleRemoteModelCount
                let sortedModels = appState.remoteModels.sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
                
                Text("开启开关以在菜单栏下拉列表中显示该模型")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ForEach(sortedModels) { model in
                    let isVisible = appState.isRemoteModelVisible(modelId: model.id)
                    let canToggleOn = visibleCount < 7 || isVisible
                    
                    Toggle(isOn: appState.remoteModelVisibilityBinding(modelId: model.id)) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(quotaColor(for: model.remainingPercentage))
                                .frame(width: 8, height: 8)
                            Text(model.displayName)
                            Spacer()
                            Text("\(model.remainingPercentage)%")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .disabled(!canToggleOn && !isVisible)
                }
                
                if visibleCount >= 7 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("已达到最大显示数量 (7个)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        } header: {
            Label("模型配额与显示", systemImage: "chart.bar.fill")
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }
    
    private var localModelVisibilitySection: some View {
        Group {
            if appState.accounts.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .foregroundStyle(.secondary)
                        Text("暂无账号")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("模型可见性", systemImage: "eye")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            } else {
                ForEach(appState.accounts) { account in
                    Section {
                        if account.models.isEmpty {
                            HStack {
                                Image(systemName: "tray")
                                    .foregroundStyle(.secondary)
                                Text("暂无模型")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            let sortedModels = account.models.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
                            ForEach(sortedModels) { model in
                                Toggle(model.name, isOn: appState.modelVisibilityBinding(accountId: account.id, modelId: model.id))
                                    .toggleStyle(.switch)
                            }
                        }
                    } header: {
                        accountHeader(account: account)
                    }
                }
            }
        }
    }
    
    private func accountHeader(account: Account) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
            
            Text(account.email)
                .font(.subheadline.bold())
            
            Spacer()
            
            if appState.isDefaultAccount(id: account.id) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .help("默认账号")
            } else {
                Button("设为默认") {
                    appState.setDefaultAccount(id: account.id)
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if account.id != "local" {
                Button(role: .destructive) {
                    appState.removeAccount(id: account.id)
                } label: {
                    Image(systemName: "trash.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("删除账号")
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
