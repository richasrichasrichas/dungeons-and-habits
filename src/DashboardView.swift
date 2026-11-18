// SPDX-License-Identifier: MPL-2.0
import SwiftUI

struct DashboardView: View {
    @Environment(GameManager.self) private var gameManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let user = gameManager.user {
                    profileHeader(user)
                    xpCard(user)
                    attributesCard(user)
                    axesCard(user)
                    quickQuests
                } else if gameManager.isLoading {
                    ProgressView("Carregando ficha…")
                        .frame(maxWidth: .infinity, minHeight: 280)
                } else if !gameManager.isConfigured {
                    setupPrompt
                } else {
                    ContentUnavailableView(
                        "Sem dados para mostrar",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("Puxe a tela para atualizar ou confira sua conexão.")
                    )
                    .frame(minHeight: 280)
                }
            }
            .padding()
        }
        .background(AppTheme.background)
        .navigationTitle("Aventureiro")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if gameManager.isLoading {
                    ProgressView()
                } else {
                    Button {
                        Task { await gameManager.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Atualizar")
                }
            }
        }
        .refreshable {
            await gameManager.refresh()
        }
    }

    private func profileHeader(_ user: User) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(user.username)
                .font(.largeTitle.bold())
            Text("Nível \(user.level) • \(user.coins) moedas")
                .font(.headline)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func xpCard(_ user: User) -> some View {
        let levelTarget = max(user.level * 100, 1)
        let progress = min(Double(user.xpCurrent), Double(levelTarget))

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Experiência", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Text("\(user.xpCurrent) / \(levelTarget) XP")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(AppTheme.secondaryText)
            }

            ProgressView(value: progress, total: Double(levelTarget))
                .tint(AppTheme.accent)

            Text("\(user.xpTotal) XP acumulados")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding()
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .foregroundStyle(.white)
    }

    private func attributesCard(_ user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Atributos")
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                ForEach(AbilityKey.allCases) { ability in
                    VStack(spacing: 5) {
                        Text(ability.label)
                            .font(.caption2.bold())
                            .foregroundStyle(AppTheme.secondaryText)
                        Text("\(user.attributes[ability])")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func axesCard(_ user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Eixos da vida")
                .font(.headline)
                .foregroundStyle(.white)

            if user.axes.isEmpty {
                Text("A progressão dos eixos aparecerá aqui.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                ForEach(user.axes.sorted { $0.subaxis.label < $1.subaxis.label }) { axis in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(axis.subaxis.label)
                                .foregroundStyle(.white)
                            Text(axis.axis.label)
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                        Text("Nv. \(axis.level) • \(axis.xpCurrent) XP")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private var quickQuests: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Próximas quests")
                .font(.headline)
                .foregroundStyle(.white)

            if gameManager.quests.isEmpty {
                Text("Nenhuma quest pendente.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                ForEach(gameManager.quests.prefix(3)) { quest in
                    HStack(spacing: 10) {
                        Image(systemName: quest.isDaily ? "sun.max.fill" : "scroll")
                            .foregroundStyle(AppTheme.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(quest.title)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("\(quest.difficulty.label) · \(quest.axis.label)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private var setupPrompt: some View {
        ContentUnavailableView(
            "Conecte sua ficha",
            systemImage: "person.crop.circle.badge.plus",
            description: Text("Informe a URL da API e o UUID do usuário na aba Configurações.")
        )
        .foregroundStyle(.white)
        .frame(minHeight: 280)
    }
}
