// SPDX-License-Identifier: MPL-2.0
import SwiftUI

struct RewardShopView: View {
    @Environment(GameManager.self) private var gameManager

    var body: some View {
        Group {
            if gameManager.isLoading && gameManager.rewards.isEmpty {
                ProgressView("Carregando loja…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if gameManager.rewards.isEmpty {
                ContentUnavailableView(
                    "Loja vazia",
                    systemImage: "bag",
                    description: Text("Cadastre recompensas para que elas apareçam aqui.")
                )
            } else {
                List(gameManager.rewards) { reward in
                    rewardRow(reward)
                        .listRowBackground(AppTheme.surface)
                }
                .scrollContentBackground(.hidden)
                .refreshable {
                    await gameManager.refresh()
                }
            }
        }
        .background(AppTheme.background)
        .navigationTitle("Loja")
        .toolbar {
            if gameManager.isLoading {
                ToolbarItem(placement: .topBarTrailing) {
                    ProgressView()
                }
            } else if let user = gameManager.user {
                ToolbarItem(placement: .topBarTrailing) {
                    Label("\(user.coins)", systemImage: "circle.hexagongrid.fill")
                        .font(.subheadline.bold())
                }
            }
        }
    }

    private func rewardRow(_ reward: Reward) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(reward.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(reward.description)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(reward.kind.label)
                        .font(.caption)
                        .foregroundStyle(AppTheme.accent)
                }
                Spacer(minLength: 8)
                if let statKey = reward.statKey, reward.statBonus > 0 {
                    Text("+\(reward.statBonus) \(statKey.label)")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.accent)
                }
            }

            HStack {
                Label("\(reward.cost) moedas", systemImage: "circle.hexagongrid.fill")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
                Button {
                    Task { await gameManager.buyReward(reward) }
                } label: {
                    if gameManager.loadingRewardIDs.contains(reward.id) {
                        ProgressView()
                            .tint(AppTheme.background)
                    } else {
                        Label("Comprar", systemImage: "cart")
                    }
                }
                .font(.caption.bold())
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .disabled(
                    gameManager.loadingRewardIDs.contains(reward.id)
                        || (gameManager.user?.coins ?? 0) < reward.cost
                )
            }

            if (gameManager.user?.coins ?? 0) < reward.cost {
                Text("Saldo insuficiente")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 7)
    }
}
