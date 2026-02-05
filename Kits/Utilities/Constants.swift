import Foundation
import SwiftUI
import AppKit

private struct UIScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = CGFloat(Constants.UI.uiScaleDefault)
}

extension EnvironmentValues {
    var uiScale: CGFloat {
        get { self[UIScaleKey.self] }
        set { self[UIScaleKey.self] = newValue }
    }
}

extension Font {
    static func uiScaled(
        _ textStyle: NSFont.TextStyle,
        scale: CGFloat,
        weight: Font.Weight? = nil,
        design: Font.Design = .default
    ) -> Font {
        let baseSize = NSFont.preferredFont(forTextStyle: textStyle).pointSize
        if let weight {
            return .system(size: baseSize * scale, weight: weight, design: design)
        }
        return .system(size: baseSize * scale, design: design)
    }
}

/// Centralized constants for the Kits app.
/// All magic numbers should be defined here with descriptive names.
enum Constants {
    
    // MARK: - UI Dimensions
    enum UI {
        /// Main popover width
        static let popoverWidth: CGFloat = 450
        /// Main popover height
        static let popoverHeight: CGFloat = 500
        /// Settings popover width
        static let settingsPopoverWidth: CGFloat = 400
        /// Settings popover height
        static let settingsPopoverHeight: CGFloat = 400
        /// UI scale minimum (50%)
        static let uiScaleMin: Double = 0.5
        /// UI scale maximum (200%)
        static let uiScaleMax: Double = 2.0
        /// UI scale default (100%)
        static let uiScaleDefault: Double = 1.0
        /// Minimum content height for the repository list
        static let minContentHeight: CGFloat = 300
        
        /// Status bar icon size (width and height)
        static let statusBarIconSize: CGFloat = 18
        /// Scanning indicator dot size
        static let scanningIndicatorSize: CGFloat = 5
        /// Scanning indicator dot offset from edge
        static let scanningIndicatorOffset: CGFloat = 1
        /// Status bar icon Y offset for visual alignment
        static let statusBarIconYOffset: CGFloat = 2
        
        /// Apple HIG minimum touch target size
        static let minTouchTargetSize: CGFloat = 44
        
        /// Header horizontal padding
        static let headerPaddingHorizontal: CGFloat = 20
        /// Header vertical padding
        static let headerPaddingVertical: CGFloat = 12
        /// Header button trailing padding
        static let headerButtonTrailingPadding: CGFloat = 4
        
        /// Repository row vertical padding
        static let rowPaddingVertical: CGFloat = 8
        /// Repository row horizontal padding
        static let rowPaddingHorizontal: CGFloat = 12
        /// Repository row corner radius
        static let rowCornerRadius: CGFloat = 8
        
        /// Settings view padding
        static let settingsPadding: CGFloat = 24
        
        /// Empty state icon size
        static let emptyStateIconSize: CGFloat = 50
        /// Progress view size (width and height)
        static let progressViewSize: CGFloat = 32
        
        /// Animation duration for UI transitions
        static let animationDuration: TimeInterval = 0.3
    }
    
    // MARK: - Typography
    enum Typography {
        /// Repository name font size
        static let repoNameSize: CGFloat = 16
        /// Repository name font weight
        static let repoNameWeight: Font.Weight = .semibold
        
        /// Branch name font size
        static let branchNameSize: CGFloat = 14
        /// Timestamp font size
        static let timestampSize: CGFloat = 14
        /// Status (ahead/behind) font size
        static let statusSize: CGFloat = 14
        /// Status font weight
        static let statusWeight: Font.Weight = .bold
        
        /// Header icon font size
        static let headerIconSize: CGFloat = 18
    }
    
    // MARK: - Scanning
    enum Scanning {
        /// Default refresh interval in seconds (5 minutes)
        static let defaultRefreshInterval: TimeInterval = 300
        /// Git command timeout in seconds
        static let gitCommandTimeout: TimeInterval = 30
        /// Process timeout for auxiliary commands in seconds
        static let processTimeout: TimeInterval = 5
        /// Buffer time added to timeouts for semaphore waits (seconds)
        static let timeoutBuffer: TimeInterval = 5
        /// Timeout for reading from pipes after process termination (seconds)
        static let pipeReadTimeout: TimeInterval = 5
        
        /// Number of folders to scan before updating UI during discovery
        static let discoveryProgressUpdateInterval = 10
        /// Number of repositories to refresh when opening popover
        static let quickRefreshCount = 10
        /// Maximum concurrent git operations (capped for safety)
        static let maxConcurrentGitOperations = 4
        
        /// Delay before restarting scan after folder change (seconds)
        static let scanRestartDelay: TimeInterval = 0.1
        
        /// Polling interval for pipe reading (seconds)
        static let pipePollInterval: TimeInterval = 0.01

        /// Maximum recursion depth for repository discovery
        static let maxDiscoveryDepth = 20
        /// Maximum duration for a full scan (seconds)
        static let maxScanDuration: TimeInterval = 300
    }
    
    // MARK: - Time Formatting
    enum TimeFormatting {
        /// Threshold for "just now" in seconds
        static let justNowThreshold: TimeInterval = 5
        /// Threshold for showing seconds instead of relative time
        static let secondsThreshold: TimeInterval = 60
    }
    
    // MARK: - File System
    enum FileSystem {
        /// Git directory name
        static let gitDirectoryName = ".git"
        /// Git refs directory name
        static let refsDirectoryName = "refs"
        /// Git index file name
        static let indexFileName = "index"
        
        /// Minimum valid timestamp for sanity checks (1 year after 1970)
        static let minValidTimestamp: TimeInterval = 31536000
        /// Minimum valid timestamp for basic validation (must be > 0)
        static let minTimestampValue: TimeInterval = 0
        /// Maximum tolerated future skew for timestamps (seconds)
        static let maxFutureTimestampSkew: TimeInterval = 86400
    }
    
    // MARK: - Git Commands
    enum GitCommands {
        /// Arguments for git status command
        static let statusArgs = ["status", "--porcelain", "-b", "--untracked-files=no"]
        /// Arguments for getting current commit timestamp
        static let currentCommitArgs = ["log", "-1", "--format=%ct"]
        /// Arguments for getting most recent commit on any branch
        static let anyCommitArgs = ["for-each-ref", "--sort=-committerdate", "refs/heads", "--format=%(committerdate:unix)", "--count=1"]
        /// Arguments for getting common git directory (worktree detection)
        static let commonDirArgs = ["rev-parse", "--git-common-dir"]
    }
    
    // MARK: - UserDefaults Keys
    enum UserDefaultsKeys {
        /// Key for root folder path setting
        static let rootFolderPath = "rootFolderPath"
        /// Key for sort mode setting
        static let sortMode = "sortMode"
        /// Key for click action setting
        static let clickAction = "clickAction"
        /// Key for custom command setting
        static let customCommand = "customCommand"
        /// Key for popover width setting
        static let popoverWidth = "popoverWidth"
        /// Key for popover height setting
        static let popoverHeight = "popoverHeight"
        /// Key for UI scale setting
        static let uiScale = "uiScale"
    }
    
    // MARK: - Security
    enum Security {
        /// Set of characters considered suspicious in paths for security validation
        static let suspiciousPathCharacters = CharacterSet(charactersIn: ";|&$`\n")
    }
    
    // MARK: - Accessibility
    enum Accessibility {
        /// UserDefaults key for reduced motion preference
        static let reduceMotionKey = "UIAccessibilityReduceMotionEnabled"
    }
    
    // MARK: - Paths
    enum Paths {
        /// Common git installation paths to check
        static let commonGitPaths = [
            "/usr/bin/git",
            "/usr/local/bin/git",
            "/opt/homebrew/bin/git"
        ]
        
        /// Standard system binary directories
        static let standardSystemPaths = [
            "/usr/bin",
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/bin",
            "/sbin"
        ]
        
        /// xcrun executable path
        static let xcrunPath = "/usr/bin/xcrun"
        /// which executable path
        static let whichPath = "/usr/bin/which"
        /// Default git fallback path
        static let defaultGitPath = "/usr/bin/git"
        /// zsh executable path
        static let zshPath = "/bin/zsh"
    }
}
