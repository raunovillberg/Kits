import Foundation
import Combine
import os.log
import Observation

// MARK: - Settings Class

@Observable
public final class Settings {
    /// Refresh interval from constants (5 minutes)
    public static let refreshIntervalSeconds: TimeInterval = Constants.Scanning.defaultRefreshInterval
    
    public var rootFolderPath: String? {
        didSet {
            // Validate path before storing
            if let path = rootFolderPath {
                guard isValidPath(path) else {
                    Logger.settings.error("Invalid path rejected: \(path)")
                    rootFolderPath = oldValue
                    return
                }
                userDefaults.set(path, forKey: Constants.UserDefaultsKeys.rootFolderPath)
            } else {
                userDefaults.removeObject(forKey: Constants.UserDefaultsKeys.rootFolderPath)
            }
            // Trigger the publisher manually if anyone is still using it
            _rootFolderPathSubject.send(rootFolderPath)
        }
    }
    
    public var sortMode: SortMode {
        didSet {
            userDefaults.set(sortMode.rawValue, forKey: Constants.UserDefaultsKeys.sortMode)
        }
    }
    
    public var clickAction: RepoClickAction {
        didSet {
            userDefaults.set(clickAction.rawValue, forKey: Constants.UserDefaultsKeys.clickAction)
            // Sync custom command if it's a preset
            if clickAction != .custom {
                customCommand = clickAction.commandTemplate
            }
        }
    }
    
    public var customCommand: String {
        didSet {
            do {
                try validateCommand(customCommand)
                userDefaults.set(customCommand, forKey: Constants.UserDefaultsKeys.customCommand)
            } catch {
                Logger.settings.error("Invalid command rejected: \(error)")
                // Revert to old value to maintain valid state
                customCommand = oldValue
            }
        }
    }
    
    public var commandError: String?
    
    public var popoverWidth: Double {
        didSet {
            userDefaults.set(popoverWidth, forKey: Constants.UserDefaultsKeys.popoverWidth)
        }
    }
    
    public var popoverHeight: Double {
        didSet {
            userDefaults.set(popoverHeight, forKey: Constants.UserDefaultsKeys.popoverHeight)
        }
    }
    
    public var uiScale: Double {
        didSet {
            let clamped = Self.clampUIScale(uiScale)
            if uiScale != clamped {
                uiScale = clamped
                return
            }
            userDefaults.set(uiScale, forKey: Constants.UserDefaultsKeys.uiScale)
        }
    }
    
    private let userDefaults: UserDefaultsProtocol
    private let fileManager: FileManagerProtocol
    private let _rootFolderPathSubject = PassthroughSubject<String?, Never>()
    
    public var rootFolderPathPublisher: AnyPublisher<String?, Never> {
        _rootFolderPathSubject.eraseToAnyPublisher()
    }
    
    public init(userDefaults: UserDefaultsProtocol = UserDefaults.standard, fileManager: FileManagerProtocol = FileManager.default) {
        let isUITesting = ProcessInfo.processInfo.environment["KITS_UI_TESTING"] == "1"
        if isUITesting {
            self.userDefaults = UserDefaults(suiteName: "KitsUITests") ?? UserDefaults.standard
        } else {
            self.userDefaults = userDefaults
        }
        self.fileManager = fileManager
        
        // Settings version tracking for future migrations
        let currentVersion = 1
        let savedVersion = self.userDefaults.integer(forKey: "settingsVersion")
        if savedVersion < currentVersion {
            // Perform migrations if needed
            self.userDefaults.set(currentVersion, forKey: "settingsVersion")
        }
        
        let userDefaultsPath = self.userDefaults.string(forKey: Constants.UserDefaultsKeys.rootFolderPath)

        if let testRoot = ProcessInfo.processInfo.environment["KITS_TEST_ROOT_PATH"], !testRoot.isEmpty {
            self.rootFolderPath = testRoot
        } else {
            self.rootFolderPath = userDefaultsPath
        }
        
        let testSortMode = ProcessInfo.processInfo.environment["KITS_TEST_SORT_MODE"]
        if let testSortMode, let mode = SortMode(rawValue: testSortMode) {
            self.sortMode = mode
        } else {
            let savedSortMode = self.userDefaults.string(forKey: Constants.UserDefaultsKeys.sortMode)
            if let rawValue = savedSortMode, let mode = SortMode(rawValue: rawValue) {
                self.sortMode = mode
            } else {
                self.sortMode = .currentBranchCommit
                if savedSortMode != nil {
                    Logger.settings.warning("Invalid saved sort mode, using default")
                }
            }
        }
        
        let savedAction = self.userDefaults.string(forKey: Constants.UserDefaultsKeys.clickAction) ?? ""
        let action = RepoClickAction(rawValue: savedAction) ?? .finder
        self.clickAction = action
        
        if action == .custom {
            let savedCommand = self.userDefaults.string(forKey: Constants.UserDefaultsKeys.customCommand) ?? action.commandTemplate
            self.customCommand = savedCommand
        } else {
            self.customCommand = action.commandTemplate
        }
        
        let savedPopoverWidth = self.userDefaults.object(forKey: Constants.UserDefaultsKeys.popoverWidth) as? Double
        let savedPopoverHeight = self.userDefaults.object(forKey: Constants.UserDefaultsKeys.popoverHeight) as? Double
        let savedUIScale = self.userDefaults.object(forKey: Constants.UserDefaultsKeys.uiScale) as? Double
        self.popoverWidth = savedPopoverWidth ?? Double(Constants.UI.popoverWidth)
        self.popoverHeight = savedPopoverHeight ?? Double(Constants.UI.popoverHeight)
        self.uiScale = Self.clampUIScale(savedUIScale ?? Constants.UI.uiScaleDefault)

        // Initial validation of loaded command
        try? validateCommand(customCommand)
    }

    private static func clampUIScale(_ value: Double) -> Double {
        min(max(value, Constants.UI.uiScaleMin), Constants.UI.uiScaleMax)
    }

    private func isValidPath(_ path: String) -> Bool {
        // Basic safety check: no suspicious characters and exists
        let url = URL(fileURLWithPath: path)
        let isSuspicious = path.rangeOfCharacter(from: Constants.Security.suspiciousPathCharacters) != nil
        
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
        
        return !isSuspicious && exists && isDirectory.boolValue && url.isFileURL && fileManager.isReadableFile(atPath: path)
    }
    
    public func validateCommand(_ command: String) throws {
        // Check not empty
        guard !command.isEmpty else {
            commandError = NSLocalizedString("Command cannot be empty", comment: "")
            throw CommandValidationError.empty
        }
        
        // Check length
        guard command.count < 1000 else {
            commandError = NSLocalizedString("Command is too long", comment: "")
            throw CommandValidationError.tooLong
        }
        
        // Check for {path} placeholder
        guard command.contains("{path}") else {
            commandError = NSLocalizedString("Command must contain {path} placeholder", comment: "")
            throw CommandValidationError.missingPathPlaceholder
        }
        
        // Check for dangerous characters (additional to shell escaping)
        let dangerousPatterns = [
            ";",      // Command separator
            "&&",     // AND operator
            "||",     // OR operator
            "|",      // Pipe
            "`",      // Backtick
            "$()",    // Command substitution
            "${",     // Variable expansion
            ">",      // Redirection
            "<",      // Redirection
            "&",      // Background
        ]
        
        for pattern in dangerousPatterns {
            if command.contains(pattern) {
                commandError = NSLocalizedString("Command contains dangerous characters", comment: "")
                throw CommandValidationError.containsDangerousCharacters
            }
        }
        
        // Reset error state if all checks passed
        commandError = nil
    }
}

// MARK: - Validation Errors

public enum CommandValidationError: Error {
    case missingPathPlaceholder
    case containsDangerousCharacters
    case tooLong
    case empty
}

