// SPDX-License-Identifier: MPL-2.0
import Foundation

enum UserRole: String, Codable, Hashable {
    case user
    case admin
}

enum AbilityKey: String, Codable, CaseIterable, Hashable, Identifiable {
    case str, dex, con, int, wis, cha
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}

struct AbilityScores: Codable, Hashable {
    var str: Int
    var dex: Int
    var con: Int
    var int: Int
    var wis: Int
    var cha: Int

    subscript(_ ability: AbilityKey) -> Int {
        get {
            switch ability {
            case .str: return str
            case .dex: return dex
            case .con: return con
            case .int: return int
            case .wis: return wis
            case .cha: return cha
            }
        }
        set {
            switch ability {
            case .str: str = newValue
            case .dex: dex = newValue
            case .con: con = newValue
            case .int: int = newValue
            case .wis: wis = newValue
            case .cha: cha = newValue
            }
        }
    }
}

enum Difficulty: String, Codable, CaseIterable, Hashable, Identifiable {
    case easy, medium, hard, epic
    var id: String { rawValue }
    var label: String {
        switch self {
        case .easy: return "Fácil"
        case .medium: return "Média"
        case .hard: return "Difícil"
        case .epic: return "Épica"
        }
    }
}

enum QuestKind: String, Codable, Hashable {
    case monsterHunt = "monster_hunt"
    case questline
    var label: String {
        switch self {
        case .monsterHunt: return "Caça a monstro"
        case .questline: return "Linha de missão"
        }
    }
}

enum LifeAxis: String, Codable, Hashable {
    case financeiro, saude, paixoes
    var label: String {
        switch self {
        case .financeiro: return "Financeiro"
        case .saude: return "Saúde"
        case .paixoes: return "Paixões"
        }
    }
}

enum LifeSubaxis: String, Codable, Hashable {
    case trabalho, estudos, metas, fisica, mental, espiritual, materiais, criativas, lazer
    var label: String {
        switch self {
        case .trabalho: return "Trabalho"
        case .estudos: return "Estudos"
        case .metas: return "Metas"
        case .fisica: return "Física"
        case .mental: return "Mental"
        case .espiritual: return "Espiritual"
        case .materiais: return "Materiais"
        case .criativas: return "Criativas"
        case .lazer: return "Lazer"
        }
    }
}

enum RewardKind: String, Codable, Hashable {
    case equipamento, descanso, consumivel, colecionavel
    var label: String {
        switch self {
        case .equipamento: return "Equipamento"
        case .descanso: return "Descanso"
        case .consumivel: return "Consumível"
        case .colecionavel: return "Colecionável"
        }
    }
}

struct AxisProgress: Codable, Hashable, Identifiable {
    let axis: LifeAxis
    let subaxis: LifeSubaxis
    var level: Int
    var xpCurrent: Int
    var xpTotal: Int
    var id: String { "\(axis.rawValue)-\(subaxis.rawValue)" }

    enum CodingKeys: String, CodingKey {
        case axis = "eixo"
        case subaxis = "subeixo"
        case level
        case xpCurrent = "xp_atual"
        case xpTotal = "xp_total"
    }
}

/// O endpoint /user/:id/sheet devolve a ficha e os eixos no mesmo objeto JSON.
struct User: Codable, Hashable, Identifiable {
    let id: UUID
    var username: String
    var xpCurrent: Int
    var xpTotal: Int
    var level: Int
    var coins: Int
    var role: UserRole
    var attributes: AbilityScores
    var axes: [AxisProgress]

    enum CodingKeys: String, CodingKey {
        case id, username, level, role
        case xpCurrent = "xp_atual"
        case xpTotal = "xp_total"
        case coins = "moedas"
        case attributes = "atributos_5e"
        case axes = "eixos"
    }

    init(
        id: UUID, username: String, xpCurrent: Int, xpTotal: Int,
        level: Int, coins: Int, role: UserRole, attributes: AbilityScores,
        axes: [AxisProgress] = []
    ) {
        self.id = id
        self.username = username
        self.xpCurrent = xpCurrent
        self.xpTotal = xpTotal
        self.level = level
        self.coins = coins
        self.role = role
        self.attributes = attributes
        self.axes = axes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            username: try container.decode(String.self, forKey: .username),
            xpCurrent: try container.decode(Int.self, forKey: .xpCurrent),
            xpTotal: try container.decode(Int.self, forKey: .xpTotal),
            level: try container.decode(Int.self, forKey: .level),
            coins: try container.decode(Int.self, forKey: .coins),
            role: try container.decodeIfPresent(UserRole.self, forKey: .role) ?? .user,
            attributes: try container.decode(AbilityScores.self, forKey: .attributes),
            axes: try container.decodeIfPresent([AxisProgress].self, forKey: .axes) ?? []
        )
    }
}

struct Quest: Codable, Hashable, Identifiable {
    let id: UUID
    let userID: UUID
    var title: String
    var description: String
    let difficulty: Difficulty
    var status: String
    let kind: QuestKind
    let axis: LifeAxis
    let subaxis: LifeSubaxis
    let ability: AbilityKey
    var isDaily: Bool
    var dueAt: Date?
    var createdAt: Date?
    var completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, status
        case userID = "user_id"
        case title = "titulo"
        case description = "descricao"
        case difficulty = "dificuldade"
        case kind = "tipo"
        case axis = "eixo_categoria"
        case subaxis = "subeixo"
        case ability = "atributo"
        case isDaily = "is_daily"
        case dueAt = "due_at"
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }
}

struct Reward: Codable, Hashable, Identifiable {
    let id: UUID
    let userID: UUID
    var title: String
    var description: String
    var cost: Int
    let kind: RewardKind
    var statKey: AbilityKey?
    var statBonus: Int
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case title = "titulo"
        case description = "descricao"
        case cost = "custo_moedas"
        case kind = "tipo"
        case statKey = "stat_key"
        case statBonus = "stat_bonus"
        case createdAt = "created_at"
    }
}

struct QuestCompletion: Codable, Hashable {
    let questID: UUID
    let xpReward: Int
    let coinsReward: Int
    let xpCurrent: Int
    let xpTotal: Int
    let coins: Int
    let level: Int
    let attributes: AbilityScores
    let axisProgress: AxisProgress

    enum CodingKeys: String, CodingKey {
        case questID = "quest_id"
        case xpReward = "xp_ganho"
        case coinsReward = "moedas_ganhas"
        case xpCurrent = "xp_atual"
        case xpTotal = "xp_total"
        case coins = "moedas"
        case level
        case attributes = "atributos_5e"
        case axisProgress = "progresso_eixo"
    }
}

struct RewardPurchase: Codable, Hashable {
    let rewardID: UUID
    let remainingCoins: Int
    let quantity: Int
    let statKey: String?
    let statBonusApplied: Int

    enum CodingKeys: String, CodingKey {
        case rewardID = "reward_id"
        case remainingCoins = "moedas_restantes"
        case quantity = "quantidade_no_inventario"
        case statKey = "stat_key"
        case statBonusApplied = "stat_bonus_aplicado"
    }
}
