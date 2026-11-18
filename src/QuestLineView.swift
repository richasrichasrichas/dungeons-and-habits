// SPDX-License-Identifier: MPL-2.0
import SwiftUI

struct QuestLineView: View {
    @Environment(GameManager.self) private var gameManager

    var body: some View {
        Group {
            if gameManager.isLoading && gameManager.quests.isEmpty {
                ProgressView("Carregando quests…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if gameManager.quests.isEmpty {
                ContentUnavailableView(
                    "Nenhuma quest pendente",
                    systemImage: "scroll",
                    description: Text("Quando houver quests para este usuário, elas aparecerão aqui.")
                )
            } else {
                List(gameManager.quests) { quest in
                    questRow(quest)
                        .listRowBackground(AppTheme.surface)
                }
                .scrollContentBackground(.hidden)
                .refreshable {
                    await gameManager.refresh()
                }
            }
        }
        .background(AppTheme.background)
        .navigationTitle("Quests")
        .toolbar {
            if gameManager.isLoading {
                ToolbarItem(placement: .topBarTrailing) {
                    ProgressView()
                }
            }
        }
    }

    private func questRow(_ quest: Quest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(quest.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(quest.description)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                    Text("\(quest.kind.label) · \(quest.difficulty.label)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.accent)
                }
                Spacer(minLength: 8)
                if quest.isDaily {
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Quest diária")
                }
            }

            HStack {
                Text("\(quest.axis.label) · \(quest.subaxis.label) · \(quest.ability.label)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
                Button {
                    Task { await gameManager.completeQuest(quest) }
                } label: {
                    if gameManager.loadingQuestIDs.contains(quest.id) {
                        ProgressView()
                            .tint(AppTheme.background)
                    } else {
                        Label("Concluir", systemImage: "checkmark")
                    }
                }
                .font(.caption.bold())
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .disabled(gameManager.loadingQuestIDs.contains(quest.id))
            }
        }
        .padding(.vertical, 7)
    }
}
