import Foundation
import Domain

/// Resolves file system paths for providers
/// This is infrastructure knowledge - the domain model (Provider) shouldn't know about file paths
public struct ProviderPathResolver: Sendable {

    private let homePath: String

    public init() {
        self.homePath = FileManager.default.homeDirectoryForCurrentUser.path
    }

    /// Initialize with a custom home path (for testing)
    public init(homePath: String) {
        self.homePath = homePath
    }

    /// Returns the path where new skills are installed for the given provider
    public func skillsPath(for provider: Provider) -> String {
        switch provider {
        case .codex:
            return "\(homePath)/.codex/skills"
        case .claude:
            return "\(homePath)/.claude/skills"
        }
    }

    /// Every folder the provider loads skills from; the first is where new skills go.
    /// Codex also reads the shared `~/.agents/skills` folder.
    public func skillsPaths(for provider: Provider) -> [String] {
        switch provider {
        case .codex:
            return [skillsPath(for: .codex), "\(homePath)/.agents/skills"]
        case .claude:
            return [skillsPath(for: .claude)]
        }
    }

    /// Returns the folder that archived skills move to. Agents don't load skills from here:
    /// Claude Code only reads top-level skill folders, and Codex scans `~/.codex/skills`
    /// recursively, so its archive lives outside that tree.
    public func archivePath(for provider: Provider) -> String {
        switch provider {
        case .codex:
            return "\(homePath)/.codex/skills-disabled"
        case .claude:
            return "\(homePath)/.claude/skills/disabled"
        }
    }
}
