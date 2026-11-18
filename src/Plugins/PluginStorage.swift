// SPDX-License-Identifier: MPL-2.0
import Foundation

@MainActor
protocol PluginRepository {
    func loadInstalled() throws -> [InstalledPlugin]
    func save(_ plugin: InstalledPlugin) throws
    func remove(pluginID: String) throws
}

/// Persists installed JSON packages in Application Support, never in a shared executable location.
@MainActor
final class FilePluginRepository: PluginRepository {
    private let directoryURL: URL
    private let fileManager: FileManager

    init(directoryURL: URL? = nil, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.directoryURL = directoryURL
            ?? supportDirectory.appendingPathComponent("DungeonsAndHabits/Plugins", isDirectory: true)
        try fileManager.createDirectory(at: self.directoryURL, withIntermediateDirectories: true)
    }

    func loadInstalled() throws -> [InstalledPlugin] {
        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        var installed: [InstalledPlugin] = []

        for url in urls where url.pathExtension == "dnhinstalled" {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let byteCount = (attributes[.size] as? NSNumber)?.intValue ?? 0
            guard byteCount > 0,
                  byteCount <= PluginPackageValidator.maximumPackageBytes + 16_384 else {
                throw PluginValidationError.fileTooLarge
            }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= PluginPackageValidator.maximumPackageBytes + 16_384 else {
                throw PluginValidationError.fileTooLarge
            }
            let record: InstalledPlugin
            do {
                record = try JSONDecoder().decode(InstalledPlugin.self, from: data)
            } catch {
                throw PluginValidationError.malformedJSON
            }
            try PluginPackageValidator.validate(record.package, requireIntegrity: true)
            guard url.deletingPathExtension().lastPathComponent == record.id else {
                throw PluginValidationError.invalidPackage("nome do arquivo local não corresponde ao ID do plugin")
            }
            installed.append(record)
        }

        return installed.sorted { $0.package.metadata.name.localizedCaseInsensitiveCompare($1.package.metadata.name) == .orderedAscending }
    }

    func save(_ plugin: InstalledPlugin) throws {
        try PluginPackageValidator.validate(plugin.package, requireIntegrity: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(plugin)
        guard data.count <= PluginPackageValidator.maximumPackageBytes + 16_384 else {
            throw PluginValidationError.fileTooLarge
        }
        let url = directoryURL.appendingPathComponent(plugin.id).appendingPathExtension("dnhinstalled")
        try data.write(to: url, options: .atomic)
    }

    func remove(pluginID: String) throws {
        // IDs are validated before reaching this repository, so they cannot escape its directory.
        let url = directoryURL.appendingPathComponent(pluginID).appendingPathExtension("dnhinstalled")
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}

/// Integration seam for the app's local domain store. Only validated, declarative content reaches it.
@MainActor
protocol PluginContentRegistry {
    func activate(_ package: PluginPackage) throws
    func deactivate(pluginID: String) throws
    func remove(pluginID: String) throws
}

/// Default MVP registry. Feature repositories can replace this with a persistent implementation.
@MainActor
final class InMemoryPluginContentRegistry: PluginContentRegistry {
    private(set) var activePackages: [String: PluginPackage] = [:]

    func activate(_ package: PluginPackage) throws {
        activePackages[package.id] = package
    }

    func deactivate(pluginID: String) throws {
        activePackages.removeValue(forKey: pluginID)
    }

    func remove(pluginID: String) throws {
        activePackages.removeValue(forKey: pluginID)
    }
}
