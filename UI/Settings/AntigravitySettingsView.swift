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
        .padding(20)
    }
    
    private var quotaModeSection: some View {
        Section("配额获取方式") {
            Picker("模式", selection: $appState.quotaMode) {
                ForEach(QuotaMode.allCases) { mode in
                    VStack(alignment: .leading) {
                        Text(mode.displayName)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            
            Text(appState.quotaMode.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var remoteAccountSection: some View {
        Section("Google 账号") {
            if appState.oauthService.isAuthenticated {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("已登录")
                                .fontWeight(.medium)
                        }
                        
                        if let email = appState.remoteUserEmail {
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let tier = appState.remoteTier {
                            Text("账号级别: \(tier)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button("登出") {
                        appState.logout()
                    }
                    .foregroundStyle(.red)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .foregroundStyle(.orange)
                        Text(appState.oauthService.authState.displayText)
                    }
                    
                    Text("登录 Google 账号以获取配额信息。远程模式不依赖本地 Antigravity 环境。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        isLoggingIn = true
                        Task {
                            _ = await appState.login()
                            isLoggingIn = false
                        }
                    } label: {
                        HStack {
                            if isLoggingIn {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 16, height: 16)
                            }
                            Text(isLoggingIn ? "登录中..." : "使用 Google 账号登录")
                        }
                    }
                    .disabled(isLoggingIn)
                }
            }
            
            if appState.oauthService.isAuthenticated && appState.remoteModels.isEmpty == false {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("模型配额")
                        .font(.headline)
                    
                    ForEach(appState.remoteModels) { model in
                        HStack {
                            Circle()
                                .fill(quotaColor(for: model.remainingPercentage))
                                .frame(width: 8, height: 8)
                            
                            Text(model.displayName)
                            
                            Spacer()
                            
                            Text("\(model.remainingPercentage)%")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }
    
    private var localAccountSection: some View {
        Section("添加账号") {
            HStack {
                TextField("Email", text: $newAccountEmail)
                    .textFieldStyle(.roundedBorder)
                Button("添加") {
                    appState.addAccount(email: newAccountEmail)
                    newAccountEmail = ""
                }
                .disabled(newAccountEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
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
        Section("显示的模型 (最多7个)") {
            if appState.remoteModels.isEmpty {
                Text("暂无模型")
                    .foregroundStyle(.secondary)
            } else {
                let visibleCount = appState.visibleRemoteModelCount
                
                ForEach(appState.remoteModels) { model in
                    let isVisible = appState.isRemoteModelVisible(modelId: model.id)
                    let canToggleOn = visibleCount < 7 || isVisible
                    
                    Toggle(isOn: appState.remoteModelVisibilityBinding(modelId: model.id)) {
                        HStack {
                            Text(model.displayName)
                            Spacer()
                            Text("\(model.remainingPercentage)%")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .disabled(!canToggleOn && !isVisible)
                }
                
                if visibleCount >= 7 {
                    Text("已达到最大显示数量")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
    
    private var localModelVisibilitySection: some View {
        Group {
            if appState.accounts.isEmpty {
                Section {
                    Text("暂无账号")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(appState.accounts) { account in
                    Section {
                        if account.models.isEmpty {
                            Text("暂无模型")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(account.models) { model in
                                Toggle(model.name, isOn: appState.modelVisibilityBinding(accountId: account.id, modelId: model.id))
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
        HStack {
            Text(account.email)
                .font(.headline)
            
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
            }

            if account.id != "local" {
                Button(role: .destructive) {
                    appState.removeAccount(id: account.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
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
