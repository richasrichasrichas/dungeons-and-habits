// SPDX-License-Identifier: MPL-2.0
import SwiftUI

struct MainTabView: View {
    @Environment(GameManager.self) private var gameManager

    private var isAlertPresented: Binding<Bool> {
        Binding(
            get: { gameManager.errorMessage != nil || gameManager.successMessage != nil },
            set: { isPresented in
                if !isPresented {
                    gameManager.clearNotices()
                }
            }
        )
    }

    private var alertTitle: String {
        gameManager.errorMessage == nil ? "Missão concluída" : "Falha na comunicação"
    }

    private var alertText: String {
        gameManager.errorMessage ?? gameManager.successMessage ?? ""
    }

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("Início", systemImage: "house.fill")
            }

            NavigationStack {
                QuestLineView()
            }
            .tabItem {
                Label("Quests", systemImage: "scroll.fill")
            }

            NavigationStack {
                RewardShopView()
            }
            .tabItem {
                Label("Loja", systemImage: "bag.fill")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Configurações", systemImage: "gearshape.fill")
            }
        }
        .tint(AppTheme.accent)
        .task {
            await gameManager.refresh()
        }
        .alert(alertTitle, isPresented: isAlertPresented) {
            Button("OK", role: .cancel) {
                gameManager.clearNotices()
            }
        } message: {
            Text(alertText)
        }
    }
}
