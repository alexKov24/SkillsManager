import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite
struct SkillArchiveTests {

    private let home: String
    private let paths: ProviderPathResolver
    private let installer: FileSystemSkillInstaller

    init() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        paths = ProviderPathResolver(homePath: home)
        installer = FileSystemSkillInstaller(pathResolver: paths)
    }

    @Test func `archive moves the skill folder out of every provider it is installed for`() async throws {
        try makeSkillFolder(.claude, "tidy")
        try makeSkillFolder(.codex, "tidy")
        let skill = localSkill("tidy", providers: [.claude, .codex])

        let archived = try await installer.archive(skill)

        #expect(archived.isArchived)
        #expect(archived.installedProviders == [.claude, .codex])
        #expect(!exists("\(paths.skillsPath(for: .claude))/tidy"))
        #expect(exists("\(paths.archivePath(for: .claude))/tidy/SKILL.md"))
        #expect(exists("\(paths.archivePath(for: .codex))/tidy/SKILL.md"))
    }

    @Test func `restore moves the skill back where it was`() async throws {
        try makeSkillFolder(.claude, "tidy")
        let archived = try await installer.archive(localSkill("tidy", providers: [.claude]))

        let restored = try await installer.restore(archived)

        #expect(!restored.isArchived)
        #expect(restored.isInstalledFor(.claude))
        #expect(exists("\(paths.skillsPath(for: .claude))/tidy/SKILL.md"))
        #expect(!exists("\(paths.archivePath(for: .claude))/tidy"))
    }

    @Test func `archive refuses to overwrite an already archived copy`() async throws {
        try makeSkillFolder(.claude, "tidy")
        try FileManager.default.createDirectory(atPath: "\(paths.archivePath(for: .claude))/tidy", withIntermediateDirectories: true)

        await #expect(throws: (any Error).self) {
            try await installer.archive(localSkill("tidy", providers: [.claude]))
        }
        #expect(exists("\(paths.skillsPath(for: .claude))/tidy/SKILL.md"))
    }

    @Test func `linking a local skill to another provider copies the whole folder`() async throws {
        try makeSkillFolder(.claude, "tidy")
        try "ref".write(toFile: "\(paths.skillsPath(for: .claude))/tidy/notes.md", atomically: true, encoding: .utf8)

        let linked = try await installer.install(localSkill("tidy", providers: [.claude]), to: [.codex])

        #expect(linked.installedProviders == [.claude, .codex])
        #expect(exists("\(paths.skillsPath(for: .codex))/tidy/SKILL.md"))
        #expect(exists("\(paths.skillsPath(for: .codex))/tidy/notes.md"))
    }

    @Test func `installed skills skip the archive folder and archived ones are read from it`() async throws {
        try makeSkillFolder(.claude, "kept")
        try makeSkillFolder(.claude, "tidy")
        _ = try await installer.archive(localSkill("tidy", providers: [.claude]))

        let installed = try await LocalSkillRepository(provider: .claude, pathResolver: paths).fetchAll()
        let archived = try await LocalSkillRepository(provider: .claude, pathResolver: paths, archived: true).fetchAll()

        #expect(installed.map(\.id) == ["kept"])
        #expect(archived.map(\.id) == ["tidy"])
        #expect(archived.allSatisfy { $0.isArchived })
    }

    // MARK: - Helpers

    private func makeSkillFolder(_ provider: Provider, _ id: String) throws {
        let dir = "\(paths.skillsPath(for: provider))/\(id)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try "---\nname: \(id)\ndescription: test\n---\n# \(id)".write(toFile: "\(dir)/SKILL.md", atomically: true, encoding: .utf8)
    }

    private func localSkill(_ id: String, providers: Set<Provider>) -> Skill {
        Skill(
            id: id, name: id, description: "test", version: "1.0.0", content: "# \(id)",
            source: .local(provider: providers.sorted { $0.rawValue < $1.rawValue }.first!),
            installedProviders: providers
        )
    }

    private func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
}
