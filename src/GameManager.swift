// SPDX-License-Identifier: MPL-2.0
import Foundation
import Observation

/// ViewModel global: concentra carregamento, operações e estados apresentados pela UI.
@MainActor
@Observable
final class GameManager {
    private(set) var user: User?
    private(set) var quests: [Quest] = []
    private(set) var rewards: [Reward] = []
    private(set) var isLoading = false
    private(set) var loadingQuestIDs: Set<UUID> = []
    private(set) var loadingRewardIDs: Set<UUID> = []
    private(set) var errorMessage: String?
    private(set) var successMessage: String?
    private(set) var userID: UUID?

    @ObservationIgnored private let repository: any GameRepository

    var isConfigured: Bool { userID != nil }

    init(repository: any GameRepository, userID: UUID? = AppConfiguration.currentUserID) {
        self.repository = repository
        self.userID = userID
    }

    /// Carrega ficha, quests pendentes e recompensas em paralelo.
    func refresh() async {
        guard let userID else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let fetchedUser = repository.fetchUserSheet(userID: userID)
            async let fetchedQuests = repository.fetchPendingQuests(userID: userID)
            async let fetchedRewards = repository.fetchRewards(userID: userID)
            let (loadedUser, loadedQuests, loadedRewards) =
                try await (fetchedUser, fetchedQuests, fetchedRewards)

            user = loadedUser
            quests = loadedQuests
            rewards = loadedRewards
        } catch is CancellationError {
            // Cancelamento da tela não deve aparecer como erro para o usuário.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func configureUserID(_ value: String) -> Bool {
        guard let parsedID = UUID(uuidString: value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "Informe um UUID válido. Você pode obter o ID ao criar o usuário pela API."
            return false
        }

        userID = parsedID
        UserDefaults.standard.set(parsedID.uuidString, forKey: AppConfiguration.userIDDefaultsKey)
        errorMessage = nil
        return true
    }

    func completeQuest(_ quest: Quest) async {
        guard loadingQuestIDs.insert(quest.id).inserted else { return }
        errorMessage = nil
        successMessage = nil
        defer { loadingQuestIDs.remove(quest.id) }

        do {
            let result = try await repository.completeQuest(id: quest.id)
            quests.removeAll { $0.id == result.questID }

            if var currentUser = user {
                currentUser.xpCurrent = result.xpCurrent
                currentUser.xpTotal = result.xpTotal
                currentUser.level = result.level
                currentUser.coins = result.coins
                currentUser.attributes = result.attributes
                currentUser.axes.removeAll { $0.id == result.axisProgress.id }
                currentUser.axes.append(result.axisProgress)
                user = currentUser
            }

            successMessage = "+\(result.xpReward) XP e +\(result.coinsReward) moedas"
        } catch is CancellationError {
            // Mantém a quest pendente; a pessoa pode tentar novamente.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func buyReward(_ reward: Reward) async {
        guard let userID, loadingRewardIDs.insert(reward.id).inserted else { return }
        errorMessage = nil
        successMessage = nil
        defer { loadingRewardIDs.remove(reward.id) }

        do {
            let result = try await repository.buyReward(id: reward.id, userID: userID)
            if var currentUser = user {
                currentUser.coins = result.remainingCoins
                user = currentUser
            }
            successMessage = "\(reward.title) comprado."
        } catch is CancellationError {
            // A operação pode ser repetida após o cancelamento.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearNotices() {
        errorMessage = nil
        successMessage = nil
    }
}
