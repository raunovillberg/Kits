import Foundation
import Combine

// MARK: - Protocols for Dependency Injection
// These protocols enable testability by allowing mock implementations

// Note: CommandExecutorProtocol is defined in Services/CommandExecutor.swift
// to keep the protocol and its primary implementation together.

public protocol FileManagerProtocol {
    func fileExists(atPath path: String) -> Bool
    func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool
    func isExecutableFile(atPath path: String) -> Bool
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) throws -> [URL]
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any]
    func isDirectory(at url: URL) -> Bool
    func isReadableFile(atPath path: String) -> Bool
}

public struct SettingsSnapshot: Codable, Equatable {
    public var version: Int
    public var rootFolderPath: String?
    public var sortMode: String?
    public var clickAction: String?
    public var customCommand: String?
    public var popoverWidth: Double?
    public var popoverHeight: Double?
    public var uiScale: Double?

    public init(
        version: Int,
        rootFolderPath: String? = nil,
        sortMode: String? = nil,
        clickAction: String? = nil,
        customCommand: String? = nil,
        popoverWidth: Double? = nil,
        popoverHeight: Double? = nil,
        uiScale: Double? = nil
    ) {
        self.version = version
        self.rootFolderPath = rootFolderPath
        self.sortMode = sortMode
        self.clickAction = clickAction
        self.customCommand = customCommand
        self.popoverWidth = popoverWidth
        self.popoverHeight = popoverHeight
        self.uiScale = uiScale
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case rootFolderPath
        case sortMode
        case clickAction
        case customCommand
        case popoverWidth
        case popoverHeight
        case uiScale
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 0
        rootFolderPath = try container.decodeIfPresent(String.self, forKey: .rootFolderPath)
        sortMode = try container.decodeIfPresent(String.self, forKey: .sortMode)
        clickAction = try container.decodeIfPresent(String.self, forKey: .clickAction)
        customCommand = try container.decodeIfPresent(String.self, forKey: .customCommand)
        popoverWidth = try container.decodeIfPresent(Double.self, forKey: .popoverWidth)
        popoverHeight = try container.decodeIfPresent(Double.self, forKey: .popoverHeight)
        uiScale = try container.decodeIfPresent(Double.self, forKey: .uiScale)
    }
}

public protocol SettingsStoreProtocol {
    func load() throws -> SettingsSnapshot?
    func save(_ snapshot: SettingsSnapshot) throws
}

public protocol ShellExecutorProtocol {
    func runProcess(executable: String, arguments: [String], environment: [String: String]?, currentDirectory: String?, timeout: TimeInterval) async throws -> (output: String, status: Int32, stderr: String)
}

// MARK: - Extensions to make system types conform

extension FileManager: FileManagerProtocol {
    public func isDirectory(at url: URL) -> Bool {
        do {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isAliasFileKey, .isMountTriggerKey, .isVolumeKey])
            return values.isDirectory == true && values.isSymbolicLink != true && values.isAliasFile != true && values.isMountTrigger != true && values.isVolume != true
        } catch {
            return false
        }
    }
}
