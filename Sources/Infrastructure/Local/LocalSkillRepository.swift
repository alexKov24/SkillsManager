import Foundation
import Domain

/// Repository for reading locally installed skills
public final class LocalSkillRepository: SkillRepository, @unchecked Sendable {
    private let provider: Provider
    private let fileManager: FileManagerProtocol
    private let skillsPaths: [String]
    private let archivePath: String
    private let archived: Bool

    /// - Parameter archived: read archived skills instead of installed ones
    public init(
        provider: Provider,
        fileManager: FileManagerProtocol = RealFileManager.shared,
        pathResolver: ProviderPathResolver = ProviderPathResolver(),
        archived: Bool = false
    ) {
        self.provider = provider
        self.fileManager = fileManager
        self.archivePath = pathResolver.archivePath(for: provider)
        self.skillsPaths = archived ? [archivePath] : pathResolver.skillsPaths(for: provider)
        self.archived = archived
    }

    /// Fetch all skills from the local skills directory (recursively)
    public func fetchAll() async throws -> [Skill] {
        var skills: [Skill] = []
        for path in skillsPaths where fileManager.fileExists(atPath: path) {
            findSkillsRecursively(in: path, relativePath: "", skills: &skills)
        }
        // A skill in two folders (e.g. ~/.codex/skills and ~/.agents/skills) shows once
        var seen = Set<String>()
        skills = skills.filter { seen.insert($0.uniqueKey).inserted }

        return skills.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Recursively search for SKILL.md files in directories.
    /// Uses relative path as skill ID to match remote skill IDs.
    private func findSkillsRecursively(in path: String, relativePath: String, skills: inout [Skill], maxDepth: Int = 5, currentDepth: Int = 0) {
        guard currentDepth < maxDepth else { return }

        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return
        }

        // Hidden folders hold built-ins and tooling (.system, .git), not the user's skills
        for item in contents where !item.hasPrefix(".") {
            let itemPath = (path as NSString).appendingPathComponent(item)
            let itemRelativePath = relativePath.isEmpty ? item : "\(relativePath)/\(item)"

            // Skip non-directories, and the archive folder when reading installed skills
            guard fileManager.isDirectory(atPath: itemPath), archived || itemPath != archivePath else {
                continue
            }

            // Check for SKILL.md in this directory
            let skillFilePath = (itemPath as NSString).appendingPathComponent("SKILL.md")

            if let data = fileManager.contents(atPath: skillFilePath),
               let content = String(data: data, encoding: .utf8) {
                // Found a skill!
                // Check for .skill-id metadata which stores uniqueKey (repoPath/id)
                let metadataPath = (itemPath as NSString).appendingPathComponent(".skill-id")
                let skillId: String
                let repoPath: String?

                if let idData = fileManager.contents(atPath: metadataPath),
                   let storedKey = String(data: idData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !storedKey.isEmpty {
                    // Parse uniqueKey: "repoPath/id" or just "id"
                    if let lastSlash = storedKey.lastIndex(of: "/") {
                        repoPath = String(storedKey[..<lastSlash])
                        skillId = String(storedKey[storedKey.index(after: lastSlash)...])
                    } else {
                        skillId = storedKey
                        repoPath = nil
                    }
                } else {
                    skillId = item  // Fall back to folder name
                    repoPath = nil
                }

                do {
                    let skill = try SkillParser.parse(
                        content: content,
                        id: skillId,
                        source: .local(provider: provider),
                        repoPath: repoPath
                    )
                    skills.append(skill.archived(archived))
                } catch {
                    // Skip invalid skills
                }
                // Don't recurse into skill directories (a skill folder is a leaf)
            } else {
                // No SKILL.md here, search subdirectories
                findSkillsRecursively(in: itemPath, relativePath: itemRelativePath, skills: &skills, maxDepth: maxDepth, currentDepth: currentDepth + 1)
            }
        }
    }

    /// Fetch a specific skill by ID
    public func fetch(id: String) async throws -> Skill? {
        let files = skillsPaths.map { ($0 as NSString).appendingPathComponent("\(id)/SKILL.md") }
        guard let data = files.lazy.compactMap({ self.fileManager.contents(atPath: $0) }).first,
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        return try SkillParser.parse(
            content: content,
            id: id,
            source: .local(provider: provider)
        )
    }
}
