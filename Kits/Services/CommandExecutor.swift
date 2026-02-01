import Foundation
import os.log

// MARK: - Command Executor Protocol

/// Protocol for executing shell commands with proper escaping and validation
public protocol CommandExecutorProtocol {
    /// Executes a command template with a path substitution
    /// - Parameters:
    ///   - commandTemplate: The command template containing {path} placeholder
    ///   - path: The repository path to substitute (will be properly escaped)
    ///   - completion: Called when execution completes with success or failure
    func execute(commandTemplate: String, path: String, completion: ((Result<Void, Error>) -> Void)?)
}

// MARK: - Command Executor Implementation

/// Executes shell commands safely with path escaping and validation
public final class CommandExecutor: CommandExecutorProtocol {
    
    // MARK: - Types
    
    public enum ExecutionError: LocalizedError {
        case missingPathPlaceholder
        case processCreationFailed(Error)
        case commandFailed(exitCode: Int32)
        
        public var errorDescription: String? {
            switch self {
            case .missingPathPlaceholder:
                return "Command template missing {path} placeholder"
            case .processCreationFailed(let error):
                return "Failed to create process: \(error.localizedDescription)"
            case .commandFailed(let exitCode):
                return "Command failed with exit code: \(exitCode)"
            }
        }
    }
    
    // MARK: - Properties
    
    private let shellPath: String
    private let logger: Logger
    private let shellExecutor: ShellExecutorProtocol
    
    // MARK: - Initialization
    
    /// Creates a new command executor
    /// - Parameters:
    ///   - shellPath: Path to the shell executable (default: /bin/zsh)
    ///   - logger: Logger for error reporting (default: general logger)
    ///   - shellExecutor: Executor for shell commands (default: ShellExecutor)
    public init(
        shellPath: String = "/bin/zsh",
        logger: Logger? = nil,
        shellExecutor: ShellExecutorProtocol = ShellExecutor()
    ) {
        self.shellPath = shellPath
        self.logger = logger ?? Logger.general
        self.shellExecutor = shellExecutor
    }
    
    // MARK: - Public Methods
    
    public func execute(
        commandTemplate: String,
        path: String,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        // Validate the command template contains the placeholder
        guard commandTemplate.contains("{path}") else {
            logger.error("Invalid command template: missing {path} placeholder")
            completion?(.failure(ExecutionError.missingPathPlaceholder))
            return
        }
        
        // Properly escape the path to prevent command injection
        let escapedPath = Self.escapePath(path)
        let command = commandTemplate.replacingOccurrences(of: "{path}", with: escapedPath)
        
        // Fire and forget - don't block the UI
        Task {
            do {
                // Use --login to ensure the user's full shell environment (and PATH) is loaded
                let result = try await shellExecutor.runProcess(
                    executable: shellPath,
                    arguments: ["--login", "-c", command],
                    environment: nil,
                    currentDirectory: nil,
                    timeout: 60 // Arbitrary timeout for user actions
                )
                
                if result.status != 0 {
                    self.logger.error("Command failed with exit code: \(result.status)")
                    completion?(.failure(ExecutionError.commandFailed(exitCode: result.status)))
                } else {
                    completion?(.success(()))
                }
            } catch {
                self.logger.error("Failed to run command: \(error.localizedDescription)")
                completion?(.failure(ExecutionError.processCreationFailed(error)))
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Escapes a file path for safe shell usage
    /// - Parameter path: The raw file path
    /// - Returns: The escaped path safe for shell injection
    private static func escapePath(_ path: String) -> String {
        // Wrap in single quotes - escapes everything except single quotes themselves
        // To escape a single quote: end quote, add escaped quote, start quote
        // Example: /Users/dev/repo's -> '/Users/dev/repo'\''s'
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}

// MARK: - Mock Implementation for Testing

#if DEBUG
public final class MockCommandExecutor: CommandExecutorProtocol {
    public var lastCommandTemplate: String?
    public var lastPath: String?
    public var shouldSucceed = true
    public var simulatedError: Error?
    
    public init() {}
    
    public func execute(
        commandTemplate: String,
        path: String,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        lastCommandTemplate = commandTemplate
        lastPath = path
        
        if let error = simulatedError {
            completion?(.failure(error))
        } else if shouldSucceed {
            completion?(.success(()))
        } else {
            completion?(.failure(CommandExecutor.ExecutionError.commandFailed(exitCode: 1)))
        }
    }
}
#endif
