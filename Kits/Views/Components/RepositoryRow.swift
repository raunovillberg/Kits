import SwiftUI

// MARK: - Repository Row

/// A row displaying information about a single Git repository
struct RepositoryRow: View {
    @Environment(\.uiScale) private var uiScale
    let repository: GitRepository
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(repository.name)
                    .font(.system(size: Constants.Typography.repoNameSize * uiScale, weight: Constants.Typography.repoNameWeight))
                    .lineLimit(1)
                
                if repository.isWorktree {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10 * uiScale, weight: .bold))
                        .foregroundColor(.secondary)
                        .help("Worktree")
                        .accessibilityLabel("Worktree")
                        .accessibilityIdentifier("worktree-badge")
                }
                
                Spacer()
                    Text(repository.lastModificationRelativeTime)
                        .font(.system(size: Constants.Typography.timestampSize * uiScale))
                        .foregroundColor(.secondary)
            }
            
            HStack(spacing: 6) {
                // Ahead/Behind status with icons for accessibility (colorblind-friendly)
                if repository.aheadCount > 0 {
                    Label {
                        Text("\(repository.aheadCount)")
                            .font(.system(size: Constants.Typography.statusSize * uiScale, weight: Constants.Typography.statusWeight))
                            .foregroundColor(.blue)
                    } icon: {
                        Image(systemName: "arrow.up")
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel(String(format: NSLocalizedString("%d commits ahead", comment: ""), repository.aheadCount))
                }
                
                if repository.behindCount > 0 {
                    Label {
                        Text("\(repository.behindCount)")
                            .font(.system(size: Constants.Typography.statusSize * uiScale, weight: Constants.Typography.statusWeight))
                            .foregroundColor(.purple)
                    } icon: {
                        Image(systemName: "arrow.down")
                            .foregroundColor(.purple)
                    }
                    .accessibilityLabel(String(format: NSLocalizedString("%d commits behind", comment: ""), repository.behindCount))
                }
                
                Text(repository.isAvailable ? repository.currentBranch : "Not found")
                    .font(.system(size: Constants.Typography.branchNameSize * uiScale))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(repository.lastCommitRelativeTime)
                    .font(.system(size: Constants.Typography.timestampSize * uiScale))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, Constants.UI.rowPaddingVertical)
        .padding(.horizontal, Constants.UI.rowPaddingHorizontal)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(Constants.UI.rowCornerRadius)
        .opacity(repository.isAvailable ? 1.0 : 0.45)
    }
}

// MARK: - Previews

#if DEBUG
struct RepositoryRow_Previews: PreviewProvider {
    static var previews: some View {
        let repo = GitRepository(
            path: "/Users/dev/sample-project",
            name: "sample-project",
            currentBranch: "main",
            lastCommitOnCurrentBranch: Date().addingTimeInterval(-3600),
            lastCommitOnAnyBranch: Date().addingTimeInterval(-3600),
            lastFileModification: Date().addingTimeInterval(-1800),
            aheadCount: 2,
            behindCount: 0,
            hasUncommittedChanges: true,
            isClean: false,
            gitCommonDir: nil
        )
        
        return RepositoryRow(repository: repo)
            .frame(width: 400)
            .padding()
    }
}
#endif
