// SPDX-License-Identifier: MPL-2.0
import Foundation
import CryptoKit

enum PluginValidationError: LocalizedError {
    case fileTooLarge
    case malformedJSON
    case unsupportedSchema(Int)
    case invalidPackage(String)
    case duplicatePlugin(String)
    case pluginNotFound(String)

    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            return "O pacote excede o tamanho máximo permitido."
        case .malformedJSON:
            return "O arquivo não contém um pacote JSON válido."
        case let .unsupportedSchema(version):
            return "A versão de formato \(version) não é compatível com este app."
        case let .invalidPackage(reason):
            return "Pacote de plugin inválido: \(reason)"
        case let .duplicatePlugin(id):
            return "O plugin \(id) já está instalado. Remova a versão atual antes de importar outra."
        case let .pluginNotFound(id):
            return "O plugin \(id) não está instalado."
        }
    }
}

/// Validates the untrusted package before it is decoded or made available to the app.
enum PluginPackageValidator {
    static let currentSchemaVersion = 1
    static let packageFileExtension = "dnhplugin"
    static let maximumPackageBytes = 1_048_576
    static let maximumJSONDepth = 32
    static let maximumRuleDepth = 12
    static let maximumRuleNodes = 128
    private static let supportedPaletteTokens: Set<String> = [
        "background", "surface", "panel", "text", "accent", "secondary-accent",
        "border", "success", "danger", "muted"
    ]

    static func decode(_ data: Data) throws -> PluginPackage {
        guard !data.isEmpty, data.count <= maximumPackageBytes else {
            throw PluginValidationError.fileTooLarge
        }
        try validateJSONNesting(data)

        let package: PluginPackage
        do {
            package = try JSONDecoder().decode(PluginPackage.self, from: data)
        } catch {
            throw PluginValidationError.malformedJSON
        }
        try validate(package, requireIntegrity: true)
        return package
    }

    static func encode(_ package: PluginPackage) throws -> Data {
        let sealedPackage = try seal(package)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sealedPackage)
        guard data.count <= maximumPackageBytes else {
            throw PluginValidationError.fileTooLarge
        }
        return data
    }

    /// Adds or refreshes the package checksum after validating its declarative payload.
    static func seal(_ package: PluginPackage) throws -> PluginPackage {
        try validateContent(package)
        let payload = PluginPackagePayload(
            metadata: package.metadata,
            content: package.content,
            translations: package.translations,
            rules: package.rules
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let digest = SHA256.hash(data: try encoder.encode(payload))
            .map { String(format: "%02x", $0) }
            .joined()
        let sealed = PluginPackage(
            metadata: package.metadata,
            content: package.content,
            translations: package.translations,
            rules: package.rules,
            integrity: PluginIntegrity(algorithm: "sha256", digest: digest)
        )
        try validate(sealed, requireIntegrity: true)
        return sealed
    }

    static func validate(_ package: PluginPackage, requireIntegrity: Bool = false) throws {
        try validateContent(package)
        guard let integrity = package.integrity else {
            if requireIntegrity { throw invalid("checksum de integridade ausente") }
            return
        }
        guard integrity.algorithm == "sha256",
              integrity.digest.count == 64,
              integrity.digest.allSatisfy({ $0.isHexDigit }) else {
            throw invalid("metadados de checksum inválidos")
        }

        let payload = PluginPackagePayload(
            metadata: package.metadata,
            content: package.content,
            translations: package.translations,
            rules: package.rules
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let expected = SHA256.hash(data: try encoder.encode(payload))
            .map { String(format: "%02x", $0) }
            .joined()
        guard integrity.digest.lowercased() == expected else {
            throw invalid("checksum SHA-256 não confere; o arquivo pode ter sido alterado")
        }
    }

    private static func validateContent(_ package: PluginPackage) throws {
        let metadata = package.metadata
        guard metadata.schemaVersion == currentSchemaVersion else {
            throw PluginValidationError.unsupportedSchema(metadata.schemaVersion)
        }
        try validateIdentifier(metadata.id, field: "ID do plugin")
        try validateText(metadata.name, field: "nome", maximumLength: 80)
        try validateVersion(metadata.version)
        try validateText(metadata.author, field: "autor", maximumLength: 80)
        try validateText(metadata.description, field: "descrição", maximumLength: 500)

        guard !metadata.declaredChanges.isEmpty,
              Set(metadata.declaredChanges).count == metadata.declaredChanges.count else {
            throw invalid("a lista de alterações está vazia ou contém duplicatas")
        }

        let content = package.content
        try enforceCount(content.themes.count, maximum: 10, field: "temas")
        try enforceCount(content.habitPresets.count, maximum: 100, field: "presets de hábitos")
        try enforceCount(content.quests.count, maximum: 100, field: "quests")
        try enforceCount(content.npcs.count, maximum: 100, field: "NPCs")
        try enforceCount(content.rewards.count, maximum: 100, field: "recompensas")
        try enforceCount(package.rules.count, maximum: 100, field: "regras")

        var actualChanges = Set<PluginChangeScope>()
        if !content.themes.isEmpty { actualChanges.insert(.themes) }
        if !content.habitPresets.isEmpty { actualChanges.insert(.habitPresets) }
        if !content.quests.isEmpty { actualChanges.insert(.quests) }
        if !content.npcs.isEmpty { actualChanges.insert(.npcs) }
        if !content.rewards.isEmpty { actualChanges.insert(.rewards) }
        if !package.translations.isEmpty { actualChanges.insert(.translations) }
        if !package.rules.isEmpty { actualChanges.insert(.rules) }
        guard Set(metadata.declaredChanges) == actualChanges else {
            throw invalid("o escopo declarado não corresponde ao conteúdo do pacote")
        }

        try validateUniqueIDs(content.themes.map(\.id), field: "tema")
        try validateUniqueIDs(content.habitPresets.map(\.id), field: "preset")
        try validateUniqueIDs(content.quests.map(\.id), field: "quest")
        try validateUniqueIDs(content.npcs.map(\.id), field: "NPC")
        try validateUniqueIDs(content.rewards.map(\.id), field: "recompensa")
        try validateUniqueIDs(package.rules.map(\.id), field: "regra")

        for theme in content.themes {
            try validateText(theme.name, field: "nome do tema", maximumLength: 80)
            guard !theme.palette.isEmpty, theme.palette.count <= 16 else {
                throw invalid("paleta de tema vazia ou grande demais")
            }
            for (token, color) in theme.palette {
                try validateToken(token, field: "token de cor")
                guard supportedPaletteTokens.contains(token) else {
                    throw invalid("token de cor não suportado: \(token)")
                }
                guard color.range(
                    of: #"^#(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$"#,
                    options: .regularExpression
                ) != nil else {
                    throw invalid("cor de tema inválida; use #RRGGBB ou #RRGGBBAA")
                }
            }
        }

        for habit in content.habitPresets {
            try validateText(habit.name, field: "nome do hábito", maximumLength: 100)
            try validateIdentifier(habit.skillID, field: "ID de skill")
            guard (1...7).contains(habit.targetPerWeek), (0...10_000).contains(habit.xpPerCompletion) else {
                throw invalid("frequência ou XP de hábito fora do limite")
            }
        }

        let questIDs = Set(content.quests.map(\.id))
        for quest in content.quests {
            try validateText(quest.title, field: "título de quest", maximumLength: 120)
            try validateIdentifier(quest.skillID, field: "ID de skill")
            guard (1...3).contains(quest.complexity) else {
                throw invalid("complexidade da quest deve estar entre 1 e 3")
            }
        }

        for npc in content.npcs {
            try validateText(npc.name, field: "nome de NPC", maximumLength: 80)
            try validateText(npc.role, field: "papel de NPC", maximumLength: 80)
            try validateText(npc.introduction, field: "introdução de NPC", maximumLength: 500)
        }

        for reward in content.rewards {
            try validateText(reward.title, field: "título de recompensa", maximumLength: 100)
            try validateText(reward.description, field: "descrição de recompensa", maximumLength: 500)
            guard (0...1_000_000).contains(reward.currencyCost) else {
                throw invalid("custo de recompensa fora do limite")
            }
        }

        try validateTranslations(package.translations)
        var totalRuleNodes = 0
        for rule in package.rules {
            try validateCondition(
                rule.condition,
                depth: 1,
                totalNodes: &totalRuleNodes,
                questIDs: questIDs
            )
            try validateAction(rule.action, questIDs: questIDs)
        }
    }

    private static func validateCondition(
        _ condition: PluginCondition,
        depth: Int,
        totalNodes: inout Int,
        questIDs: Set<String>
    ) throws {
        totalNodes += 1
        guard depth <= maximumRuleDepth, totalNodes <= maximumRuleNodes else {
            throw invalid("árvore de regras excede os limites de profundidade ou tamanho")
        }

        switch condition {
        case let .skillLevelAtLeast(skillID, level):
            try validateIdentifier(skillID, field: "ID de skill na regra")
            guard (1...10_000).contains(level) else {
                throw invalid("nível exigido pela regra fora do limite")
            }
        case let .questCompleted(questID):
            try validateIdentifier(questID, field: "ID de quest na regra")
            guard questIDs.contains(questID) else {
                throw invalid("regra referencia uma quest que não existe no pacote")
            }
        case let .all(children), let .any(children):
            guard (1...10).contains(children.count) else {
                throw invalid("condições all/any devem conter de 1 a 10 itens")
            }
            for child in children {
                try validateCondition(child, depth: depth + 1, totalNodes: &totalNodes, questIDs: questIDs)
            }
        }
    }

    private static func validateAction(_ action: PluginAction, questIDs: Set<String>) throws {
        switch action {
        case let .unlockQuest(questID):
            try validateIdentifier(questID, field: "ID de quest na ação")
            guard questIDs.contains(questID) else {
                throw invalid("ação referencia uma quest que não existe no pacote")
            }
        }
    }

    private static func validateTranslations(_ translations: [String: [String: String]]) throws {
        let supportedLocales: Set<String> = ["pt", "en", "es", "fr", "de"]
        guard translations.count <= supportedLocales.count else {
            throw invalid("há idiomas demais no pacote")
        }
        for (locale, strings) in translations {
            guard supportedLocales.contains(locale), strings.count <= 200 else {
                throw invalid("idioma não suportado ou catálogo de tradução grande demais")
            }
            for (key, value) in strings {
                try validateToken(key, field: "chave de tradução")
                try validateText(value, field: "tradução", maximumLength: 500)
            }
        }
    }

    private static func validateUniqueIDs(_ ids: [String], field: String) throws {
        guard Set(ids).count == ids.count else {
            throw invalid("há IDs duplicados em \(field)")
        }
        for id in ids {
            try validateIdentifier(id, field: "ID de \(field)")
        }
    }

    private static func validateIdentifier(_ value: String, field: String) throws {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._-")
        guard (3...64).contains(value.utf8.count),
              value == value.lowercased(),
              value.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              let first = value.unicodeScalars.first,
              CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789").contains(first) else {
            throw invalid("\(field) deve usar 3–64 caracteres: a-z, 0-9, ponto, hífen ou sublinhado")
        }
    }

    private static func validateToken(_ value: String, field: String) throws {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._-")
        guard (1...128).contains(value.utf8.count),
              value == value.lowercased(),
              value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw invalid("\(field) contém caracteres inválidos")
        }
    }

    private static func validateText(_ value: String, field: String, maximumLength: Int) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              value.count <= maximumLength,
              !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw invalid("\(field) vazio, grande demais ou contém caracteres de controle")
        }
    }

    private static func validateVersion(_ value: String) throws {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0 >= "0" && $0 <= "9" } }) else {
            throw invalid("versão do plugin deve seguir o formato MAJOR.MINOR.PATCH")
        }
    }

    private static func enforceCount(_ count: Int, maximum: Int, field: String) throws {
        guard count <= maximum else { throw invalid("há itens demais em \(field)") }
    }

    private static func invalid(_ reason: String) -> PluginValidationError {
        .invalidPackage(reason)
    }

    /// A cheap iterative preflight prevents deeply nested JSON from reaching Codable's decoder.
    private static func validateJSONNesting(_ data: Data) throws {
        var depth = 0
        var isInsideString = false
        var isEscaped = false

        for byte in data {
            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if byte == 0x5C {
                    isEscaped = true
                } else if byte == 0x22 {
                    isInsideString = false
                }
                continue
            }

            switch byte {
            case 0x22:
                isInsideString = true
            case 0x7B, 0x5B: // { or [
                depth += 1
                guard depth <= maximumJSONDepth else {
                    throw invalid("JSON aninhado profundamente demais")
                }
            case 0x7D, 0x5D: // } or ]
                depth -= 1
                guard depth >= 0 else { throw PluginValidationError.malformedJSON }
            default:
                break
            }
        }

        guard depth == 0, !isInsideString, !isEscaped else {
            throw PluginValidationError.malformedJSON
        }
    }
}

private struct PluginPackagePayload: Codable {
    let metadata: PluginMetadata
    let content: PluginContent
    let translations: [String: [String: String]]
    let rules: [PluginRule]
}
