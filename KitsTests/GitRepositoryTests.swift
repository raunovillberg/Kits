import XCTest
@testable import Kits

final class GitRepositoryTests: XCTestCase {
    
    func testIsWorktree_TrueWhenCommonDirDiffers() {
        let repoPath = "/Users/test/repo-worktree"
        let commonDir = "/Users/test/main-repo/.git"
        
        let repo = GitRepository(
            path: repoPath,
            name: "repo-worktree",
            currentBranch: "feature",
            lastCommitOnCurrentBranch: Date(),
            lastCommitOnAnyBranch: Date(),
            lastFileModification: Date(),
            aheadCount: 0,
            behindCount: 0,
            hasUncommittedChanges: false,
            isClean: true,
            gitCommonDir: commonDir,
            lastScanMarker: Date()
        )
        
        XCTAssertTrue(repo.isWorktree)
    }
    
    func testIsWorktree_FalseWhenCommonDirIsSameAsDotGit() {
        let repoPath = "/Users/test/repo"
        let commonDir = ".git" // Relative path
        
        let repo = GitRepository(
            path: repoPath,
            name: "repo",
            currentBranch: "main",
            lastCommitOnCurrentBranch: Date(),
            lastCommitOnAnyBranch: Date(),
            lastFileModification: Date(),
            aheadCount: 0,
            behindCount: 0,
            hasUncommittedChanges: false,
            isClean: true,
            gitCommonDir: commonDir,
            lastScanMarker: Date()
        )
        
        XCTAssertFalse(repo.isWorktree)
    }
    
    func testCompare_Alphabetical() {
        let repoA = createRepo(name: "A", path: "/a")
        let repoB = createRepo(name: "B", path: "/b")
        
        XCTAssertEqual(GitRepository.compare(repoA, repoB, mode: .alphabetical), .orderedAscending)
        XCTAssertEqual(GitRepository.compare(repoB, repoA, mode: .alphabetical), .orderedDescending)
    }
    
    func testCompare_CommitDate() {
        let now = Date()
        let earlier = now.addingTimeInterval(-3600)
        
        let repoNew = createRepo(name: "New", path: "/new", commitDate: now)
        let repoOld = createRepo(name: "Old", path: "/old", commitDate: earlier)
        
        // Sorting should be newest first
        XCTAssertEqual(GitRepository.compare(repoNew, repoOld, mode: .currentBranchCommit), .orderedAscending)
        XCTAssertEqual(GitRepository.compare(repoOld, repoNew, mode: .currentBranchCommit), .orderedDescending)
    }
    
    // Helper
    private func createRepo(name: String, path: String, commitDate: Date? = nil) -> GitRepository {
        return GitRepository(
            path: path,
            name: name,
            currentBranch: "main",
            lastCommitOnCurrentBranch: commitDate,
            lastCommitOnAnyBranch: commitDate,
            lastFileModification: commitDate,
            aheadCount: 0,
            behindCount: 0,
            hasUncommittedChanges: false,
            isClean: true,
            gitCommonDir: nil,
            lastScanMarker: nil
        )
    }
}
