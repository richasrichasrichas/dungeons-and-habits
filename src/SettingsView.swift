// SPDX-License-Identifier: MPL-2.0
import SwiftUI

struct SettingsView: View {
    @Environment(GameManager.self) private var gameManager
    @AppStorage("dah.apiBaseURL") private var apiURLText = AppConfiguration.defaultAPIURLString
    @AppStorage("dah.userID") private var userIDText = ""

    @State private var localValidationMessage: String?

    var body: some View {
        Form {
            Section("Conexão") {
                TextField("http://192.168.1.10:8080", text: $apiURLText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                Text("No iPhone, localhost aponta para o próprio telefone. Use o endereço IPv4 do Fedora e mantenha os dois aparelhos na mesma rede Wi-Fi.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Ficha do usuário") {
                TextField("UUID retornado por POST /users", text: $userIDText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.footnote.monospaced())

                Text(gameManager.user?.username ?? "Nenhum usuário carregado")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    saveAndConnect()
                } label: {
                    HStack {
                        Spacer()
                        if gameManager.isLoading {
                            ProgressView()
                        } else {
                            Text("Salvar e sincronizar")
                        }
                        Spacer()
                    }
                }
                .disabled(gameManager.isLoading)

                Button("Sincronizar agora") {
                    Task { await gameManager.refresh() }
                }
                .disabled(gameManager.isLoading || !gameManager.isConfigured)
            } footer: {
                Text("O backend atual ainda não tem autenticação. A camada de rede já permite adicionar Authorization: Bearer quando JWT for implementado.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle("Configurações")
        .alert("Configuração inválida", isPresented: Binding(
            get: { localValidationMessage != nil },
            set: { if !$0 { localValidationMessage = nil } }
        )) {
            Button("OK", role: .cancel) { localValidationMessage = nil }
        } message: {
            Text(localValidationMessage ?? "")
        }
    }

    private func saveAndConnect() {
        let trimmedURL = apiURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil
        else {
            localValidationMessage = "Informe uma URL válida, como http://192.168.1.10:8080."
            return
        }

        UserDefaults.standard.set(trimmedURL, forKey: AppConfiguration.apiURLDefaultsKey)
        guard gameManager.configureUserID(userIDText) else { return }
        Task { await gameManager.refresh() }
    }
}
