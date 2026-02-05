import Foundation

public struct GitRepository: Identifiable {
    public var id: String { path }
    let path: String
    let name: String
    let currentBranch: String
    let lastCommitOnCurrentBranch: Date?
    let lastCommitOnAnyBranch: Date?
    let lastFileModification: Date?
    let aheadCount: Int
    let behindCount: Int
    let hasUncommittedChanges: Bool
    let isClean: Bool
    let gitCommonDir: String? // Points to shared git dir for worktrees
    var lastScanMarker: Date? // Used for stat-based skipping
    
    // MARK: - Worktree Detection
    
    /// Whether this repository is a worktree linked to a main repository
    var isWorktree: Bool {
        guard let commonDir = gitCommonDir else { return false }
        
        // Resolve commonDir to an absolute path if it's relative
        let absoluteCommonDir: String
        if (commonDir as NSString).isAbsolutePath {
            absoluteCommonDir = (commonDir as NSString).standardizingPath
        } else {
            absoluteCommonDir = ((path as NSString).appendingPathComponent(commonDir) as NSString).standardizingPath
        }
        
        let dotGitPath = ((path as NSString).appendingPathComponent(".git") as NSString).standardizingPath
        return absoluteCommonDir != dotGitPath
    }
    
    // MARK: - Comparison
    
    /// Compares two repositories based on the specified sort mode.
    /// - Returns: .orderedAscending if lhs should come before rhs,
    ///           .orderedDescending if lhs should come after rhs,
    ///           .orderedSame if they are equal
    static func compare(_ lhs: GitRepository, _ rhs: GitRepository, mode: SortMode) -> ComparisonResult {
        switch mode {
        case .alphabetical:
            return compareByNameThenPath(lhs, rhs)

        case .currentBranchCommit, .anyBranchCommit, .fileModification:
            let lhsDate = lhs.sortDate(for: mode) ?? Date.distantPast
            let rhsDate = rhs.sortDate(for: mode) ?? Date.distantPast
            if lhsDate > rhsDate {
                return .orderedAscending
            } else if lhsDate < rhsDate {
                return .orderedDescending
            } else {
                // Deterministic tie-breaker for equal dates.
                return compareByNameThenPath(lhs, rhs)
            }
        }
    }

    private static func compareByNameThenPath(_ lhs: GitRepository, _ rhs: GitRepository) -> ComparisonResult {
        let byName = lhs.name.localizedStandardCompare(rhs.name)
        if byName != .orderedSame {
            return byName
        }
        return lhs.path.localizedStandardCompare(rhs.path)
    }

    func sortDate(for mode: SortMode) -> Date? {
        switch mode {
        case .currentBranchCommit:
            return lastCommitOnCurrentBranch
        case .anyBranchCommit:
            // For worktrees, use the most recent available signal:
            // any-branch commit time and/or file modification time.
            if isWorktree {
                return [lastCommitOnAnyBranch, lastFileModification].compactMap { $0 }.max()
            }
            return lastCommitOnAnyBranch
        case .fileModification:
            return lastFileModification
        case .alphabetical:
            return nil
        }
    }
    
    var aheadBehindStatus: String {
        var parts: [String] = []
        if aheadCount > 0 { parts.append("↑\(aheadCount)") }
        if behindCount > 0 { parts.append("↓\(behindCount)") }
        return parts.joined(separator: " ")
    }
    
    var lastCommitRelativeTime: String {
        guard let description = lastCommitOnCurrentBranch?.relativeTimeDescription else { return NSLocalizedString("No commits", comment: "") }
        let format = NSLocalizedString("Commit %@", comment: "Label for the last commit time")
        return String(format: format, description)
    }
    
    var lastModificationRelativeTime: String {
        guard let date = lastFileModification else { return "" }
        let format = NSLocalizedString("Edit %@", comment: "Label for the last edit time")
        return String(format: format, date.relativeTimeDescription)
    }
    
    var relativeTimeDescription: String {
        // Default to currentBranchCommit for display
        let date = lastCommitOnCurrentBranch ?? lastCommitOnAnyBranch
        return date?.relativeTimeDescription ?? NSLocalizedString("Unknown", comment: "")
    }
    
    // MARK: - Accessibility
    
    var accessibilityLabel: String {
        let prefix = isWorktree ? "Worktree, " : ""
        return "\(prefix)\(name), branch \(currentBranch)"
    }
    
    var accessibilityValue: String {
        var components: [String] = []
        if hasUncommittedChanges {
            components.append(NSLocalizedString("has uncommitted changes", comment: ""))
        }
        if aheadCount > 0 {
            let format = NSLocalizedString("%d commits ahead", comment: "Accessibility description for ahead count")
            components.append(String(format: format, aheadCount))
        }
        if behindCount > 0 {
            let format = NSLocalizedString("%d commits behind", comment: "Accessibility description for behind count")
            components.append(String(format: format, behindCount))
        }
        if let date = lastCommitOnCurrentBranch {
            let format = NSLocalizedString("last commit %@", comment: "Accessibility description for last commit time")
            components.append(String(format: format, date.relativeTimeDescription))
        }
        return components.joined(separator: ", ")
    }
}
