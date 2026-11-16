import Testing
import Foundation
import Mockable
@testable import App
@testable import Domain

@Suite
@MainActor
struct SkillLibraryArchiveTests {

    @Test func `archive moves skills from installed to archived`() async {
        let a = skill("a"), b = skill("b"), c = skill("c")
        let installer = MockSkillInstaller()
        given(installer).archive(.any).willProduce { $0.archived() }
        let library = makeLibrary(installed: [a, b, c], installer: installer)

        await library.archive([a, b])

        #expect(library.localCatalog.skills.map(\.id) == ["c"])
        #expect(library.archivedCatalog.skills.map(\.id) == ["a", "b"])
        #expect(library.archivedCatalog.skills.allSatisfy { $0.isArchived })
    }

    @Test func `restore moves skills back to installed`() async {
        let a = skill("a").archived()
        let installer = MockSkillInstaller()
        given(installer).restore(.any).willProduce { $0.archived(false) }
        let library = makeLibrary(archived: [a], installer: installer)

        await library.restore([a])

        #expect(library.archivedCatalog.skills.isEmpty)
        #expect(library.localCatalog.skills.map(\.id) == ["a"])
    }

    @Test func `archived view shows archived skills`() {
        let library = makeLibrary(installed: [skill("a")], archived: [skill("b").archived()])

        library.selectedSource = .archived

        #expect(library.filteredSkills.map(\.id) == ["b"])
    }

    @Test func `uninstall removes skills from every provider`() async {
        let a = skill("a", providers: [.claude, .codex])
        let installer = MockSkillInstaller()
        given(installer).uninstall(.any, from: .any).willProduce { skill, provider in skill.uninstalling(from: provider) }
        let library = makeLibrary(installed: [a, skill("b")], installer: installer)

        await library.uninstall([a])

        #expect(library.localCatalog.skills.map(\.id) == ["b"])
    }

    @Test func `link adds a provider to each skill`() async {
        let a = skill("a"), b = skill("b")
        let installer = MockSkillInstaller()
        given(installer).install(.any, to: .value([.codex])).willProduce { skill, _ in skill.installing(for: .codex) }
        let library = makeLibrary(installed: [a, b], installer: installer)

        await library.link([a, b], to: .codex)

        #expect(library.localCatalog.skills.allSatisfy { $0.isInstalledFor(.codex) })
    }

    // MARK: - Multi-select

    @Test func `toggling adds and removes skills from the selection`() {
        let a = skill("a"), b = skill("b")
        let library = makeLibrary(installed: [a, b])

        library.select(a)
        library.toggleSelection(b)
        #expect(library.selectedSkills.map(\.id) == ["a", "b"])

        library.toggleSelection(a)
        #expect(library.selectedSkills.map(\.id) == ["b"])
    }

    @Test func `extending selects the range from the last clicked skill`() {
        let skills = ["a", "b", "c", "d"].map { skill($0) }
        let library = makeLibrary(installed: skills)

        library.select(skills[1])
        library.extendSelection(to: skills[3])

        #expect(library.selectedSkills.map(\.id) == ["b", "c", "d"])
    }

    @Test func `right-clicking outside the selection acts on that skill only`() {
        let a = skill("a"), b = skill("b"), c = skill("c")
        let library = makeLibrary(installed: [a, b, c])
        library.select(a)
        library.toggleSelection(b)

        #expect(library.skillsForContextMenu(on: b).map(\.id) == ["a", "b"])
        #expect(library.skillsForContextMenu(on: c).map(\.id) == ["c"])
    }

    // MARK: - Helpers

    private func skill(_ id: String, providers: Set<Provider> = [.claude]) -> Skill {
        Skill(
            id: id, name: id, description: "", version: "1.0.0", content: "",
            source: .local(provider: .claude), installedProviders: providers
        )
    }

    private func makeLibrary(
        installed: [Skill] = [], archived: [Skill] = [], installer: MockSkillInstaller = MockSkillInstaller()
    ) -> SkillLibrary {
        SkillLibrary(
            localCatalog: catalog(installed),
            archivedCatalog: catalog(archived),
            installer: installer
        )
    }

    private func catalog(_ skills: [Skill]) -> SkillsCatalog {
        let repo = MockSkillRepository()
        given(repo).fetchAll().willReturn(skills)
        let catalog = SkillsCatalog(name: "Local", loader: repo)
        catalog.skills = skills
        return catalog
    }
}
