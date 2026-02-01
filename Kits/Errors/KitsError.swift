import Foundation

/// Errors specific to Kits application domains
enum KitsError: LocalizedError {
    // Git Scanner Errors
    case gitCommandFailed(args: [String], exitCode: Int32, stderr: String)
    case gitCommandTimeout(args: [String], timeout: TimeInterval)
    case invalidRootPath(path: String)
    case pathEscapeAttempt(path: String)
    
    // Launch at Login Errors
    case launchAgentCreationFailed(underlying: Error)
    case launchAgentRemovalFailed(underlying: Error)
    case launchAgentPathInvalid
    
    // Settings Errors
    case settingsSaveFailed(key: String, underlying: Error)
    case folderSelectionFailed(underlying: Error)
    
    // Command Execution
    case commandExecutionFailed(command: String, underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .gitCommandFailed(_, let code, _):
            let format = NSLocalizedString("Git command failed with exit code %d", comment: "Error message for git command failure")
            return String(format: format, code)
        case .gitCommandTimeout:
            return NSLocalizedString("Git command timed out", comment: "Error message for git command timeout")
        case .invalidRootPath(let path):
            let format = NSLocalizedString("Invalid root path: %@", comment: "Error message for invalid root path")
            return String(format: format, path)
        case .pathEscapeAttempt:
            return NSLocalizedString("Security: Blocked path escape attempt", comment: "Error message for security violation")
        case .launchAgentCreationFailed:
            return NSLocalizedString("Failed to enable launch at login", comment: "Error message for launch at login failure")
        case .launchAgentRemovalFailed:
            return NSLocalizedString("Failed to disable launch at login", comment: "Error message for launch at login removal failure")
        case .launchAgentPathInvalid:
            return NSLocalizedString("Invalid launch agent path", comment: "Error message for invalid launch agent path")
        case .settingsSaveFailed(let key, _):
            let format = NSLocalizedString("Failed to save setting: %@", comment: "Error message for settings save failure")
            return String(format: format, key)
        case .folderSelectionFailed:
            return NSLocalizedString("Failed to select folder", comment: "Error message for folder selection failure")
        case .commandExecutionFailed:
            return NSLocalizedString("Failed to execute command", comment: "Error message for command execution failure")
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .gitCommandFailed, .gitCommandTimeout:
            return NSLocalizedString("Check your repository status and git configuration.", comment: "Recovery suggestion for git errors")
        case .invalidRootPath:
            return NSLocalizedString("Please select a valid directory in settings.", comment: "Recovery suggestion for invalid path")
        case .launchAgentCreationFailed:
            return NSLocalizedString("Check disk permissions for ~/Library/LaunchAgents.", comment: "Recovery suggestion for launch at login failure")
        case .settingsSaveFailed:
            return NSLocalizedString("Try restarting the app.", comment: "Recovery suggestion for settings failure")
        default:
            return nil
        }
    }
}
