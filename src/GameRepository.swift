// SPDX-License-Identifier: MPL-2.0
import Foundation

/// Porta da camada de domínio para as operações remotas necessárias ao app.
protocol GameRepository: Sendable {
    func fetchUserSheet(userID: UUID) async throws -> User
    func fetchPendingQuests(userID: UUID) async throws -> [Quest]
    func completeQuest(id: UUID) async throws -> QuestCompletion
    func fetchRewards(userID: UUID) async throws -> [Reward]
    func buyReward(id: UUID, userID: UUID) async throws -> RewardPurchase
}

/// Implementação remota. Pode ser substituída por um repositório em memória
/// em previews sem alterar as Views ou a lógica do GameManager.
struct RemoteGameRepository: GameRepository {
    let api: APIService

    func fetchUserSheet(userID: UUID) async throws -> User {
        try await api.fetchUserSheet(userID: userID)
    }

    func fetchPendingQuests(userID: UUID) async throws -> [Quest] {
        try await api.fetchPendingQuests(userID: userID)
    }

    func completeQuest(id: UUID) async throws -> QuestCompletion {
        try await api.completeQuest(id: id)
    }

    func fetchRewards(userID: UUID) async throws -> [Reward] {
        try await api.fetchRewards(userID: userID)
    }

    func buyReward(id: UUID, userID: UUID) async throws -> RewardPurchase {
        try await api.buyReward(id: id, userID: userID)
    }
}
