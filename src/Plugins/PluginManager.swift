// SPDX-License-Identifier: MPL-2.0
import Foundation
import Observation

/// Coordinates preview, validation, installation, activation, export, and removal of plugins.
/// `.dnhplugin` files are plain UTF-8 JSON in schema v1; compressed archives are not accepted.
@MainActor
@Observable
final class PluginManager {
    private(set) var installedPlugins: [InstalledPlugin] = []
    private(set) var pendingImportPreview: PluginImportPreview?
    private(set) var errorMessage: String?

    @ObservationIgnored private let repository: PluginRepository
    @ObservationIgnored private let contentRegistry: PluginContentRegistry
    @ObservationIgnored private let ruleEngine: PluginRuleEngine
    @ObservationIgnored private var pendingPackage: PluginPackage?

    var activePackages: [PluginPackage] {
        installedPlugins.filter(\.isEnabled).map(\.package)
    }

    convenience init() throws {
        try self.init(
            repository: FilePluginRepository(),
            contentRegistry: InMemoryPluginContentRegistry(),
            ruleEngine: NativePluginRuleEngine()
        )
    }

    init(
        repository: PluginRepository,
        contentRegistry: PluginContentRegistry,
        ruleEngine: PluginRuleEngine = NativePluginRuleEngine()
    ) throws {
        self.repository = repository
        self.contentRegistry = contentRegistry
        self.ruleEngine = ruleEngine

        let restored = try repository.loadInstalled()
        var seenIDs = Set<String>()
        for record in restored {
            try PluginPackageValidator.validate(record.package, requireIntegrity: true)
            guard seenIDs.insert(record.id).inserted else {
                throw PluginValidationError.invalidPackage("há plugins instalados com o mesmo ID")
            }
            if record.isEnabled {
                try contentRegistry.activate(record.package)
            }
        }
        installedPlugins = restored
    }

    /// Reads a file selected through the system file picker and prepares a confirmation preview.
    func prepareImport(from url: URL) {
        errorMessage = nil
        pendingImportPreview = nil
        pendingPackage = nil

        let accessedSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            guard url.pathExtension.lowercased() == PluginPackageValidator.packageFileExtension else {
                throw PluginValidationError.invalidPackage("a extensão esperada é .dnhplugin")
            }
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let byteCount = (attributes[.size] as? NSNumber)?.intValue ?? 0
            guard byteCount > 0, byteCount <= PluginPackageValidator.maximumPackageBytes else {
                throw PluginValidationError.fileTooLarge
            }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            _ = try prepareImport(data: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Decodes and validates the package, but does not install or apply its content.
    @discardableResult
    func prepareImport(data: Data) throws -> PluginImportPreview {
        pendingImportPreview = nil
        pendingPackage = nil
        let package = try PluginPackageValidator.decode(data)
        guard !installedPlugins.contains(where: { $0.id == package.id }) else {
            throw PluginValidationError.duplicatePlugin(package.id)
        }

        let preview = PluginImportPreview(
            pluginID: package.id,
            name: package.metadata.name,
            version: package.metadata.version,
            author: package.metadata.author,
            declaredChanges: package.metadata.declaredChanges,
            itemCounts: package.metadata.declaredChanges.map { scope in
                let count: Int
                switch scope {
                case .themes: count = package.content.themes.count
                case .habitPresets: count = package.content.habitPresets.count
                case .quests: count = package.content.quests.count
                case .npcs: count = package.content.npcs.count
                case .rewards: count = package.content.rewards.count
                case .translations: count = package.translations.values.reduce(0) { $0 + $1.count }
                case .rules: count = package.rules.count
                }
                return PluginChangeCount(scope: scope, count: count)
            }
        )
        pendingPackage = package
        pendingImportPreview = preview
        errorMessage = nil
        return preview
    }

    /// Applies the staged package only after the UI explicitly confirms the preview.
    func confirmImport() {
        guard let package = pendingPackage,
              pendingImportPreview?.pluginID == package.id else {
            errorMessage = "Não há plugin aguardando confirmação."
            return
        }

        let record = InstalledPlugin(package: package, isEnabled: true)
        do {
            try repository.save(record)
            do {
                try contentRegistry.activate(package)
            } catch {
                try? contentRegistry.deactivate(pluginID: package.id)
                try? repository.remove(pluginID: package.id)
                throw error
            }
            installedPlugins.append(record)
            installedPlugins.sort {
                $0.package.metadata.name.localizedCaseInsensitiveCompare($1.package.metadata.name) == .orderedAscending
            }
            cancelImport()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelImport() {
        pendingPackage = nil
        pendingImportPreview = nil
    }

    func setEnabled(_ enabled: Bool, for pluginID: String) {
        guard let index = installedPlugins.firstIndex(where: { $0.id == pluginID }) else {
            errorMessage = PluginValidationError.pluginNotFound(pluginID).localizedDescription
            return
        }
        let oldRecord = installedPlugins[index]
        guard oldRecord.isEnabled != enabled else { return }
        let updated = InstalledPlugin(package: oldRecord.package, isEnabled: enabled)

        do {
            if enabled {
                try contentRegistry.activate(oldRecord.package)
            } else {
                try contentRegistry.deactivate(pluginID: pluginID)
            }
            do {
                try repository.save(updated)
            } catch {
                if oldRecord.isEnabled {
                    try? contentRegistry.activate(oldRecord.package)
                } else {
                    try? contentRegistry.deactivate(pluginID: pluginID)
                }
                throw error
            }
            installedPlugins[index] = updated
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(pluginID: String) {
        guard let index = installedPlugins.firstIndex(where: { $0.id == pluginID }) else {
            errorMessage = PluginValidationError.pluginNotFound(pluginID).localizedDescription
            return
        }
        let record = installedPlugins[index]

        do {
            try contentRegistry.remove(pluginID: pluginID)
            do {
                try repository.remove(pluginID: pluginID)
            } catch {
                if record.isEnabled {
                    try? contentRegistry.activate(record.package)
                }
                throw error
            }
            installedPlugins.remove(at: index)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Returns the original declarative package data for SwiftUI's fileExporter or share sheet.
    func exportData(for pluginID: String) throws -> Data {
        guard let record = installedPlugins.first(where: { $0.id == pluginID }) else {
            throw PluginValidationError.pluginNotFound(pluginID)
        }
        return try PluginPackageValidator.encode(record.package)
    }

    /// Convenience for callers that already have a destination URL from a document picker.
    func export(pluginID: String, to destinationURL: URL) throws {
        let data = try exportData(for: pluginID)
        try data.write(to: destinationURL, options: .atomic)
    }

    /// Evaluates only active plugins and returns quests their native declarative rules unlock.
    func unlockedQuestIDs(for context: PluginRuleContext) -> Set<String> {
        let rules = activePackages.flatMap(\.rules)
        return ruleEngine.unlockedQuestIDs(for: rules, context: context)
    }
}
