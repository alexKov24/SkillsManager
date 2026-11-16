import Foundation

/// A skill listed in a public directory (skills.sh), not yet fetched
public struct DirectorySkill: Sendable, Equatable, Identifiable, Hashable {
    /// GitHub "owner/repo" the skill lives in
    public let repo: String
    /// Skill name in the directory, usually its folder name
    public let skillId: String
    /// How many times people installed it
    public let installs: Int

    public init(repo: String, skillId: String, installs: Int) {
        self.repo = repo
        self.skillId = skillId
        self.installs = installs
    }

    public var id: String { "\(repo)/\(skillId)" }

    public var repoUrl: String { "https://github.com/\(repo)" }
}
