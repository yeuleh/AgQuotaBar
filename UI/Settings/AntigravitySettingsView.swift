import SwiftUI

struct AntigravitySettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var newAccountEmail = ""

    var body: some View {
        Form {
            Section("Add Account") {
                HStack {
                    TextField("Email", text: $newAccountEmail)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        appState.addAccount(email: newAccountEmail)
                        newAccountEmail = ""
                    }
                    .disabled(newAccountEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if appState.accounts.isEmpty {
                Text("No accounts configured")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.accounts) { account in
                    Section {
                        if account.models.isEmpty {
                            Text("No models available")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(account.models) { model in
                                Toggle(model.name, isOn: appState.modelVisibilityBinding(accountId: account.id, modelId: model.id))
                            }
                        }
                    } header: {
                        HStack {
                            Text(account.email)
                                .font(.headline)
                            
                            Spacer()
                            
                            if appState.isDefaultAccount(id: account.id) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .help("Default Account")
                            } else {
                                Button("Make Default") {
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
                                .help("Remove Account")
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
    }
}
