import Testing
import Foundation
import Mockable
@testable import App
@testable import Domain

@Suite
@MainActor
struct SkillLibraryDiscoverTests {

    @Test func `searching the directory shows its results`() async {
        let directory = MockSkillDirectory()
        given(directory).search(.value("pdf")).willReturn([listing("pdf")])
        let library = makeLibrary(directory: directory)

        await library.searchDirectory("pdf")

        #expect(library.directoryResults.map(\.skillId) == ["pdf"])
    }

    @Test func `queries shorter than two characters clear the results`() async {
        let library = makeLibrary(directory: MockSkillDirectory())

        await library.searchDirectory("p")

        #expect(library.directoryResults.isEmpty)
    }

    @Test func `installing from the directory fetches the skill from its repo and installs it`() async {
        let remote = Skill(
            id: "pdf", name: "pdf", description: "", version: "1.0.0", content: "",
            source: .remote(repoUrl: "https://github.com/anthropics/skills"), repoPath: "skills"
        )
        let repo = MockSkillRepository()
        given(repo).fetch(id: .value("pdf")).willReturn(remote)
        let installer = MockSkillInstaller()
        given(installer).install(.any, to: .value([.claude])).willProduce { skill, _ in skill.installing(for: .claude) }
        let library = makeLibrary(installer: installer, loader: repo)

        await library.install(listing("pdf"), to: .claude)

        #expect(library.localCatalog.skills.map(\.id) == ["pdf"])
        #expect(library.isInstalled(listing("pdf")))
    }

    @Test func `falls back to matching by name when the folder name differs`() async {
        let remote = Skill(
            id: "react-best-practices", name: "vercel-react-best-practices", description: "", version: "1.0.0",
            content: "", source: .remote(repoUrl: "https://github.com/vercel-labs/agent-skills")
        )
        let repo = MockSkillRepository()
        given(repo).fetch(id: .any).willReturn(nil)
        given(repo).fetchAll().willReturn([remote])
        let installer = MockSkillInstaller()
        given(installer).install(.any, to: .any).willProduce { skill, _ in skill.installing(for: .claude) }
        let library = makeLibrary(installer: installer, loader: repo)

        await library.install(listing("vercel-react-best-practices", repo: "vercel-labs/agent-skills"), to: .claude)

        #expect(library.localCatalog.skills.map(\.id) == ["react-best-practices"])
    }

    // MARK: - Helpers

    private func listing(_ skillId: String, repo: String = "anthropics/skills") -> DirectorySkill {
        DirectorySkill(repo: repo, skillId: skillId, installs: 100)
    }

    private func makeLibrary(
        directory: MockSkillDirectory = MockSkillDirectory(),
        installer: MockSkillInstaller = MockSkillInstaller(),
        loader: MockSkillRepository = MockSkillRepository()
    ) -> SkillLibrary {
        let local = MockSkillRepository()
        given(local).fetchAll().willReturn([])
        return SkillLibrary(
            localCatalog: SkillsCatalog(name: "Local", loader: local),
            installer: installer,
            catalogLoaderFactory: { _ in loader },
            directory: directory
        )
    }
}
