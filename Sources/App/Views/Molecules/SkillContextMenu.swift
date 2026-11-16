import SwiftUI
import Domain

/// Molecule: Right-click menu for one or more skills
struct SkillContextMenu: View {
    let skills: [Skill]
    @Bindable var library: SkillLibrary
    let onUninstall: ([Skill]) -> Void

    var body: some View {
        if skills.allSatisfy(\.isArchived) {
            Button {
                Task { await library.restore(skills) }
            } label: {
                Label(title("Restore"), systemImage: "arrow.uturn.backward")
            }
        } else {
            if skills.count == 1, let skill = skills.first, skill.isEditable {
                Button {
                    library.edit(skill)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Divider()
            }

            ForEach(Provider.allCases) { provider in
                let unlinked = skills.filter { !$0.isArchived && !$0.isInstalledFor(provider) }
                if !unlinked.isEmpty {
                    Button {
                        Task { await library.link(unlinked, to: provider) }
                    } label: {
                        Label("Link to \(provider.displayName)", systemImage: "link")
                    }
                }
            }

            let installed = skills.filter(\.isInstalled)
            if !installed.isEmpty {
                Divider()
                Button {
                    Task { await library.archive(installed) }
                } label: {
                    Label(title("Archive", count: installed.count), systemImage: "archivebox")
                }
                Button(role: .destructive) {
                    onUninstall(installed)
                } label: {
                    Label(title("Uninstall", count: installed.count) + "…", systemImage: "trash")
                }
            }
        }
    }

    private func title(_ action: String, count: Int? = nil) -> String {
        let count = count ?? skills.count
        return count > 1 ? "\(action) \(count) Skills" : action
    }
}
