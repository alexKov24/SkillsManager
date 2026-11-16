import Foundation
import Mockable

/// A public directory of skills people can search and install from
@Mockable
public protocol SkillDirectory: Sendable {
    /// Skills matching the query, most installed first
    func search(_ query: String) async throws -> [DirectorySkill]
}
