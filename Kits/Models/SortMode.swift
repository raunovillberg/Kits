import Foundation

public enum SortMode: String, CaseIterable, Identifiable {
    case currentBranchCommit = "currentBranch"
    case anyBranchCommit = "anyBranch"
    case fileModification = "fileModification"
    case alphabetical = "alphabetical"
    
    public var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .currentBranchCommit:
            return NSLocalizedString("Last commit on current branch", comment: "")
        case .anyBranchCommit:
            return NSLocalizedString("Last commit on any branch", comment: "")
        case .fileModification:
            return NSLocalizedString("Last file modification", comment: "")
        case .alphabetical:
            return NSLocalizedString("Alphabetical", comment: "")
        }
    }
}
