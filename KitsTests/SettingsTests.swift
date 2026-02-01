import XCTest
@testable import Kits

final class SettingsTests: XCTestCase {
    var mockUserDefaults: MockUserDefaults!
    var mockFileManager: MockFileManager!
    var settings: Settings!
    
    override func setUp() {
        super.setUp()
        mockUserDefaults = MockUserDefaults()
        mockFileManager = MockFileManager()
    }
    
    func testInitialization_FromUserDefaults() {
        let expectedPath = "/Users/test/projects"
        mockUserDefaults.storage[Constants.UserDefaultsKeys.rootFolderPath] = expectedPath
        mockFileManager.files[expectedPath] = true // Mark as exists
        
        settings = Settings(userDefaults: mockUserDefaults, fileManager: mockFileManager)
        
        XCTAssertEqual(settings.rootFolderPath, expectedPath)
    }
    
    func testSetRootFolderPath_ValidatesAndSavesToUserDefaults() {
        settings = Settings(userDefaults: mockUserDefaults, fileManager: mockFileManager)
        
        let validPath = "/Users/test/valid"
        mockFileManager.files[validPath] = true
        
        settings.rootFolderPath = validPath
        
        XCTAssertEqual(settings.rootFolderPath, validPath)
        XCTAssertEqual(mockUserDefaults.storage[Constants.UserDefaultsKeys.rootFolderPath] as? String, validPath)
    }
    
    func testSetRootFolderPath_RejectsInvalidPath() {
        settings = Settings(userDefaults: mockUserDefaults, fileManager: mockFileManager)
        
        let invalidPath = "/non/existent"
        // mockFileManager.files[invalidPath] is false by default
        
        settings.rootFolderPath = invalidPath
        
        XCTAssertNil(settings.rootFolderPath)
        XCTAssertNil(mockUserDefaults.storage[Constants.UserDefaultsKeys.rootFolderPath])
    }
    
    func testCommandValidation_AcceptsValid() throws {
        settings = Settings(userDefaults: mockUserDefaults, fileManager: mockFileManager)
        
        let validCommand = "code {path}"
        try settings.validateCommand(validCommand)
        XCTAssertNil(settings.commandError)
    }
    
    func testCommandValidation_RejectsDangerous() {
        settings = Settings(userDefaults: mockUserDefaults, fileManager: mockFileManager)
        
        let dangerousCommand = "code {path}; rm -rf /"
        XCTAssertThrowsError(try settings.validateCommand(dangerousCommand))
        XCTAssertNotNil(settings.commandError)
    }
}
