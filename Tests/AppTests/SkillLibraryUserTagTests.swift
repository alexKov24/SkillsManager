import Testing
import Foundation
import Mockable
@testable import App
@testable import Domain

@Suite
@MainActor
struct SkillLibraryUserTagTests {

    // MARK: - Tag Counts

    @Test func `tagCounts includes file tags and custom tags`() {
        let skill = makeSkill(id: "my-skill", tags: ["development"])
        let localCatalog = makeLocalCatalog(skills: [skill])
        let mockInstaller = MockSkillInstaller()
        let skillTags = SkillTags()
        skillTags.createTag("favorites", for: "my-skill")

        let library = SkillLibrary(
            localCatalog: localCatalog,
            installer: mockInstaller,
            skillTags: skillTags
        )

        let counts = library.tagCounts

        #expect(counts["development"] == 1)
        #expect(counts["favorites"] == 1)
    }

    // MARK: - Filter

    @Test func `filteredSkills filters by custom tag`() {
        let skill1 = makeSkill(id: "skill-a", tags: ["development"])
        let skill2 = makeSkill(id: "skill-b", tags: ["testing"])
        let localCatalog = makeLocalCatalog(skills: [skill1, skill2])
        let mockInstaller = MockSkillInstaller()
        let skillTags = SkillTags()
        skillTags.createTag("favorites", for: "skill-a")

        let library = SkillLibrary(
            localCatalog: localCatalog,
            installer: mockInstaller,
            skillTags: skillTags
        )
        library.selectedTag = "favorites"

        #expect(library.filteredSkills.count == 1)
        #expect(library.filteredSkills.first?.id == "skill-a")
    }

    @Test func `filteredSkills filters by file tag`() {
        let skill = makeSkill(id: "skill-a", tags: ["development"])
        let localCatalog = makeLocalCatalog(skills: [skill])
        let mockInstaller = MockSkillInstaller()

        let library = SkillLibrary(
            localCatalog: localCatalog,
            installer: mockInstaller
        )
        library.selectedTag = "development"

        #expect(library.filteredSkills.count == 1)
    }

    // MARK: - Shared Across Catalogs

    @Test func `custom tag shows in both local and remote catalog views`() {
        let localSkill = makeSkill(id: "my-skill", tags: [])
        let remoteSkill = Skill(
            id: "my-skill", name: "my-skill", description: "", version: "1.0.0",
            content: "", source: .remote(repoUrl: "https://github.com/test/repo"),
            repoPath: "skills"
        )

        let localCatalog = makeLocalCatalog(skills: [localSkill])
        let remoteCatalog = makeRemoteCatalog(skills: [remoteSkill])
        let mockInstaller = MockSkillInstaller()
        let skillTags = SkillTags()
        skillTags.createTag("favorites", for: "my-skill")

        let library = SkillLibrary(
            localCatalog: localCatalog,
            remoteCatalogs: [remoteCatalog],
            installer: mockInstaller,
            skillTags: skillTags
        )

        // Local view
        library.selectedSource = .allInstalled
        #expect(library.tagCounts["favorites"] == 1)

        // Remote view
        library.selectedSource = .remote(repoId: remoteCatalog.id)
        #expect(library.tagCounts["favorites"] == 1)
    }

    // MARK: - Helpers

    private func makeSkill(id: String, tags: [String] = []) -> Skill {
        Skill(
            id: id, name: id, description: "Test", version: "1.0.0",
            content: "", source: .local(provider: .claude),
            installedProviders: [.claude], tags: tags
        )
    }

    private func makeLocalCatalog(skills: [Skill] = []) -> SkillsCatalog {
        let repo = MockSkillRepository()
        given(repo).fetchAll().willReturn(skills)
        let catalog = SkillsCatalog(name: "Local", loader: repo)
        catalog.skills = skills
        return catalog
    }

    private func makeRemoteCatalog(skills: [Skill] = []) -> SkillsCatalog {
        let repo = MockSkillRepository()
        given(repo).fetchAll().willReturn(skills)
        let catalog = SkillsCatalog(url: "https://github.com/test/repo", loader: repo)
        catalog.skills = skills
        return catalog
    }
}

@Suite
@MainActor
struct SkillLibraryUsageTests {

    @Test func `usage count comes from session logs by skill folder name`() async {
        let skill = Skill(
            id: "frontend-design", name: "Frontend Design", description: "", version: "1.0.0",
            content: "", source: .local(provider: .claude), installedProviders: [.claude]
        )
        let repo = MockSkillRepository()
        given(repo).fetchAll().willReturn([skill])
        let usage = MockSkillUsageRepository()
        given(usage).usageCounts().willReturn(["frontend-design": 7])

        let library = SkillLibrary(
            localCatalog: SkillsCatalog(name: "Local", loader: repo),
            installer: MockSkillInstaller(),
            usageRepository: usage
        )
        await library.loadSkills()

        #expect(library.usageCount(for: skill) == 7)
    }

    @Test func `unused skill has zero uses`() async {
        let skill = Skill(
            id: "never-used", name: "never-used", description: "", version: "1.0.0",
            content: "", source: .local(provider: .claude)
        )
        let library = SkillLibrary(
            localCatalog: SkillsCatalog(name: "Local", loader: MockSkillRepository()),
            installer: MockSkillInstaller()
        )

        #expect(library.usageCount(for: skill) == 0)
    }
}

@Suite
@MainActor
struct SkillLibraryHeaderTests {

    @Test func `tagCounts hides tags no skill in view has`() {
        let skill = Skill(
            id: "a", name: "a", description: "", version: "1.0.0", content: "",
            source: .local(provider: .claude), tags: ["development"]
        )
        let skillTags = SkillTags()
        skillTags.createTag("unused", for: "elsewhere")
        let library = SkillLibrary(
            localCatalog: catalog([skill]),
            installer: MockSkillInstaller(),
            skillTags: skillTags
        )

        #expect(library.tagCounts == ["development": 1])
    }

    @Test func `tagCounts keeps the selected tag so it can be cleared`() {
        let skillTags = SkillTags()
        skillTags.createTag("unused", for: "elsewhere")
        let library = SkillLibrary(
            localCatalog: catalog([]),
            installer: MockSkillInstaller(),
            skillTags: skillTags
        )
        library.selectedTag = "unused"

        #expect(library.tagCounts == ["unused": 0])
    }

    @Test func `list view sorts by uses, most used first`() async {
        let skills = ["rare", "popular", "unused"].map {
            Skill(id: $0, name: $0, description: "", version: "1.0.0", content: "", source: .local(provider: .claude))
        }
        let usage = MockSkillUsageRepository()
        given(usage).usageCounts().willReturn(["rare": 1, "popular": 9])
        let library = SkillLibrary(
            localCatalog: catalog(skills),
            installer: MockSkillInstaller(),
            usageRepository: usage
        )
        await library.loadSkills()
        library.viewMode = .list
        library.sortByUses = true

        #expect(library.filteredSkills.map(\.id) == ["popular", "rare", "unused"])
    }

    @Test func `grid view keeps catalog order`() async {
        let skills = ["rare", "popular"].map {
            Skill(id: $0, name: $0, description: "", version: "1.0.0", content: "", source: .local(provider: .claude))
        }
        let usage = MockSkillUsageRepository()
        given(usage).usageCounts().willReturn(["rare": 1, "popular": 9])
        let library = SkillLibrary(
            localCatalog: catalog(skills),
            installer: MockSkillInstaller(),
            usageRepository: usage
        )
        await library.loadSkills()
        library.sortByUses = true

        #expect(library.filteredSkills.map(\.id) == ["rare", "popular"])
    }

    private func catalog(_ skills: [Skill]) -> SkillsCatalog {
        let repo = MockSkillRepository()
        given(repo).fetchAll().willReturn(skills)
        let catalog = SkillsCatalog(name: "Local", loader: repo)
        catalog.skills = skills
        return catalog
    }
}
