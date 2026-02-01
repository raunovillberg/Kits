import Foundation

public enum RepoClickAction: String, CaseIterable, Identifiable {
    case finder = "finder"
    case fork = "fork"
    case tower = "tower"
    case vscode = "vscode"
    case iterm2 = "iterm2"
    case terminal = "terminal"
    case custom = "custom"
    
    public var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .finder: return NSLocalizedString("Open in Finder", comment: "")
        case .fork: return NSLocalizedString("Open in Fork", comment: "")
        case .tower: return NSLocalizedString("Open in Tower", comment: "")
        case .vscode: return NSLocalizedString("Open in VS Code", comment: "")
        case .iterm2: return NSLocalizedString("Open in iTerm2", comment: "")
        case .terminal: return NSLocalizedString("Open in Terminal", comment: "")
        case .custom: return NSLocalizedString("Custom command", comment: "")
        }
    }
    
    var commandTemplate: String {
        switch self {
        case .finder: return "open {path}"
        case .fork: return "fork {path}"
        case .tower: return "open -a Tower {path}"
        case .vscode: return "open -a \"Visual Studio Code\" {path}"
        case .iterm2: return "open -a iTerm {path}"
        case .terminal: return "open -a Terminal {path}"
        case .custom: return ""
        }
    }
}
