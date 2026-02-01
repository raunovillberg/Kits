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

public class MockUserDefaults: UserDefaultsProtocol {
    public var storage: [String: Any] = [:]
    
    public init() {}
    
    public func string(forKey defaultName: String) -> String? {
        return storage[defaultName] as? String
    }
    
    public func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }
    
    public func integer(forKey defaultName: String) -> Int {
        return storage[defaultName] as? Int ?? 0
    }
    
    public func double(forKey defaultName: String) -> Double {
        return storage[defaultName] as? Double ?? 0.0
    }
    
    public func object(forKey defaultName: String) -> Any? {
        return storage[defaultName]
    }
    
    public func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }
}
