import Foundation
import Mockable

/// Reads how many times each skill was used by AI agents
@Mockable
public protocol SkillUsageRepository: Sendable {
    /// Use counts keyed by skill folder name
    func usageCounts() async -> [String: Int]
}
