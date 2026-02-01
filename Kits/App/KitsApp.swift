import SwiftUI

@main
struct KitsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Menu bar only app - no main window
        // The AppDelegate handles everything
    }
}
