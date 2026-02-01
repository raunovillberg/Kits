import XCTest
import AppKit
import Darwin

final class KitsUITests: XCTestCase {
    private var fixturesRoot: String?

    override func setUpWithError() throws {
        continueAfterFailure = false
        let fixtures = try FixturesFactory.make()
        fixturesRoot = fixtures.rootPath
    }

    override func tearDownWithError() throws {
        if let fixturesRoot {
            try? FileManager.default.removeItem(atPath: fixturesRoot)
        }
    }

    func testRepositoryListShowsRepositories() throws {
        let app = launchApp()

        let alphaRow = element(app, identifier: "repo-Alpha")
        XCTAssertTrue(alphaRow.waitForExistence(timeout: 10))

        let betaRow = element(app, identifier: "repo-Beta")
        XCTAssertTrue(betaRow.exists)

        let worktreeRow = element(app, identifier: "repo-Gamma-Worktree")
        XCTAssertTrue(worktreeRow.exists)

        let deltaRow = element(app, identifier: "repo-Delta")
        XCTAssertTrue(deltaRow.exists)
    }

    func testWorktreeBadgeIsVisible() throws {
        let app = launchApp()

        let worktreeRow = element(app, identifier: "repo-Gamma-Worktree")
        XCTAssertTrue(worktreeRow.waitForExistence(timeout: 10))
        XCTAssertTrue(worktreeRow.label.contains("Worktree"))
    }

    func testScreenshots() throws {
        let app = launchApp()
        try waitForRepoList(app: app)

        try takeScreenshot(app: app, name: "repo-list")

        let betaRow = element(app, identifier: "repo-Beta")
        if betaRow.waitForExistence(timeout: 5) {
            try takeElementScreenshot(element: betaRow, name: "dirty-repo")
        }

        let deltaRow = element(app, identifier: "repo-Delta")
        if deltaRow.waitForExistence(timeout: 5) {
            try takeElementScreenshot(element: deltaRow, name: "sync-status")
        }

        let worktreeRow = element(app, identifier: "repo-Gamma-Worktree")
        if worktreeRow.waitForExistence(timeout: 5) {
            try takeElementScreenshot(element: worktreeRow, name: "worktree-badge")
        }

        let currentBranchApp = launchApp(sortMode: "currentBranch")
        try waitForRepoList(app: currentBranchApp)
        try takeScreenshot(app: currentBranchApp, name: "sort-current-branch")

        let anyBranchApp = launchApp(sortMode: "anyBranch")
        try waitForRepoList(app: anyBranchApp)
        try takeScreenshot(app: anyBranchApp, name: "sort-any-branch")

        let fileModificationApp = launchApp(sortMode: "fileModification")
        try waitForRepoList(app: fileModificationApp)
        try takeScreenshot(app: fileModificationApp, name: "sort-file-modification")
    }

    private func launchApp(sortMode: String? = nil) -> XCUIApplication {
        terminateRunningApp()

        let app = XCUIApplication()
        app.launchEnvironment["KITS_UI_TESTING"] = "1"
        if let fixturesRoot {
            app.launchEnvironment["KITS_TEST_ROOT_PATH"] = fixturesRoot
        }
        if let sortMode {
            app.launchEnvironment["KITS_TEST_SORT_MODE"] = sortMode
        }
        app.launch()
        return app
    }

    private func terminateRunningApp() {
        let bundleIdentifier = "es.makingvideogam.Kits"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        for app in runningApps {
            _ = app.terminate()
            if !app.isTerminated {
                _ = app.forceTerminate()
            }
            if !app.isTerminated {
                kill(app.processIdentifier, SIGKILL)
            }
        }

        if !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty {
            runKillall()
        }

        let timeout = Date().addingTimeInterval(5)
        while Date() < timeout {
            if NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty {
                break
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
    }

    private func runKillall() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["-9", "Kits"]
        try? process.run()
        process.waitUntilExit()
    }

    private func takeScreenshot(app: XCUIApplication, name: String) throws {
        let window = app.windows.firstMatch
        let screenshot = window.exists ? window.screenshot() : XCUIScreen.main.screenshot()
        try saveScreenshot(screenshot, name: name)
    }

    private func takeElementScreenshot(element: XCUIElement, name: String) throws {
        let screenshot = element.screenshot()
        try saveScreenshot(screenshot, name: name)
    }

    private func saveScreenshot(_ screenshot: XCUIScreenshot, name: String) throws {
        let directory = try screenshotsDirectory()
        let url = directory.appendingPathComponent("\(name).png")
        try screenshot.pngRepresentation.write(to: url)
    }

    private func screenshotsDirectory() throws -> URL {
        let environment = ProcessInfo.processInfo.environment
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kits-screenshots", isDirectory: true)
        let directoryPath = environment["SCREENSHOTS_DIR"] ?? temporaryDirectory.path
        let url = URL(fileURLWithPath: directoryPath, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        print("Screenshots saved to: \(url.path)")
        return url
    }

    private func waitForRepoList(app: XCUIApplication) throws {
        let alphaRow = element(app, identifier: "repo-Alpha")
        XCTAssertTrue(alphaRow.waitForExistence(timeout: 10))
    }

    private func element(_ app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}

private enum FixturesFactory {
    struct Fixtures {
        let rootPath: String
    }

    static func make() throws -> Fixtures {
        let root = (NSTemporaryDirectory() as NSString).appendingPathComponent("kits-uitest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)

        let alpha = (root as NSString).appendingPathComponent("Alpha")
        let beta = (root as NSString).appendingPathComponent("Beta")
        let gamma = (root as NSString).appendingPathComponent("Gamma")
        let gammaWorktree = (root as NSString).appendingPathComponent("Gamma-Worktree")
        let delta = (root as NSString).appendingPathComponent("Delta")

        let now = Date()
        let alphaDate = now.addingTimeInterval(-18000)
        let betaDate = now.addingTimeInterval(-7200)
        let gammaDate = now.addingTimeInterval(-28800)

        try createRepo(at: alpha, commitMessage: "Initial commit", commitDate: alphaDate)
        try createRepo(at: beta, commitMessage: "Initial commit", commitDate: betaDate)
        try markDirty(at: alpha, modificationDate: now.addingTimeInterval(-60))
        try markDirty(at: beta, modificationDate: now.addingTimeInterval(-300))
        try createRepo(at: gamma, commitMessage: "Initial commit", commitDate: gammaDate)
        try addAnyBranchCommit(mainRepo: gamma, branch: "feature", commitDate: now.addingTimeInterval(-1800))
        try addWorktree(mainRepo: gamma, worktreePath: gammaWorktree, branch: "worktree")
        try createDivergedRepo(at: delta, root: root, baseDate: now.addingTimeInterval(-14400))

        return Fixtures(rootPath: root)
    }

    private static func createRepo(at path: String, commitMessage: String, commitDate: Date? = nil) throws {
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        try runGit(["init", "-b", "main"], in: path)
        let readme = (path as NSString).appendingPathComponent("README.md")
        try "# \(UUID().uuidString)".write(toFile: readme, atomically: true, encoding: .utf8)
        try runGit(["add", "README.md"], in: path)
        try runGit(["commit", "-m", commitMessage], in: path, commitDate: commitDate)
    }

    private static func markDirty(at path: String, modificationDate: Date? = nil) throws {
        let file = (path as NSString).appendingPathComponent("README.md")
        let existing = (try? String(contentsOfFile: file, encoding: .utf8)) ?? ""
        try (existing + "\nedit").write(toFile: file, atomically: true, encoding: .utf8)
        if let modificationDate {
            try FileManager.default.setAttributes([.modificationDate: modificationDate], ofItemAtPath: file)
        }
    }

    private static func addWorktree(mainRepo: String, worktreePath: String, branch: String) throws {
        try runGit(["worktree", "add", "-b", branch, worktreePath], in: mainRepo)
        let readme = (worktreePath as NSString).appendingPathComponent("README.md")
        try "worktree".write(toFile: readme, atomically: true, encoding: .utf8)
        try runGit(["add", "README.md"], in: worktreePath)
        try runGit(["commit", "-m", "Worktree commit"], in: worktreePath, commitDate: Date().addingTimeInterval(-10800))
    }

    private static func addAnyBranchCommit(mainRepo: String, branch: String, commitDate: Date) throws {
        try runGit(["checkout", "-b", branch], in: mainRepo)
        let file = (mainRepo as NSString).appendingPathComponent("feature.txt")
        try "feature".write(toFile: file, atomically: true, encoding: .utf8)
        try runGit(["add", "feature.txt"], in: mainRepo)
        try runGit(["commit", "-m", "Feature commit"], in: mainRepo, commitDate: commitDate)
        try runGit(["checkout", "main"], in: mainRepo)
    }

    private static func createDivergedRepo(at path: String, root: String, baseDate: Date) throws {
        let remotePath = (root as NSString).appendingPathComponent("Delta-remote.git")
        let clonePath = (NSTemporaryDirectory() as NSString).appendingPathComponent("kits-uitest-remote-clone-\(UUID().uuidString)")

        try createRepo(at: path, commitMessage: "Initial commit", commitDate: baseDate)
        try runGit(["init", "--bare", remotePath], in: root)
        try runGit(["remote", "add", "origin", remotePath], in: path)
        try runGit(["push", "-u", "origin", "main"], in: path)

        let aheadFile = (path as NSString).appendingPathComponent("ahead.txt")
        try "ahead".write(toFile: aheadFile, atomically: true, encoding: .utf8)
        try runGit(["add", "ahead.txt"], in: path)
        try runGit(["commit", "-m", "Ahead commit"], in: path, commitDate: baseDate.addingTimeInterval(1800))

        try runGit(["clone", remotePath, clonePath], in: root)
        let remoteFile = (clonePath as NSString).appendingPathComponent("remote.txt")
        try "remote".write(toFile: remoteFile, atomically: true, encoding: .utf8)
        try runGit(["add", "remote.txt"], in: clonePath)
        try runGit(["commit", "-m", "Remote commit"], in: clonePath, commitDate: baseDate.addingTimeInterval(3600))
        try runGit(["push"], in: clonePath)

        try runGit(["fetch", "origin"], in: path)
    }

    private static func gitExecutablePath() -> String {
        let candidates = [
            "/Applications/Xcode.app/Contents/Developer/usr/bin/git",
            "/usr/local/bin/git",
            "/opt/homebrew/bin/git",
            "/usr/bin/git"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return "/usr/bin/git"
    }

    private static func runGit(_ arguments: [String], in directory: String, commitDate: Date? = nil) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitExecutablePath())
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        var environment = [
            "GIT_AUTHOR_NAME": "Kits",
            "GIT_AUTHOR_EMAIL": "kits@example.com",
            "GIT_COMMITTER_NAME": "Kits",
            "GIT_COMMITTER_EMAIL": "kits@example.com"
        ]
        if let commitDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            let dateString = formatter.string(from: commitDate)
            environment["GIT_AUTHOR_DATE"] = dateString
            environment["GIT_COMMITTER_DATE"] = dateString
        }
        process.environment = environment
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "KitsUITests", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output])
        }
    }
}
