import Foundation
import Combine
import SwiftUI
import os.log
import Observation

// MARK: - GitScanner Class

@Observable
public class GitScanner {
    public var repositories: [GitRepository] = []
    public var isScanning = false {
        didSet {
            _isScanningSubject.send(isScanning)
        }
    }
    var lastScanDate: Date?
    var errorMessage: String?
    var totalReposToScan: Int = 0
    var scannedReposCount: Int = 0
    var discoveryFoldersScanned: Int = 0
    var currentScanningPath: String?
    
    private let _isScanningSubject = CurrentValueSubject<Bool, Never>(false)
    var isScanningPublisher: AnyPublisher<Bool, Never> {
        _isScanningSubject.eraseToAnyPublisher()
    }
    
    private final class RepositoryCache {
        private let lock = NSLock()
        private var cache: [String: GitRepository] = [:]
        
        func get(path: String) -> GitRepository? {
            lock.lock()
            defer { lock.unlock() }
            return cache[path]
        }
        
        func set(path: String, repository: GitRepository) {
            lock.lock()
            defer { lock.unlock() }
            cache[path] = repository
        }
        
        func clear() {
            lock.lock()
            defer { lock.unlock() }
            cache = [:]
        }
    }
    
    private let repositoryCache = RepositoryCache()
    private var scanTimer: Timer?
    private let fileManager: FileManagerProtocol
    private let shellExecutor: ShellExecutorProtocol
    private var cancellables = Set<AnyCancellable>()
    private var currentScanTask: Task<Void, Never>?
    private let settings: Settings
    private var isDeallocated = false
    private var scanStartTime: Date?
    
    // Async-safe storage for cached git path
    private actor GitPathStore {
        private var cached: String?
        func get() -> String? { cached }
        func set(_ value: String) { cached = value }
    }
    private let gitPathStore = GitPathStore()
    
    deinit {
        isDeallocated = true
        scanTimer?.invalidate()
        scanTimer = nil
        currentScanTask?.cancel()
        cancellables.removeAll()
    }
    
    /// Helper to run a process with timeout protection
    /// - Parameters:
    ///   - executable: Path to the executable
    ///   - arguments: Command arguments
    ///   - timeout: Maximum time to wait (default from Constants)
    /// - Returns: Tuple of (stdout string, termination status) or nil if failed/timeout
    private func runProcessWithTimeout(executable: String, arguments: [String], timeout: TimeInterval = Constants.Scanning.processTimeout) async -> (output: String, status: Int32)? {
        do {
            let result = try await shellExecutor.runProcess(
                executable: executable,
                arguments: arguments,
                environment: nil,
                currentDirectory: nil,
                timeout: timeout
            )
            
            if result.status != 0 {
                if !result.stderr.isEmpty {
                    Logger.gitScanner.error("Process \(executable) failed (exit code \(result.status)): \(result.stderr)")
                }
            }
            
            if !result.output.isEmpty {
                return (result.output, result.status)
            }
            
            // Return status even if output is empty if it was successful
            if result.status == 0 {
                return ("", 0)
            }
            
            return nil
        } catch {
            Logger.gitScanner.error("Failed to run process \(executable): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Checks if a file exists and is executable
    private func isExecutable(atPath path: String) -> Bool {
        return fileManager.fileExists(atPath: path) && fileManager.isExecutableFile(atPath: path)
    }
    
    /// Standard system directories for security auditing
    private static let standardSystemPaths = Constants.Paths.standardSystemPaths
    
    /// Checks if a path is within standard system directories
    private static func isInStandardLocation(_ path: String) -> Bool {
        let parentDir = (path as NSString).deletingLastPathComponent
        return standardSystemPaths.contains(parentDir)
    }
    
    private func currentGitPathDefaulting() async -> String {
        if let cached = await gitPathStore.get() {
            return cached
        }
        // Default fallback if discovery hasn't happened yet
        return "/usr/bin/git"
    }
    
    /// Async method to discover and set the git path
    public func discoverGitPath() async -> String {
        if let cached = await gitPathStore.get() {
            return cached
        }

        if ProcessInfo.processInfo.environment["KITS_UI_TESTING"] == "1" {
            let uiTestGitPaths = [
                "/Applications/Xcode.app/Contents/Developer/usr/bin/git",
                "/usr/bin/git"
            ]
            for path in uiTestGitPaths where fileManager.fileExists(atPath: path) && fileManager.isExecutableFile(atPath: path) {
                await gitPathStore.set(path)
                return path
            }
        }

        // 1. Try xcrun first
        if let result = await self.runProcessWithTimeout(executable: Constants.Paths.xcrunPath, arguments: ["-f", "git"]),
           result.status == 0,
           !result.output.isEmpty,
           fileManager.fileExists(atPath: result.output) && fileManager.isExecutableFile(atPath: result.output) {
            let path = result.output
            await gitPathStore.set(path)
            return path
        }
        
        // 2. Fallback to common paths
        for path in Constants.Paths.commonGitPaths {
            if fileManager.fileExists(atPath: path) && fileManager.isExecutableFile(atPath: path) {
                await gitPathStore.set(path)
                return path
            }
        }
        
        let defaultPath = "/usr/bin/git"
        await gitPathStore.set(defaultPath)
        return defaultPath
    }
    
    /// Thread-safe counter for discovery phase progress
    private final class DiscoveryCounter {
        private let lock = NSLock()
        private var count = 0
        private let scanner: GitScanner
        
        init(scanner: GitScanner) {
            self.scanner = scanner
        }
        
        func increment(path: String) {
            lock.lock()
            count += 1
            let currentCount = count
            lock.unlock()
            
            // Update UI every 10 folders to avoid too many main thread hops
            if currentCount % 10 == 0 {
                let folderName = (path as NSString).lastPathComponent
                Task { @MainActor in
                    scanner.discoveryFoldersScanned = currentCount
                    scanner.currentScanningPath = folderName
                }
            }
        }
        
        func getCount() -> Int {
            lock.lock()
            defer { lock.unlock() }
            return count
        }
        
        func finalize() {
            let finalCount = getCount()
            Task { @MainActor in
                scanner.discoveryFoldersScanned = finalCount
            }
        }
    }
    
    public init(settings: Settings, fileManager: FileManagerProtocol = FileManager.default, shellExecutor: ShellExecutorProtocol = ShellExecutor()) {
        self.settings = settings
        self.fileManager = fileManager
        self.shellExecutor = shellExecutor
        
        // Watch for root folder changes and restart scanning
        settings.rootFolderPathPublisher
            .dropFirst() // Skip initial value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newPath in
                self?.rootFolderChanged(to: newPath)
            }
            .store(in: &cancellables)
    }
    
    /// Called when user changes the root folder - cancels everything and starts fresh
    private func rootFolderChanged(to newPath: String?) {
        Logger.gitScanner.info("Root folder changed to: \(newPath ?? "nil") - cancelling scans and restarting")
        
        // Cancel any scheduled timer
        scanTimer?.invalidate()
        scanTimer = nil
        
        // Cancel any ongoing scan task
        currentScanTask?.cancel()
        currentScanTask = nil
        
        // Reset state and optionally restart using structured concurrency
        Task { [weak self] in
            guard let self = self else { return }
            
            // Reset state on main thread
            await MainActor.run {
                self.isScanning = false
                self.repositories = []
                self.errorMessage = nil
                self.totalReposToScan = 0
                self.scannedReposCount = 0
                self.discoveryFoldersScanned = 0
                self.lastScanDate = nil
            }
            self.repositoryCache.clear()
            
            // Start fresh scan if we have a new path
            if newPath != nil {
                // Small delay to let the UI clear and any cancellation propagate
                try? await Task.sleep(nanoseconds: UInt64(Constants.Scanning.scanRestartDelay * 1_000_000_000))
                guard !self.isDeallocated else { return }
                await MainActor.run {
                    self.startScanning()
                }
            }
        }
    }
    
    public func startScanning() {
        Logger.gitScanner.info("Starting scanner")
        performScan()
        scheduleNextScan()
    }
    
    public func stopScanning() {
        Logger.gitScanner.info("Stopping scanner")
        scanTimer?.invalidate()
        scanTimer = nil
    }
    
    func scheduleNextScan() {
        scanTimer?.invalidate()
        scanTimer = nil
        
        let interval = Settings.refreshIntervalSeconds
        Logger.gitScanner.info("Scheduling next scan in \(Int(interval / 60)) minutes")
        
        scanTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self = self, !self.isDeallocated else { return }
            self.performScan()
            self.scheduleNextScan()
        }
    }
    
    /// Sorts the repositories array according to the specified sort mode
    /// - Parameter mode: The sort mode to use for sorting
    @MainActor
    public func sortRepositories(by mode: SortMode) {
        repositories = repositories.sorted {
            GitRepository.compare($0, $1, mode: mode) == .orderedAscending
        }
    }
    
    /// Announces scan completion to VoiceOver users
    @MainActor
    private func announceScanCompletion(count: Int) {
        let announcement: String
        if count == 1 {
            announcement = NSLocalizedString("Scan complete. Found 1 repository.", comment: "Accessibility announcement for single repository found")
        } else {
            let format = NSLocalizedString("Scan complete. Found %d repositories.", comment: "Accessibility announcement for multiple repositories found")
            announcement = String(format: format, count)
        }
        
        // Post accessibility announcement for macOS
        // Use NSApp as the target element for the announcement
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
            NSAccessibility.NotificationUserInfoKey.announcement: announcement,
            NSAccessibility.NotificationUserInfoKey.priority: NSAccessibilityPriorityLevel.high
        ])
    }
    
    /// Refreshes only the first N repositories (for quick update when opening popover)
    public func refreshFirstNRepositories(count: Int) {
        guard !isScanning else { return }
        guard !repositories.isEmpty else { return }
        
        let reposToRefresh = Array(repositories.prefix(count))
        
        Task { [weak self] in
            guard let self = self else { return }
            
            await withTaskGroup(of: GitRepository?.self) { group in
                for repo in reposToRefresh {
                    group.addTask { [weak self] in
                        guard let self = self, !self.isDeallocated else { return nil }
                        return await self.scanRepository(at: repo.path)
                    }
                }
                
                while let updatedRepo = await group.next() {
                    // Check for cancellation
                    guard !Task.isCancelled, !self.isDeallocated else {
                        group.cancelAll()
                        return
                    }
                    
                    if let r = updatedRepo {
                        let finalRepo = r
                        await MainActor.run {
                            self.updateOrAddRepository(finalRepo)
                        }
                    }
                }
            }
        }
    }
    
    public func performScan(clearExisting: Bool = false) {
        guard !isScanning else {
            Logger.gitScanner.warning("Scan already in progress, skipping")
            return
        }
        
        guard let rootPath = settings.rootFolderPath else {
            Logger.gitScanner.info("No root folder set, skipping scan")
            return
        }
        
        isScanning = true
        errorMessage = nil
        totalReposToScan = 0
        scannedReposCount = 0
        discoveryFoldersScanned = 0
        currentScanningPath = nil
        
        if clearExisting {
            self.repositories = []
            self.repositoryCache.clear()
        }
        
        Logger.gitScanner.info("Starting live refresh scan at: \(rootPath)")
        
        currentScanTask = Task {
            scanStartTime = Date()
            
            // Discover git path once and cache it
            _ = await self.discoverGitPath()
            
            do {
                // 1. Discovery (parallel directory traversal)
                try Task.checkCancellation()
                let repoPaths = try await self.findGitRepositories(at: rootPath)
                
                try Task.checkCancellation()
                
                await MainActor.run {
                    self.totalReposToScan = repoPaths.count
                    self.scannedReposCount = 0
                    self.currentScanningPath = nil
                }
                
                // 2. Parallel scan
                let scannedReposResult = await withTaskGroup(of: GitRepository?.self) { group in
                    let maxConcurrent = ProcessInfo.processInfo.activeProcessorCount
                    var iterator = repoPaths.makeIterator()
                    var results: [GitRepository] = []
                    var isCancelled = false
                    
                    // Initial burst
                    for _ in 0..<maxConcurrent {
                        if let path = iterator.next() {
                            group.addTask { [weak self] in
                                guard let self = self, !self.isDeallocated else { return nil }
                                
                                // Check for scan timeout
                                if let startTime = self.scanStartTime, Date().timeIntervalSince(startTime) > Constants.Scanning.maxScanDuration {
                                    Logger.gitScanner.warning("Scan timeout reached during repository analysis")
                                    return nil
                                }
                                
                                return await self.scanRepository(at: path)
                            }
                        }
                    }
                    
                    // As one finishes, add another
                    while let repo = await group.next() {
                        // Check for cancellation or timeout
                        if Task.isCancelled || self.isDeallocated {
                            group.cancelAll()
                            isCancelled = true
                            break
                        }
                        
                        if let r = repo {
                            results.append(r)
                            let currentCount = results.count
                            await MainActor.run {
                                self.scannedReposCount = currentCount
                            }
                        }
                        
                        if let nextPath = iterator.next() {
                            group.addTask { [weak self] in
                                guard let self = self, !self.isDeallocated else { return nil }
                                
                                // Check for scan timeout
                                if let startTime = self.scanStartTime, Date().timeIntervalSince(startTime) > Constants.Scanning.maxScanDuration {
                                    return nil
                                }
                                
                                return await self.scanRepository(at: nextPath)
                            }
                        }
                    }
                    
                    // If cancelled, return empty to trigger cancellation handling
                    return isCancelled ? [] : results
                }
                
                // Check if we were cancelled or timed out during the scan
                try Task.checkCancellation()
                
                // 3. Sort and remove duplicates (if any)
                // Capture sort mode before entering detached task (Settings is MainActor-isolated)
                let sortMode = await MainActor.run { self.settings.sortMode }
                
                let finalUniqueRepos = await Task.detached {
                    var sortedRepos = scannedReposResult
                    
                    // Explicit sort with captured sort mode - avoids relying on global state
                    sortedRepos.sort { lhs, rhs in
                        let result = GitRepository.compare(lhs, rhs, mode: sortMode)
                        // For UI: alphabetical A-Z, dates newest-first
                        return result == .orderedAscending
                    }
                    
                    var unique: [GitRepository] = []
                    var seenPaths = Set<String>()
                    for repo in sortedRepos {
                        if !seenPaths.contains(repo.path) {
                            unique.append(repo)
                            seenPaths.insert(repo.path)
                        }
                    }
                    return unique
                }.value
                
                await MainActor.run {
                    // Check for reduced motion preference
                    let shouldAnimate = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                    
                    if shouldAnimate {
                        withAnimation(.easeInOut(duration: Constants.UI.animationDuration)) {
                            self.repositories = finalUniqueRepos
                        }
                    } else {
                        self.repositories = finalUniqueRepos
                    }
                    
                    self.lastScanDate = Date()
                    self.isScanning = false
                    self.scannedReposCount = 0
                    self.totalReposToScan = 0
                    self.currentScanningPath = nil
                    
                    // Announce scan completion to VoiceOver
                    self.announceScanCompletion(count: finalUniqueRepos.count)
                }
                
                if let startTime = scanStartTime {
                    let duration = Date().timeIntervalSince(startTime)
                    Logger.gitScanner.info("Scan completed in \(String(format: "%.2f", duration))s")
                }
                
            } catch is CancellationError {
                Logger.gitScanner.info("Scan was cancelled")
                // Don't update UI - the cancellation handler already reset state
            } catch let error as KitsError {
                Logger.gitScanner.error("Scan failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isScanning = false
                }
            } catch {
                Logger.gitScanner.error("Scan failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isScanning = false
                }
            }
            
            // Clear the task reference when done
            self.currentScanTask = nil
            self.scanStartTime = nil
        }
    }
    
    @MainActor
    private func updateOrAddRepository(_ repo: GitRepository) {
        self.scannedReposCount += 1
        
        if let index = self.repositories.firstIndex(where: { $0.path == repo.path }) {
            // Update in place
            self.repositories[index] = repo
        } else {
            // New repo found
            self.repositories.append(repo)
        }
    }
    
    /// Entry point for discovery - creates counter and starts parallel scan
    public func findGitRepositories(at rootPath: String) async throws -> [String] {
        // Normalize and validate root path
        let normalizedRoot = (rootPath as NSString).standardizingPath
        let rootURL = URL(fileURLWithPath: normalizedRoot).standardizedFileURL
        
        // Ensure root path exists and is directory
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: normalizedRoot, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            Logger.gitScanner.error("Invalid root path: \(rootPath)")
            throw KitsError.invalidRootPath(path: rootPath)
        }
        
        let counter = DiscoveryCounter(scanner: self)
        let results = try await findGitRepositories(
            at: normalizedRoot,
            rootURL: rootURL,
            currentDepth: 0,
            counter: counter
        )
        counter.finalize()
        return results
    }
    
    /// Internal recursive function with progress tracking and safety checks
    private func findGitRepositories(
        at path: String,
        rootURL: URL,
        currentDepth: Int,
        counter: DiscoveryCounter
    ) async throws -> [String] {
        // 1. Check scan timeout
        if let startTime = scanStartTime, Date().timeIntervalSince(startTime) > Constants.Scanning.maxScanDuration {
            Logger.gitScanner.warning("Scan timeout reached during discovery")
            return []
        }
        
        // 2. Limit recursion depth
        guard currentDepth < Constants.Scanning.maxDiscoveryDepth else {
            // Log at debug level to avoid noise in the console
            Logger.gitScanner.debug("Max depth reached at: \(path)")
            return []
        }
        
        // 3. Validate path is within root (Path Traversal Protection)
        let currentURL = URL(fileURLWithPath: path).standardizedFileURL
        guard currentURL.path.hasPrefix(rootURL.path) else {
            Logger.gitScanner.error("Path escape detected: \(path) is outside \(rootURL.path)")
            throw KitsError.pathEscapeAttempt(path: path)
        }
        
        // Count this folder
        counter.increment(path: path)
        
        // If we found a .git folder, we've found a repo.
        // We stop recursion here for this branch to avoid finding sub-repos
        // or worktrees that might be physically nested but shouldn't be treated as separate root entries.
        let gitPath = (path as NSString).appendingPathComponent(".git")
        if fileManager.fileExists(atPath: gitPath) {
            return [path]
        }
        
        let url = URL(fileURLWithPath: path)
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isAliasFileKey, .isMountTriggerKey, .isVolumeKey],
            options: [.skipsHiddenFiles]
        ) else {
            // If we can't read a directory, we just skip it rather than failing the whole scan
            Logger.gitScanner.warning("Could not read directory contents at: \(path)")
            return []
        }
        
        // Filter to directories only and skip symbolic links, aliases, and mount points
        let directories = contents.filter { item in
            fileManager.isDirectory(at: item)
        }
        
        // If no subdirectories, return empty
        if directories.isEmpty {
            return []
        }
        
        // Process subdirectories in parallel using TaskGroup
        var allRepos: [String] = []
        
        try Task.checkCancellation()
        
        await withTaskGroup(of: [String].self) { group in
            for item in directories {
                group.addTask { [weak self] in
                    guard let self = self, !self.isDeallocated else { return [] }
                    // Recursively search each subdirectory
                    // Use try? since we don't want one bad directory to kill the whole scan
                    return (try? await self.findGitRepositories(
                        at: item.path,
                        rootURL: rootURL,
                        currentDepth: currentDepth + 1,
                        counter: counter
                    )) ?? []
                }
            }
            
            // Collect results as they complete
            for await repos in group {
                // Check for cancellation
                guard !Task.isCancelled else {
                    group.cancelAll()
                    return
                }
                allRepos.append(contentsOf: repos)
            }
        }
        
        return allRepos
    }
    
    public func scanRepository(at path: String) async -> GitRepository? {
        // 0. Check if we can skip based on file system stats
        let gitPath = (path as NSString).appendingPathComponent(".git")
        let refsPath = (gitPath as NSString).appendingPathComponent("refs")
        let indexPath = (gitPath as NSString).appendingPathComponent("index")
        
        let refsDate = (try? fileManager.attributesOfItem(atPath: refsPath)[.modificationDate] as? Date) ?? .distantPast
        let indexDate = (try? fileManager.attributesOfItem(atPath: indexPath)[.modificationDate] as? Date) ?? .distantPast
        let maxGitDate = max(refsDate, indexDate)

        let sortMode = await MainActor.run { self.settings.sortMode }
        if sortMode != .fileModification {
            if let cached = repositoryCache.get(path: path), let marker = cached.lastScanMarker, marker >= maxGitDate {
                return cached
            }
        }

        let name = (path as NSString).lastPathComponent
        
        // 1. Get branch and status in one go
        // -b includes the branch line like "## main...origin/main [ahead 1, behind 2]"
        // --untracked-files=no speeds up large repos
        let statusResult = await runGitCommand(args: Constants.GitCommands.statusArgs, at: path)
        let statusLines = statusResult?.split(separator: "\n").map(String.init) ?? []
        
        var currentBranch = "unknown"
        var aheadCount = 0
        var behindCount = 0
        
        if let branchLine = statusLines.first, branchLine.hasPrefix("## ") {
            let branchInfo = branchLine.dropFirst(3)
            if let dotIndex = branchInfo.range(of: "...") {
                currentBranch = String(branchInfo[..<dotIndex.lowerBound])
                
                // Parse ahead/behind if present
                if let bracketIndex = branchInfo.range(of: "[") {
                    let syncInfo = branchInfo[bracketIndex.lowerBound...]
                    if let aheadMatch = syncInfo.range(of: "ahead (\\d+)", options: .regularExpression) {
                        let countStr = syncInfo[aheadMatch].replacingOccurrences(of: "ahead ", with: "")
                        aheadCount = Int(countStr) ?? 0
                    }
                    if let behindMatch = syncInfo.range(of: "behind (\\d+)", options: .regularExpression) {
                        let countStr = syncInfo[behindMatch].replacingOccurrences(of: "behind ", with: "")
                        behindCount = Int(countStr) ?? 0
                    }
                }
            } else {
                currentBranch = String(branchInfo).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Remaining lines (if any) are the changed files
        let hasUncommittedChanges = statusLines.count > 1
        let porcelainStatus = hasUncommittedChanges ? statusLines.dropFirst().joined(separator: "\n") : nil
        
        let currentCommitResult = await runGitCommand(args: Constants.GitCommands.currentCommitArgs, at: path)
        let lastCommitOnCurrentBranch = currentCommitResult.flatMap {
            parseGitDate($0, minimumTimestamp: Constants.FileSystem.minTimestampValue)
        }

        let anyCommitResult = await runGitCommand(args: Constants.GitCommands.anyCommitArgs, at: path)
        let lastCommitOnAnyBranch = anyCommitResult.flatMap {
            parseGitDate($0, minimumTimestamp: Constants.FileSystem.minTimestampValue)
        }
        
        let lastFileModification: Date?
        if sortMode == .fileModification {
            lastFileModification = await getLastWorkingTreeModification(at: path)
        } else {
            lastFileModification = await getLastFileModification(at: path, status: porcelainStatus)
        }
        let isClean = !hasUncommittedChanges && aheadCount == 0 && behindCount == 0
        
        // Detect worktrees
        let gitCommonDirResult = await runGitCommand(args: Constants.GitCommands.commonDirArgs, at: path)
        let gitCommonDir = gitCommonDirResult?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let repo = GitRepository(
            path: path,
            name: name,
            currentBranch: currentBranch,
            lastCommitOnCurrentBranch: lastCommitOnCurrentBranch,
            lastCommitOnAnyBranch: lastCommitOnAnyBranch,
            lastFileModification: lastFileModification,
            aheadCount: aheadCount,
            behindCount: behindCount,
            hasUncommittedChanges: hasUncommittedChanges,
            isClean: isClean,
            gitCommonDir: gitCommonDir,
            lastScanMarker: Date()
        )
        
        repositoryCache.set(path: path, repository: repo)
        
        return repo
    }
    
    private func getLastFileModification(at path: String, status: String?) async -> Date? {
        guard let status = status, !status.isEmpty else {
            let commitResult = await runGitCommand(args: Constants.GitCommands.currentCommitArgs, at: path)
            return commitResult.flatMap {
                parseGitDate($0, minimumTimestamp: Constants.FileSystem.minTimestampValue)
            }
        }
        
        var latestDate: Date?
        let lines = status.split(separator: "\n")
        for line in lines {
            let parts = line.split(separator: " ", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let filePath = String(parts[1]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            let fullPath = (path as NSString).appendingPathComponent(filePath)
            if let attrs = try? fileManager.attributesOfItem(atPath: fullPath), let modDate = attrs[.modificationDate] as? Date {
                // Sanity check: ignore dates that are clearly wrong (e.g. 1970 or far future)
                if isReasonableDate(modDate, minimumTimestamp: Constants.FileSystem.minValidTimestamp) {
                    if latestDate == nil || modDate > latestDate! { latestDate = modDate }
                }
            }
        }
        return latestDate
    }

    private func getLastWorkingTreeModification(at path: String) async -> Date? {
        await Task.yield()

        let rootURL = URL(fileURLWithPath: path)
        let latest = findLatestModificationDate(in: rootURL)
        return latest
    }

    private func findLatestModificationDate(in directory: URL) -> Date? {
        if Task.isCancelled { return nil }

        let keys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey]
        guard let items = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys, options: []) else {
            return nil
        }

        var latestDate: Date?
        for item in items {
            if item.lastPathComponent == Constants.FileSystem.gitDirectoryName {
                continue
            }

            let isDirectory = fileManager.isDirectory(at: item)
            if isDirectory {
                if let nestedDate = findLatestModificationDate(in: item) {
                    if latestDate == nil || nestedDate > latestDate! { latestDate = nestedDate }
                }
            } else if let values = try? item.resourceValues(forKeys: Set(keys)), let modDate = values.contentModificationDate {
                if isReasonableDate(modDate, minimumTimestamp: Constants.FileSystem.minValidTimestamp) {
                    if latestDate == nil || modDate > latestDate! { latestDate = modDate }
                }
            }
        }

        return latestDate
    }

    private func parseGitDate(_ rawTimestamp: String, minimumTimestamp: TimeInterval) -> Date? {
        let trimmed = rawTimestamp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let timestamp = TimeInterval(trimmed) else { return nil }

        let date = Date(timeIntervalSince1970: timestamp)
        guard isReasonableDate(date, minimumTimestamp: minimumTimestamp) else { return nil }

        return date
    }

    private func isReasonableDate(_ date: Date, minimumTimestamp: TimeInterval) -> Bool {
        let timestamp = date.timeIntervalSince1970
        let maxAllowedTimestamp = Date().addingTimeInterval(Constants.FileSystem.maxFutureTimestampSkew).timeIntervalSince1970

        return timestamp > minimumTimestamp && timestamp <= maxAllowedTimestamp
    }
    
    /// Runs a git command with timeout protection and path validation
    /// - Parameters:
    ///   - args: Git command arguments
    ///   - path: Working directory for the command (must be within root folder)
    ///   - timeout: Maximum time to wait for command completion (default: 30 seconds)
    /// - Returns: Command output if successful, nil on failure or timeout
    private func runGitCommand(args: [String], at path: String, timeout: TimeInterval = Constants.Scanning.gitCommandTimeout) async -> String? {
        do {
            return try await runGitCommandThrowing(args: args, at: path, timeout: timeout)
        } catch {
            // Logged inside runGitCommandThrowing
            return nil
        }
    }

    /// Internal git command runner that throws errors
    /// Uses withCheckedThrowingContinuation instead of semaphores to avoid thread pool starvation
    private func runGitCommandThrowing(args: [String], at path: String, timeout: TimeInterval = Constants.Scanning.gitCommandTimeout) async throws -> String? {
        // Validate path is within root folder (security) - prevent path traversal
        guard let rootPath = settings.rootFolderPath else {
            Logger.gitScanner.error("No root folder configured")
            return nil
        }
        
        let normalizedRoot = (rootPath as NSString).standardizingPath
        let normalizedPath = (path as NSString).standardizingPath
        let safeRoot = normalizedRoot.hasSuffix("/") ? normalizedRoot : normalizedRoot + "/"
        
        guard normalizedPath.hasPrefix(safeRoot) else {
            Logger.gitScanner.error("Path escape attempt blocked: \(path) (normalized: \(normalizedPath)) is not within \(safeRoot)")
            throw KitsError.pathEscapeAttempt(path: path)
        }
        
        let result = try await shellExecutor.runProcess(
            executable: await self.currentGitPathDefaulting(),
            arguments: args,
            environment: nil,
            currentDirectory: path,
            timeout: timeout
        )
        
        if result.status != 0 {
            Logger.gitScanner.error("Git command failed with exit code \(result.status): git \(args.joined(separator: " ")) at \(path), stderr: \(result.stderr)")
            throw KitsError.gitCommandFailed(args: args, exitCode: result.status, stderr: result.stderr)
        }
        
        return result.output
    }
    
}
