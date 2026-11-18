// SPDX-License-Identifier: MPL-2.0
import Foundation

/// The package format is declarative JSON. It never contains executable code.
struct PluginPackage: Codable, Equatable, Identifiable {
    let metadata: PluginMetadata
    let content: PluginContent
    let translations: [String: [String: String]]
    let rules: [PluginRule]
    /// SHA-256 over the sorted-key JSON encoding of the four payload fields above.
    /// It detects accidental changes; it does not prove who authored the package.
    let integrity: PluginIntegrity?

    var id: String { metadata.id }
}

struct PluginIntegrity: Codable, Equatable {
    let algorithm: String
    let digest: String
}

struct PluginMetadata: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let schemaVersion: Int
    let version: String
    let author: String
    let description: String
    let declaredChanges: [PluginChangeScope]
}

enum PluginChangeScope: String, Codable, CaseIterable, Equatable, Hashable, Identifiable {
    case themes
    case habitPresets
    case quests
    case npcs
    case rewards
    case translations
    case rules

    var id: Self { self }
}

struct PluginContent: Codable, Equatable {
    let themes: [PluginTheme]
    let habitPresets: [PluginHabitPreset]
    let quests: [PluginQuest]
    let npcs: [PluginNPC]
    let rewards: [PluginReward]

    func itemCount(for scope: PluginChangeScope) -> Int {
        switch scope {
        case .themes: return themes.count
        case .habitPresets: return habitPresets.count
        case .quests: return quests.count
        case .npcs: return npcs.count
        case .rewards: return rewards.count
        case .translations, .rules: return 0
        }
    }
}

struct PluginTheme: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    /// Named color tokens mapped to #RRGGBB or #RRGGBBAA values.
    let palette: [String: String]
    let font: PluginFontToken
}

enum PluginFontToken: String, Codable, CaseIterable, Equatable {
    case system
    case pixel
    case medieval
}

struct PluginHabitPreset: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let skillID: String
    let targetPerWeek: Int
    let xpPerCompletion: Int
}

struct PluginQuest: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let skillID: String
    /// MVP range: 1 (simple) through 3 (complex).
    let complexity: Int
    let kind: PluginQuestKind
}

enum PluginQuestKind: String, Codable, CaseIterable, Equatable {
    case monsterHunt
    case questline
}

struct PluginNPC: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let role: String
    let introduction: String
}

struct PluginReward: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let description: String
    let currencyCost: Int
    let kind: PluginRewardKind
}

enum PluginRewardKind: String, Codable, CaseIterable, Equatable {
    case equipment
    case rest
    case consumable
    case collectible
}

struct PluginRule: Codable, Equatable, Identifiable {
    let id: String
    let condition: PluginCondition
    let action: PluginAction
}

/// Allowlisted condition nodes interpreted by the app's native rule engine.
indirect enum PluginCondition: Codable, Equatable {
    case skillLevelAtLeast(skillID: String, level: Int)
    case questCompleted(questID: String)
    case all([PluginCondition])
    case any([PluginCondition])

    private enum CodingKeys: String, CodingKey {
        case type
        case skillID
        case level
        case questID
        case conditions
    }

    private enum ConditionType: String, Codable {
        case skillLevelAtLeast
        case questCompleted
        case all
        case any
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(ConditionType.self, forKey: .type) {
        case .skillLevelAtLeast:
            self = .skillLevelAtLeast(
                skillID: try container.decode(String.self, forKey: .skillID),
                level: try container.decode(Int.self, forKey: .level)
            )
        case .questCompleted:
            self = .questCompleted(questID: try container.decode(String.self, forKey: .questID))
        case .all:
            self = .all(try container.decode([PluginCondition].self, forKey: .conditions))
        case .any:
            self = .any(try container.decode([PluginCondition].self, forKey: .conditions))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .skillLevelAtLeast(skillID, level):
            try container.encode(ConditionType.skillLevelAtLeast, forKey: .type)
            try container.encode(skillID, forKey: .skillID)
            try container.encode(level, forKey: .level)
        case let .questCompleted(questID):
            try container.encode(ConditionType.questCompleted, forKey: .type)
            try container.encode(questID, forKey: .questID)
        case let .all(conditions):
            try container.encode(ConditionType.all, forKey: .type)
            try container.encode(conditions, forKey: .conditions)
        case let .any(conditions):
            try container.encode(ConditionType.any, forKey: .type)
            try container.encode(conditions, forKey: .conditions)
        }
    }
}

/// MVP actions can unlock content only; packages cannot award XP or currency.
enum PluginAction: Codable, Equatable {
    case unlockQuest(questID: String)

    private enum CodingKeys: String, CodingKey {
        case type
        case questID
    }

    private enum ActionType: String, Codable {
        case unlockQuest
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(ActionType.self, forKey: .type) {
        case .unlockQuest:
            self = .unlockQuest(questID: try container.decode(String.self, forKey: .questID))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .unlockQuest(questID):
            try container.encode(ActionType.unlockQuest, forKey: .type)
            try container.encode(questID, forKey: .questID)
        }
    }
}

struct PluginRuleContext {
    let skillLevels: [String: Int]
    let completedQuestIDs: Set<String>
}

struct PluginImportPreview: Equatable, Identifiable {
    let pluginID: String
    let name: String
    let version: String
    let author: String
    let declaredChanges: [PluginChangeScope]
    let itemCounts: [PluginChangeCount]

    var id: String { pluginID }
}

struct PluginChangeCount: Equatable, Identifiable {
    let scope: PluginChangeScope
    let count: Int

    var id: PluginChangeScope { scope }
}

struct InstalledPlugin: Codable, Equatable, Identifiable {
    let package: PluginPackage
    var isEnabled: Bool

    var id: String { package.id }
}
