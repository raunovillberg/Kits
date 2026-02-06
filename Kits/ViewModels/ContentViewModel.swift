import Foundation
import SwiftUI
import os.log

// MARK: - Content View Model

/// ViewModel for ContentView using the new @Observable macro
/// Handles business logic while keeping view-specific state in the view
@Observable
@MainActor
final class ContentViewModel {
    
    // MARK: - Properties
    
    var errorMessage: String?
    
    private let gitScanner: GitScanner
    private let settings: Settings
    private let logger: Logger
    private let commandExecutor: CommandExecutorProtocol
    
    // MARK: - Computed Properties
    
    /// The display name for the current folder (with ~ for home directory)
    var folderName: String {
        guard let path = settings.rootFolderPath else {
            return "Choose root folder..."
        }
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return (path as NSString).lastPathComponent
    }
    
    /// The SF Symbol icon name for the current sort mode
    var sortModeIcon: String {
        switch settings.sortMode {
        case .currentBranchCommit:
            return "arrow.down.circle"
        case .anyBranchCommit:
            return "arrow.triangle.branch"
        case .fileModification:
            return "doc.badge.clock"
        case .alphabetical:
            return "textformat.abc"
        }
    }
    
    /// Human-readable description of the current sort mode
    var sortModeDescription: String {
        settings.sortMode.displayName
    }
    
    /// Status text for the header (scanning progress or last update time)
    var statusText: String {
        if gitScanner.isScanning {
            if gitScanner.isShowingCachedSnapshot && !gitScanner.repositories.isEmpty {
                if gitScanner.totalReposToScan > 0 {
                    let format = NSLocalizedString("Showing cached data, updating %lld/%lld...", comment: "Status shown while cached repository data is visible and a live refresh with progress counters is running")
                    return String(format: format, gitScanner.scannedReposCount, gitScanner.totalReposToScan)
                }
                return NSLocalizedString("Showing cached data, updating...", comment: "Status shown while cached repository data is visible and a live refresh is running")
            }

            if gitScanner.totalReposToScan > 0 {
                switch gitScanner.currentScanPhase {
                case "Updating commit data":
                    let format = NSLocalizedString("Updating commit data %lld/%lld...", comment: "Status shown while refreshing commit-based repository metadata with progress counters")
                    return String(format: format, gitScanner.scannedReposCount, gitScanner.totalReposToScan)
                case "Updating file modifications":
                    let format = NSLocalizedString("Updating file modifications %lld/%lld...", comment: "Status shown while refreshing file modification timestamps with progress counters")
                    return String(format: format, gitScanner.scannedReposCount, gitScanner.totalReposToScan)
                default:
                    let format = NSLocalizedString("Updating %lld/%lld...", comment: "Status shown while refreshing repositories with progress counters")
                    return String(format: format, gitScanner.scannedReposCount, gitScanner.totalReposToScan)
                }
            } else if gitScanner.discoveryFoldersScanned > 0 {
                let format = NSLocalizedString("Scanning %lld folders...", comment: "Status shown while discovering repositories by scanning folders")
                return String(format: format, gitScanner.discoveryFoldersScanned)
            } else {
                return NSLocalizedString("Scanning...", comment: "Status shown while scanning repositories")
            }
        } else if let lastScan = gitScanner.lastScanDate {
            let count = gitScanner.repositories.count
            if gitScanner.isShowingCachedSnapshot {
                let format = NSLocalizedString("%lld repos, showing cached data", comment: "Status shown with repository count when cached data is displayed")
                return String(format: format, count)
            }
            let format = NSLocalizedString("%lld repos, updated %@", comment: "Status shown with repository count and relative update time")
            return String(format: format, count, lastScan.relativeTimeDescription)
        }
        return ""
    }
    
    /// The current scanning path (if any) for detailed status
    var currentScanningPath: String? {
        gitScanner.currentScanningPath
    }
    
    /// Whether a scan is currently in progress
    var isScanning: Bool {
        gitScanner.isScanning
    }
    
    /// The list of repositories (read-only access)
    var repositories: [GitRepository] {
        gitScanner.repositories
    }
    
    /// Whether the root folder is set
    var hasRootFolder: Bool {
        settings.rootFolderPath != nil
    }
    
    /// The custom command template for opening repositories
    var customCommand: String {
        settings.customCommand
    }
    
    /// The current sort mode
    var sortMode: SortMode {
        settings.sortMode
    }
    
    /// Popover width setting
    var popoverWidth: CGFloat {
        CGFloat(settings.popoverWidth)
    }
    
    /// Popover height setting
    var popoverHeight: CGFloat {
        CGFloat(settings.popoverHeight)
    }
    
    /// UI scale setting
    var uiScale: CGFloat {
        CGFloat(settings.uiScale)
    }
    
    // MARK: - Initialization
    
    init(
        gitScanner: GitScanner,
        settings: Settings,
        commandExecutor: CommandExecutorProtocol? = nil,
        logger: Logger? = nil
    ) {
        self.gitScanner = gitScanner
        self.settings = settings
        self.commandExecutor = commandExecutor ?? CommandExecutor()
        self.logger = logger ?? Logger.ui
    }
    
    // MARK: - Actions
    
    /// Cycles to the next sort mode and re-sorts the repositories
    /// - Parameter reverse: Whether to cycle in reverse order
    /// - Returns: Whether the sort mode changed
    @discardableResult
    func cycleSortMode(reverse: Bool = false) -> Bool {
        let allModes = SortMode.allCases
        let currentIndex = allModes.firstIndex(of: settings.sortMode) ?? 0
        
        let nextIndex: Int
        if reverse {
            nextIndex = (currentIndex - 1 + allModes.count) % allModes.count
        } else {
            nextIndex = (currentIndex + 1) % allModes.count
        }
        
        settings.sortMode = allModes[nextIndex]
        
        // Re-sort the repositories using the GitScanner method
        gitScanner.sortRepositories(by: settings.sortMode)
        
        let newSortMode = settings.sortMode.displayName
        logger.debug("Changed sort mode to: \(newSortMode)")
        return true
    }
    
    /// Sets the root folder path and triggers a scan after validation
    /// - Parameter path: The new root folder path
    func setRootFolder(path: String) {
        // Validation is now handled in Settings.swift's didSet for rootFolderPath
        // which reverts to oldValue if invalid.
        settings.rootFolderPath = path
        
        // Check if the path was actually accepted
        if settings.rootFolderPath == path {
            logger.debug("Set root folder to: \(path)")
        } else {
            // If it reverted, it was invalid
            showError(NSLocalizedString("Invalid folder selection. Please ensure it is a readable directory.", comment: ""))
            logger.warning("Root folder selection rejected: \(path)")
        }
    }
    
    /// Triggers a manual refresh of the repositories
    func refresh() {
        guard !gitScanner.isScanning else {
            logger.debug("Refresh requested but already scanning")
            return
        }
        gitScanner.performScan()
    }
    
    /// Opens a repository using the configured custom command
    /// - Parameter path: The repository path to open
    func openRepository(at path: String) {
        commandExecutor.execute(
            commandTemplate: settings.customCommand,
            path: path
        ) { [weak self] result in
            if case .failure(let error) = result {
                self?.showError("Failed to open repository: \(error.localizedDescription)")
            }
        }
    }
    
    /// Clears any displayed error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Shows an error message
    /// - Parameter message: The error message to display
    func showError(_ message: String) {
        errorMessage = message
        logger.error("ContentView error: \(message)")
    }
}

// MARK: - Preview Support

#if DEBUG
extension ContentViewModel {
    /// Creates a preview ViewModel with mock data
    static func preview() -> ContentViewModel {
        let settings = Settings()
        let scanner = GitScanner(settings: settings)
        let mockExecutor = MockCommandExecutor()
        
        // Add sample repositories for previews
        let commonDir = "/Users/dev/project-main/.git"
        scanner.repositories = [
            GitRepository(
                path: "/Users/dev/project-alpha",
                name: "project-alpha",
                currentBranch: "main",
                lastCommitOnCurrentBranch: Date().addingTimeInterval(-10800),
                lastCommitOnAnyBranch: Date().addingTimeInterval(-1800),
                lastFileModification: Date().addingTimeInterval(-7200),
                aheadCount: 2,
                behindCount: 0,
                hasUncommittedChanges: true,
                isClean: false,
                gitCommonDir: nil
            ),
            GitRepository(
                path: "/Users/dev/project-alpha-wt",
                name: "project-alpha-wt",
                currentBranch: "feature/work",
                lastCommitOnCurrentBranch: Date().addingTimeInterval(-3600),
                lastCommitOnAnyBranch: Date().addingTimeInterval(-3600),
                lastFileModification: Date().addingTimeInterval(-3600),
                aheadCount: 0,
                behindCount: 0,
                hasUncommittedChanges: false,
                isClean: true,
                gitCommonDir: commonDir
            ),
            GitRepository(
                path: "/Users/dev/project-beta",
                name: "project-beta",
                currentBranch: "feature/new-ui",
                lastCommitOnCurrentBranch: Date().addingTimeInterval(-3600),
                lastCommitOnAnyBranch: Date().addingTimeInterval(-7200),
                lastFileModification: Date().addingTimeInterval(-1800),
                aheadCount: 0,
                behindCount: 5,
                hasUncommittedChanges: true,
                isClean: false,
                gitCommonDir: nil
            ),
            GitRepository(
                path: "/Users/dev/project-gamma",
                name: "project-gamma",
                currentBranch: "main",
                lastCommitOnCurrentBranch: Date().addingTimeInterval(-1800),
                lastCommitOnAnyBranch: Date().addingTimeInterval(-86400),
                lastFileModification: Date().addingTimeInterval(-86400),
                aheadCount: 0,
                behindCount: 0,
                hasUncommittedChanges: false,
                isClean: true,
                gitCommonDir: nil
            )
        ]
        
        return ContentViewModel(gitScanner: scanner, settings: settings, commandExecutor: mockExecutor)
    }
}
#endif
