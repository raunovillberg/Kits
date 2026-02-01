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

public protocol UserDefaultsProtocol {
    func string(forKey defaultName: String) -> String?
    func set(_ value: Any?, forKey defaultName: String)
    func integer(forKey defaultName: String) -> Int
    func double(forKey defaultName: String) -> Double
    func object(forKey defaultName: String) -> Any?
    func removeObject(forKey defaultName: String)
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
extension UserDefaults: UserDefaultsProtocol {}