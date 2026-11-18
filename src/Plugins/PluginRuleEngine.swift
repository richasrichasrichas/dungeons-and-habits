// SPDX-License-Identifier: MPL-2.0
import Foundation

/// The runtime seam for declarative plugin logic.
protocol PluginRuleEngine {
    func unlockedQuestIDs(for rules: [PluginRule], context: PluginRuleContext) -> Set<String>
}

/// Interprets the small, allowlisted condition/action tree shipped in schema v1.
struct NativePluginRuleEngine: PluginRuleEngine {
    func unlockedQuestIDs(for rules: [PluginRule], context: PluginRuleContext) -> Set<String> {
        var unlocked = Set<String>()
        for rule in rules where matches(rule.condition, context: context, depth: 1) {
            if case let .unlockQuest(questID) = rule.action {
                unlocked.insert(questID)
            }
        }
        return unlocked
    }

    private func matches(_ condition: PluginCondition, context: PluginRuleContext, depth: Int) -> Bool {
        guard depth <= PluginPackageValidator.maximumRuleDepth else { return false }
        switch condition {
        case let .skillLevelAtLeast(skillID, level):
            return context.skillLevels[skillID, default: 0] >= level
        case let .questCompleted(questID):
            return context.completedQuestIDs.contains(questID)
        case let .all(conditions):
            return !conditions.isEmpty && conditions.allSatisfy {
                matches($0, context: context, depth: depth + 1)
            }
        case let .any(conditions):
            return conditions.contains {
                matches($0, context: context, depth: depth + 1)
            }
        }
    }
}

/*
 Future Wasm extension point:

 A sandboxed implementation can replace or complement PluginRuleEngine once the app has a
 vetted WebAssembly runtime. It must expose only a narrow capability API, deny filesystem
 and network imports, and enforce memory, instruction/fuel, and wall-clock limits. Schema v1
 intentionally carries no Wasm bytes and this project does not execute third-party code.
 */
