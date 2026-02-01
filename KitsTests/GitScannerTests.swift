import XCTest
@testable import Kits

final class GitScannerTests: XCTestCase {
    var scanner: GitScanner!
    var mockFileManager: MockFileManager!
    var mockShellExecutor: MockShellExecutor!
    var mockSettings: Settings!
    var mockUserDefaults: MockUserDefaults!
    
    override func setUp() {
        super.setUp()
        mockFileManager = MockFileManager()
        mockShellExecutor = MockShellExecutor()
        mockUserDefaults = MockUserDefaults()
        mockSettings = Settings(userDefaults: mockUserDefaults, fileManager: mockFileManager)
        scanner = GitScanner(settings: mockSettings, fileManager: mockFileManager, shellExecutor: mockShellExecutor)
    }
    
    func testDiscoverGitPath_XcrunSuccess() async {
        mockShellExecutor.handlers[Constants.Paths.xcrunPath] = { _, args in
            if args == ["-f", "git"] {
                return ("/usr/local/bin/git", 0, "")
            }
            return ("", 1, "")
        }
        mockFileManager.files["/usr/local/bin/git"] = true
        mockFileManager.executableFiles.insert("/usr/local/bin/git")
        
        let path = await scanner.discoverGitPath()
        XCTAssertEqual(path, "/usr/local/bin/git")
    }
    
    func testDiscoverGitPath_Fallback() async {
        mockShellExecutor.handlers[Constants.Paths.xcrunPath] = { _, _ in
            return ("", 1, "not found")
        }
        mockFileManager.files["/usr/bin/git"] = true
        mockFileManager.executableFiles.insert("/usr/bin/git")
        
        let path = await scanner.discoverGitPath()
        XCTAssertEqual(path, "/usr/bin/git")
    }
    
    func testScanRepository_Success() async {
        let rootPath = "/Users/test"
        let repoPath = "\(rootPath)/repo"
        
        // Must register root path BEFORE setting it on Settings (validation checks file exists)
        mockFileManager.files[rootPath] = true
        mockSettings.rootFolderPath = rootPath
        
        // Enable git path discovery
        mockShellExecutor.handlers[Constants.Paths.xcrunPath] = { _, _ in ("/usr/bin/git", 0, "") }
        mockFileManager.files["/usr/bin/git"] = true
        mockFileManager.executableFiles.insert("/usr/bin/git")
        
        mockShellExecutor.handlers["/usr/bin/git"] = { _, args in
            if args.contains("status") {
                return ("## main...origin/main [ahead 1, behind 2]\nM  file1.txt", 0, "")
            } else if args.contains("rev-parse") {
                return ("1600000000", 0, "")
            } else if args.contains("log") {
                return ("1600000000", 0, "")
            }
            return ("", 0, "")
        }
        
        // Mocking .git folder existence for the skip-scan check
        mockFileManager.files["\(repoPath)/.git"] = true
        mockFileManager.files["\(repoPath)/.git/refs"] = true
        mockFileManager.files["\(repoPath)/.git/index"] = true
        // Need to mark the repo path itself as existing for fileExists checks
        mockFileManager.files[repoPath] = true
        
        let repo = await scanner.scanRepository(at: repoPath)
        
        XCTAssertNotNil(repo)
        XCTAssertEqual(repo?.name, "repo")
        XCTAssertEqual(repo?.currentBranch, "main")
        XCTAssertEqual(repo?.aheadCount, 1)
        XCTAssertEqual(repo?.behindCount, 2)
        XCTAssertTrue(repo?.hasUncommittedChanges ?? false)
        XCTAssertFalse(repo?.isClean ?? true)
    }
    
    func testFindGitRepositories_Recursive() async throws {
        let rootPath = "/Users/test/projects"
        
        // Must register root path BEFORE setting it on Settings
        mockFileManager.files[rootPath] = true
        mockSettings.rootFolderPath = rootPath
        
        let repo1 = URL(fileURLWithPath: "\(rootPath)/repo1")
        let repo2 = URL(fileURLWithPath: "\(rootPath)/subdir/repo2")
        let nonRepo = URL(fileURLWithPath: "\(rootPath)/not-a-repo")
        
        mockFileManager.directories[rootPath] = [repo1, URL(fileURLWithPath: "\(rootPath)/subdir"), nonRepo]
        mockFileManager.directories["\(rootPath)/subdir"] = [repo2]
        
        mockFileManager.files["\(rootPath)/repo1/.git"] = true
        mockFileManager.files["\(rootPath)/subdir/repo2/.git"] = true
        
        // Need to mock isDirectory for findGitRepositories
        mockFileManager.files["\(rootPath)/repo1"] = true
        mockFileManager.files["\(rootPath)/subdir"] = true
        mockFileManager.files["\(rootPath)/subdir/repo2"] = true
        mockFileManager.files["\(rootPath)/not-a-repo"] = true
        
        let foundRepos = try await scanner.findGitRepositories(at: rootPath)
        
        XCTAssertEqual(foundRepos.count, 2)
        XCTAssertTrue(foundRepos.contains("\(rootPath)/repo1"))
        XCTAssertTrue(foundRepos.contains("\(rootPath)/subdir/repo2"))
        XCTAssertFalse(foundRepos.contains("\(rootPath)/not-a-repo"))
    }
    
    func testPathTraversalProtection() async {
        let rootPath = "/Users/test/projects"
        
        // Must register root path BEFORE setting it on Settings
        mockFileManager.files[rootPath] = true
        mockSettings.rootFolderPath = rootPath
        
        // Attempt to scan a repository outside the root folder
        // This tests the protection in runGitCommandThrowing which validates
        // that the scanned path is within settings.rootFolderPath
        let outsidePath = "/Users/test/other/repo"
        
        // Mark outside path as having a .git folder so scanRepository tries to run git commands
        mockFileManager.files[outsidePath] = true
        mockFileManager.files["\(outsidePath)/.git"] = true
        mockFileManager.files["\(outsidePath)/.git/refs"] = true
        mockFileManager.files["\(outsidePath)/.git/index"] = true
        
        // Set up git so if it runs, it would succeed
        mockShellExecutor.handlers["/usr/bin/git"] = { _, _ in
            ("## main", 0, "")
        }
        
        // scanRepository should return nil because runGitCommand fails the path check
        let repo = await scanner.scanRepository(at: outsidePath)
        
        // The repo should still be created but with "unknown" branch since git commands fail
        XCTAssertEqual(repo?.currentBranch, "unknown", "Git commands should not execute for paths outside root folder")
    }
    
    func testGitCommandTimeout() async {
        let rootPath = "/Users/test"
        let repoPath = "\(rootPath)/repo"
        
        // Must register root path BEFORE setting it on Settings
        mockFileManager.files[rootPath] = true
        mockSettings.rootFolderPath = rootPath
        
        mockShellExecutor.handlers["/usr/bin/git"] = { _, _ in
            // Simulate a timeout by throwing an error (or just returning something that triggers our logic)
            // In our updated GitScanner, the ShellExecutor handles the timeout and throws.
            // But here we want to see how GitScanner handles it.
            return ("", 1, "timeout")
        }
        
        mockFileManager.files["\(repoPath)/.git"] = true
        mockFileManager.files["\(repoPath)/.git/refs"] = true
        mockFileManager.files["\(repoPath)/.git/index"] = true

        let repo = await scanner.scanRepository(at: repoPath)
        
        // If git status fails, repo will have "unknown" branch and no changes.
        XCTAssertEqual(repo?.currentBranch, "unknown")
    }
}
