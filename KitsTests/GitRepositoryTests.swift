import XCTest
@testable import Kits

final class GitRepositoryTests: XCTestCase {

    func testIsWorktree_TrueWhenCommonDirDiffers() {
        let repoPath = "/Users/test/repo-worktree"
        let commonDir = "/Users/test/main-repo/.git"

        let repo = createRepo(
            name: "repo-worktree",
            path: repoPath,
            currentBranchDate: Date(),
            anyBranchDate: Date(),
            fileModificationDate: Date(),
            gitCommonDir: commonDir
        )

        XCTAssertTrue(repo.isWorktree)
    }

    func testIsWorktree_FalseWhenCommonDirIsSameAsDotGit() {
        let repoPath = "/Users/test/repo"
        let commonDir = ".git" // Relative path

        let repo = createRepo(
            name: "repo",
            path: repoPath,
            currentBranchDate: Date(),
            anyBranchDate: Date(),
            fileModificationDate: Date(),
            gitCommonDir: commonDir
        )

        XCTAssertFalse(repo.isWorktree)
    }

    func testCompare_Alphabetical_UsesPathAsTieBreaker() {
        let left = createRepo(name: "Same", path: "/a")
        let right = createRepo(name: "Same", path: "/b")

        XCTAssertEqual(GitRepository.compare(left, right, mode: .alphabetical), .orderedAscending)
        XCTAssertEqual(GitRepository.compare(right, left, mode: .alphabetical), .orderedDescending)
    }

    func testCompare_CommitDate_NewestFirst() {
        let now = Date()
        let earlier = now.addingTimeInterval(-3600)

        let repoNew = createRepo(name: "New", path: "/new", currentBranchDate: now)
        let repoOld = createRepo(name: "Old", path: "/old", currentBranchDate: earlier)

        XCTAssertEqual(GitRepository.compare(repoNew, repoOld, mode: .currentBranchCommit), .orderedAscending)
        XCTAssertEqual(GitRepository.compare(repoOld, repoNew, mode: .currentBranchCommit), .orderedDescending)
    }

    func testCompare_CommitDate_NilDateSortsLast() {
        let dated = createRepo(name: "Dated", path: "/dated", currentBranchDate: Date())
        let missing = createRepo(name: "Missing", path: "/missing", currentBranchDate: nil)

        XCTAssertEqual(GitRepository.compare(dated, missing, mode: .currentBranchCommit), .orderedAscending)
        XCTAssertEqual(GitRepository.compare(missing, dated, mode: .currentBranchCommit), .orderedDescending)
    }

    func testSortDate_AnyBranchCommit_WorktreeFallsBackToFileModificationWhenCommitMissing() {
        let fileDate = Date()
        let repo = createRepo(
            name: "worktree",
            path: "/Users/test/worktree",
            anyBranchDate: nil,
            fileModificationDate: fileDate,
            gitCommonDir: "/Users/test/main/.git"
        )

        XCTAssertEqual(repo.sortDate(for: .anyBranchCommit), fileDate)
    }

    func testCompare_DateTie_UsesNameThenPathForDeterministicOrder() {
        let sameDate = Date()

        let alpha = createRepo(name: "Alpha", path: "/z", currentBranchDate: sameDate)
        let beta = createRepo(name: "Beta", path: "/a", currentBranchDate: sameDate)

        XCTAssertEqual(GitRepository.compare(alpha, beta, mode: .currentBranchCommit), .orderedAscending)
        XCTAssertEqual(GitRepository.compare(beta, alpha, mode: .currentBranchCommit), .orderedDescending)

        let alphaA = createRepo(name: "Alpha", path: "/a", currentBranchDate: sameDate)
        let alphaB = createRepo(name: "Alpha", path: "/b", currentBranchDate: sameDate)

        XCTAssertEqual(GitRepository.compare(alphaA, alphaB, mode: .currentBranchCommit), .orderedAscending)
        XCTAssertEqual(GitRepository.compare(alphaB, alphaA, mode: .currentBranchCommit), .orderedDescending)
    }

    // Helper
    private func createRepo(
        name: String,
        path: String,
        currentBranchDate: Date? = nil,
        anyBranchDate: Date? = nil,
        fileModificationDate: Date? = nil,
        gitCommonDir: String? = nil
    ) -> GitRepository {
        GitRepository(
            path: path,
            name: name,
            currentBranch: "main",
            lastCommitOnCurrentBranch: currentBranchDate,
            lastCommitOnAnyBranch: anyBranchDate,
            lastFileModification: fileModificationDate,
            aheadCount: 0,
            behindCount: 0,
            hasUncommittedChanges: false,
            isClean: true,
            gitCommonDir: gitCommonDir,
            lastScanMarker: nil
        )
    }
}
