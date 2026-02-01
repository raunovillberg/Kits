import Foundation
import os.log

class LaunchAtLoginHelper {
    private let bundleId = Bundle.main.bundleIdentifier ?? "es.makingvideogam.Kits"
    
    enum LaunchAtLoginError: Error {
        case invalidPath
        case invalidBundlePath(String)
        case executableNotFound
        case invalidPlist
        case emptyPlistData
        case directoryCreationFailed(Error)
    }

    private var launchAgentPath: URL? {
        do {
            let folder = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library")
                .appendingPathComponent("LaunchAgents")
            
            // Create directory with proper permissions
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o755]
            )
            
            return folder.appendingPathComponent("\(bundleId).plist")
        } catch {
            Logger.general.error("Failed to create LaunchAgents directory: \(error.localizedDescription)")
            return nil
        }
    }
    
    var isEnabled: Bool {
        get {
            guard let path = launchAgentPath else { return false }
            return FileManager.default.fileExists(atPath: path.path)
        }
        set {
            if newValue {
                do {
                    try enable()
                } catch {
                    Logger.general.error("Failed to enable launch at login: \(error.localizedDescription)")
                    // Notify UI if possible, but at least we're throwing in enable()
                }
            } else {
                do {
                    try disable()
                } catch {
                    Logger.general.error("Failed to disable launch at login: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func enable() throws {
        guard let path = launchAgentPath else {
            throw KitsError.launchAgentPathInvalid
        }
        
        // Validate bundle path
        let appPath = Bundle.main.bundlePath
        guard isValidPath(appPath) else {
            throw LaunchAtLoginError.invalidBundlePath(appPath)
        }
        
        // Use URL path components instead of string interpolation
        let appURL = URL(fileURLWithPath: appPath)
        let executableURL = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("MacOS")
            .appendingPathComponent("Kits")
        
        // Verify executable exists
        guard FileManager.default.fileExists(atPath: executableURL.path) else {
            throw LaunchAtLoginError.executableNotFound
        }
        
        let plist: [String: Any] = [
            "Label": bundleId,
            "ProgramArguments": [executableURL.path],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
            "StandardOutPath": "/dev/null",
            "StandardErrorPath": getLogPath().path
        ]
        
        // Validate plist can be serialized
        guard PropertyListSerialization.propertyList(plist, isValidFor: .xml) else {
            throw LaunchAtLoginError.invalidPlist
        }
        
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            
            // Validate data isn't empty
            guard !data.isEmpty else {
                throw LaunchAtLoginError.emptyPlistData
            }
            
            // Write atomically
            try data.write(to: path, options: .atomic)
            Logger.general.info("Launch at login enabled: \(path.path)")
        } catch {
            throw KitsError.launchAgentCreationFailed(underlying: error)
        }
    }
    
    private func disable() throws {
        guard let path = launchAgentPath else { return }
        do {
            try FileManager.default.removeItem(at: path)
            Logger.general.info("Launch at login disabled")
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError {
                // Ignore if file doesn't exist
                return
            }
            throw KitsError.launchAgentRemovalFailed(underlying: error)
        }
    }
    
    /// Updates the path in the plist in case the app was moved
    func updatePathIfNeeded() {
        if isEnabled {
            do {
                try enable() 
            } catch {
                Logger.general.error("Failed to update launch at login path: \(error.localizedDescription)")
            }
        }
    }

    private func isValidPath(_ path: String) -> Bool {
        // Reject paths with suspicious characters
        return path.rangeOfCharacter(from: Constants.Security.suspiciousPathCharacters) == nil
    }

    private func getLogPath() -> URL {
        let logDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Logs")
            .appendingPathComponent("Kits")
        
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        
        return logDir.appendingPathComponent("launchagent.log")
    }
}
