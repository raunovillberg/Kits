import Foundation
import Combine
import os.log
import Observation

public final class JSONSettingsStore: SettingsStoreProtocol {
    public static var defaultSettingsURL: URL {
        URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent(Constants.SettingsFile.directoryName, isDirectory: true)
            .appendingPathComponent(Constants.SettingsFile.fileName, isDirectory: false)
    }

    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL = JSONSettingsStore.defaultSettingsURL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func load() throws -> SettingsSnapshot? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(SettingsSnapshot.self, from: data)
    }

    public func save(_ snapshot: SettingsSnapshot) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Settings Class

@Observable
public final class Settings {
    /// Refresh interval from constants (5 minutes)
    public static let refreshIntervalSeconds: TimeInterval = Constants.Scanning.defaultRefreshInterval
    private static let currentSettingsVersion = 1

    public var rootFolderPath: String? {
        didSet {
            // Validate path before storing
            if let path = rootFolderPath {
                guard isValidPath(path) else {
                    Logger.settings.error("Invalid path rejected: \(path)")
                    rootFolderPath = oldValue
                    return
                }
            }

            persistSettings()
            // Trigger the publisher manually if anyone is still using it
            _rootFolderPathSubject.send(rootFolderPath)
        }
    }

    public var sortMode: SortMode {
        didSet {
            persistSettings()
        }
    }

    public var clickAction: RepoClickAction {
        didSet {
            // Sync custom command if it's a preset.
            // customCommand's didSet performs persistence.
            if clickAction != .custom && customCommand != clickAction.commandTemplate {
                customCommand = clickAction.commandTemplate
                return
            }

            persistSettings()
        }
    }

    public var customCommand: String {
        didSet {
            do {
                try validateCommand(customCommand)
                persistSettings()
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
            persistSettings()
        }
    }

    public var popoverHeight: Double {
        didSet {
            persistSettings()
        }
    }

    public var uiScale: Double {
        didSet {
            let clamped = Self.clampUIScale(uiScale)
            if uiScale != clamped {
                uiScale = clamped
                return
            }
            persistSettings()
        }
    }

    private let settingsStore: SettingsStoreProtocol
    private let fileManager: FileManagerProtocol
    private let _rootFolderPathSubject = PassthroughSubject<String?, Never>()

    public var rootFolderPathPublisher: AnyPublisher<String?, Never> {
        _rootFolderPathSubject.eraseToAnyPublisher()
    }

    public init(store: SettingsStoreProtocol = JSONSettingsStore(), fileManager: FileManagerProtocol = FileManager.default) {
        let isUITesting = ProcessInfo.processInfo.environment["KITS_UI_TESTING"] == "1"
        if isUITesting {
            let uiTestsURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("kits-uitests-settings.json", isDirectory: false)
            self.settingsStore = JSONSettingsStore(fileURL: uiTestsURL)
        } else {
            self.settingsStore = store
        }
        self.fileManager = fileManager

        let loadedSnapshot: SettingsSnapshot?
        do {
            loadedSnapshot = try self.settingsStore.load()
        } catch {
            Logger.settings.error("Failed to load settings file: \(error.localizedDescription)")
            loadedSnapshot = nil
        }

        let savedSnapshot = Self.migrateSnapshotIfNeeded(loadedSnapshot)

        if let savedSnapshot, savedSnapshot.version > Self.currentSettingsVersion {
            Logger.settings.warning("Settings file version \(savedSnapshot.version) is newer than supported version \(Self.currentSettingsVersion)")
        }

        if let testRoot = ProcessInfo.processInfo.environment["KITS_TEST_ROOT_PATH"], !testRoot.isEmpty {
            self.rootFolderPath = testRoot
        } else {
            self.rootFolderPath = savedSnapshot?.rootFolderPath
        }

        let testSortMode = ProcessInfo.processInfo.environment["KITS_TEST_SORT_MODE"]
        if let testSortMode, let mode = SortMode(rawValue: testSortMode) {
            self.sortMode = mode
        } else {
            let savedSortMode = savedSnapshot?.sortMode
            if let rawValue = savedSortMode, let mode = SortMode(rawValue: rawValue) {
                self.sortMode = mode
            } else {
                self.sortMode = .currentBranchCommit
                if savedSortMode != nil {
                    Logger.settings.warning("Invalid saved sort mode, using default")
                }
            }
        }

        let savedAction = savedSnapshot?.clickAction ?? ""
        let action = RepoClickAction(rawValue: savedAction) ?? .finder
        self.clickAction = action

        if action == .custom {
            let savedCommand = savedSnapshot?.customCommand ?? action.commandTemplate
            self.customCommand = savedCommand
        } else {
            self.customCommand = action.commandTemplate
        }

        self.popoverWidth = savedSnapshot?.popoverWidth ?? Double(Constants.UI.popoverWidth)
        self.popoverHeight = savedSnapshot?.popoverHeight ?? Double(Constants.UI.popoverHeight)
        self.uiScale = Self.clampUIScale(savedSnapshot?.uiScale ?? Constants.UI.uiScaleDefault)

        // Initial validation of loaded command
        try? validateCommand(customCommand)

        // Ensure file exists and has a version even if no settings were changed this launch.
        persistSettings()
    }

    private static func migrateSnapshotIfNeeded(_ snapshot: SettingsSnapshot?) -> SettingsSnapshot? {
        guard let snapshot else {
            return nil
        }

        guard snapshot.version < currentSettingsVersion else {
            return snapshot
        }

        let migratedSnapshot = migrate(snapshot: snapshot, to: currentSettingsVersion)
        Logger.settings.info("Migrated settings snapshot from version \(snapshot.version) to \(migratedSnapshot.version)")
        return migratedSnapshot
    }

    private static func migrate(snapshot: SettingsSnapshot, to targetVersion: Int) -> SettingsSnapshot {
        var migratedSnapshot = snapshot

        while migratedSnapshot.version < targetVersion {
            switch migratedSnapshot.version {
            case 0:
                migratedSnapshot = migrateV0ToV1(migratedSnapshot)
            default:
                Logger.settings.warning("No explicit migration defined for settings version \(migratedSnapshot.version). Forcing version \(targetVersion).")
                migratedSnapshot.version = targetVersion
            }
        }

        return migratedSnapshot
    }

    // Migration scaffold: add future migration steps (e.g. v1->v2) here.
    private static func migrateV0ToV1(_ snapshot: SettingsSnapshot) -> SettingsSnapshot {
        var migratedSnapshot = snapshot
        migratedSnapshot.version = 1
        return migratedSnapshot
    }

    private static func clampUIScale(_ value: Double) -> Double {
        min(max(value, Constants.UI.uiScaleMin), Constants.UI.uiScaleMax)
    }

    private func persistSettings() {
        let snapshot = SettingsSnapshot(
            version: Self.currentSettingsVersion,
            rootFolderPath: rootFolderPath,
            sortMode: sortMode.rawValue,
            clickAction: clickAction.rawValue,
            customCommand: customCommand,
            popoverWidth: popoverWidth,
            popoverHeight: popoverHeight,
            uiScale: uiScale
        )

        do {
            try settingsStore.save(snapshot)
        } catch {
            Logger.settings.error("Failed to save settings file: \(error.localizedDescription)")
        }
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
