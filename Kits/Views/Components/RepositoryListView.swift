import SwiftUI

// MARK: - Repository List View

/// Scrollable list of repositories with scroll-to-top support
struct RepositoryListView: View {
    let repositories: [GitRepository]
    let scrollToTopTrigger: UUID
    let onRepoTap: (GitRepository) -> Void
    
    var body: some View {
        ScrollViewReader { proxy in
            List(repositories) { repo in
                RepositoryRow(repository: repo)
                    .contentShape(Rectangle())
                    .disabled(!repo.isAvailable)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(repo.accessibilityLabel)
                    .accessibilityHint(repo.isAvailable ? NSLocalizedString("Double tap to open repository", comment: "") : NSLocalizedString("Repository is unavailable", comment: ""))
                    .accessibilityValue(repo.accessibilityValue)
                    .accessibilityIdentifier("repo-\(repo.name)")
                    .onTapGesture {
                        guard repo.isAvailable else { return }
                        onRepoTap(repo)
                    }
            }
            .listStyle(.plain)
            .frame(minHeight: Constants.UI.minContentHeight)
            .onChange(of: scrollToTopTrigger) {
                // Scroll to first repo (or top of list if empty)
                withAnimation {
                    if let firstId = repositories.first?.id {
                        proxy.scrollTo(firstId, anchor: .top)
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
struct RepositoryListView_Previews: PreviewProvider {
    static var previews: some View {
        let repos = [
            GitRepository(
                path: "/Users/dev/project-alpha",
                name: "project-alpha",
                currentBranch: "main",
                lastCommitOnCurrentBranch: Date().addingTimeInterval(-3600),
                lastCommitOnAnyBranch: Date().addingTimeInterval(-3600),
                lastFileModification: Date().addingTimeInterval(-7200),
                aheadCount: 2,
                behindCount: 0,
                hasUncommittedChanges: true,
                isClean: false,
                gitCommonDir: nil
            ),
            GitRepository(
                path: "/Users/dev/project-beta",
                name: "project-beta",
                currentBranch: "feature/new-ui",
                lastCommitOnCurrentBranch: Date().addingTimeInterval(-7200),
                lastCommitOnAnyBranch: Date().addingTimeInterval(-7200),
                lastFileModification: Date().addingTimeInterval(-1800),
                aheadCount: 0,
                behindCount: 5,
                hasUncommittedChanges: true,
                isClean: false,
                gitCommonDir: nil
            )
        ]
        
        return RepositoryListView(
            repositories: repos,
            scrollToTopTrigger: UUID(),
            onRepoTap: { repo in
                print("Tapped: \(repo.name)")
            }
        )
        .frame(height: 300)
    }
}
#endif
