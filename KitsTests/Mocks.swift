import Foundation
import Kits

public class MockFileManager: FileManagerProtocol {
    public var files: [String: Bool] = [:]
    public var directories: [String: [URL]] = [:]
    public var attributes: [String: [FileAttributeKey: Any]] = [:]
    public var executableFiles: Set<String> = []
    
    public init() {}
    
    public func fileExists(atPath path: String) -> Bool {
        return files[path] ?? false
    }
    
    public func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        if let isDir = files[path] {
            isDirectory?.pointee = ObjCBool(isDir)
            return true
        }
        return false
    }
    
    public func isExecutableFile(atPath path: String) -> Bool {
        return executableFiles.contains(path)
    }
    
    public func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) throws -> [URL] {
        return directories[url.path] ?? []
    }
    
    public func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        return attributes[path] ?? [:]
    }
    
    public func isDirectory(at url: URL) -> Bool {
        return files[url.path] ?? false
    }
    
    public func isReadableFile(atPath path: String) -> Bool {
        return files[path] ?? false
    }
}

public class MockShellExecutor: ShellExecutorProtocol {
    public typealias Handler = (String, [String]) -> (output: String, status: Int32, stderr: String)
    public var handlers: [String: Handler] = [:]
    public var lastCommands: [(executable: String, args: [String])] = []
    
    public init() {}
    
    public func runProcess(executable: String, arguments: [String], environment: [String: String]?, currentDirectory: String?, timeout: TimeInterval) async throws -> (output: String, status: Int32, stderr: String) {
        lastCommands.append((executable, arguments))
        
        let key = executable
        if let handler = handlers[key] {
            return handler(executable, arguments)
        }
        
        // Default: success with empty output
        return ("", 0, "")
    }
}

public class MockSettingsStore: SettingsStoreProtocol {
    public var snapshot: SettingsSnapshot?
    public var saveCallCount = 0

    public init(snapshot: SettingsSnapshot? = nil) {
        self.snapshot = snapshot
    }

    public func load() throws -> SettingsSnapshot? {
        snapshot
    }

    public func save(_ snapshot: SettingsSnapshot) throws {
        saveCallCount += 1
        self.snapshot = snapshot
    }
}

public class MockDirectoryStore: DirectoryStoreProtocol {
    public var snapshot: DirectorySnapshot?
    public var saveCallCount = 0

    public init(snapshot: DirectorySnapshot? = nil) {
        self.snapshot = snapshot
    }

    public func load() throws -> DirectorySnapshot? {
        snapshot
    }

    public func save(_ snapshot: DirectorySnapshot) throws {
        saveCallCount += 1
        self.snapshot = snapshot
    }
}

public class MockRepositoryStore: RepositoryStoreProtocol {
    public var snapshot: RepositorySnapshot?
    public var saveCallCount = 0

    public init(snapshot: RepositorySnapshot? = nil) {
        self.snapshot = snapshot
    }

    public func load() throws -> RepositorySnapshot? {
        snapshot
    }

    public func save(_ snapshot: RepositorySnapshot) throws {
        saveCallCount += 1
        self.snapshot = snapshot
    }
}
