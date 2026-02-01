import Foundation
import os.log

extension Logger {
    static let subsystem = "es.makingvideogam.Kits"
    
    static let general = Logger(subsystem: subsystem, category: "General")
    static let gitScanner = Logger(subsystem: subsystem, category: "GitScanner")
    static let settings = Logger(subsystem: subsystem, category: "Settings")
    static let ui = Logger(subsystem: subsystem, category: "UI")
}

// Also print to console for debugging
func logDebug(_ message: String) {
    print("[Kits] \(message)")
}
