import XCTest
@testable import Kits

final class SettingsTests: XCTestCase {
    var mockSettingsStore: MockSettingsStore!
    var mockFileManager: MockFileManager!
    var settings: Settings!

    override func setUp() {
        super.setUp()
        mockSettingsStore = MockSettingsStore()
        mockFileManager = MockFileManager()
    }

    func testInitialization_FromSettingsFile() {
        let expectedPath = "/Users/test/projects"
        mockSettingsStore.snapshot = SettingsSnapshot(
            version: 1,
            rootFolderPath: expectedPath
        )
        mockFileManager.files[expectedPath] = true // Mark as exists

        settings = Settings(store: mockSettingsStore, fileManager: mockFileManager)

        XCTAssertEqual(settings.rootFolderPath, expectedPath)
    }

    func testInitialization_MigratesVersion0ToVersion1() {
        let expectedPath = "/Users/test/projects"
        mockSettingsStore.snapshot = SettingsSnapshot(
            version: 0,
            rootFolderPath: expectedPath,
            sortMode: SortMode.currentBranchCommit.rawValue,
            clickAction: RepoClickAction.finder.rawValue,
            customCommand: RepoClickAction.finder.commandTemplate,
            popoverWidth: 450,
            popoverHeight: 500,
            uiScale: 1.0
        )
        mockFileManager.files[expectedPath] = true

        settings = Settings(store: mockSettingsStore, fileManager: mockFileManager)

        XCTAssertEqual(settings.rootFolderPath, expectedPath)
        XCTAssertEqual(mockSettingsStore.snapshot?.version, 1)
        XCTAssertGreaterThanOrEqual(mockSettingsStore.saveCallCount, 1)
    }

    func testSetRootFolderPath_ValidatesAndSavesToSettingsFile() {
        settings = Settings(store: mockSettingsStore, fileManager: mockFileManager)

        let validPath = "/Users/test/valid"
        mockFileManager.files[validPath] = true

        settings.rootFolderPath = validPath

        XCTAssertEqual(settings.rootFolderPath, validPath)
        XCTAssertEqual(mockSettingsStore.snapshot?.rootFolderPath, validPath)
        XCTAssertEqual(mockSettingsStore.snapshot?.version, 1)
    }

    func testSetRootFolderPath_RejectsInvalidPath() {
        settings = Settings(store: mockSettingsStore, fileManager: mockFileManager)

        let invalidPath = "/non/existent"
        // mockFileManager.files[invalidPath] is false by default

        settings.rootFolderPath = invalidPath

        XCTAssertNil(settings.rootFolderPath)
        XCTAssertNil(mockSettingsStore.snapshot?.rootFolderPath)
    }

    func testCommandValidation_AcceptsValid() throws {
        settings = Settings(store: mockSettingsStore, fileManager: mockFileManager)

        let validCommand = "code {path}"
        try settings.validateCommand(validCommand)
        XCTAssertNil(settings.commandError)
    }

    func testCommandValidation_RejectsDangerous() {
        settings = Settings(store: mockSettingsStore, fileManager: mockFileManager)

        let dangerousCommand = "code {path}; rm -rf /"
        XCTAssertThrowsError(try settings.validateCommand(dangerousCommand))
        XCTAssertNotNil(settings.commandError)
    }
}
