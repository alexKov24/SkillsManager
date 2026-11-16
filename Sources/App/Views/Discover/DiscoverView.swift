import SwiftUI
import Domain

/// Organism: Search skills.sh and install a skill in one click
struct DiscoverView: View {
    @Bindable var library: SkillLibrary
    @State private var query: String

    init(library: SkillLibrary, query: String = "") {
        self.library = library
        _query = State(initialValue: query)
    }

    private let examples = ["pdf", "react", "testing", "design", "docs", "git"]

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            content
        }
        .task(id: query) {
            // Debounce typing; a newer query cancels this task
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await library.searchDirectory(query)
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(DS.Colors.textMuted)
            TextField("Search skills.sh", text: $query)
                .textFieldStyle(.plain)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.textPrimary)
            if library.isSearchingDirectory {
                ProgressView().controlSize(.small)
            }
            Link("skills.sh", destination: URL(string: "https://skills.sh")!)
                .font(DS.Typography.description)
                .foregroundStyle(DS.Colors.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(DS.Colors.bgInput)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Colors.border, lineWidth: 1))
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Results

    @ViewBuilder
    private var content: some View {
        if query.trimmingCharacters(in: .whitespaces).count < 2 {
            examplesView
        } else if library.directoryResults.isEmpty && !library.isSearchingDirectory {
            message("No skills found for \u{201C}\(query)\u{201D}")
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(library.directoryResults) { listing in
                        row(listing)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func row(_ listing: DirectorySkill) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(listing.skillId)
                    .font(DS.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)
                Text(listing.repo)
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(listing.installs.formatted(.number.notation(.compactName)))
                .font(DS.Typography.mono)
                .foregroundStyle(DS.Colors.textSecondary)
                .help("\(listing.installs.formatted()) installs on skills.sh")
                .frame(width: 60, alignment: .trailing)

            installButton(listing)
                .frame(width: 92, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Divider().overlay(DS.Colors.border) }
        .contentShape(Rectangle())
        .contextMenu {
            ForEach(Provider.allCases) { provider in
                Button("Install to \(provider.displayName)") {
                    Task { await library.install(listing, to: provider) }
                }
            }
            Divider()
            Link("Open on skills.sh", destination: URL(string: "https://skills.sh/\(listing.id)")!)
            Link("Open on GitHub", destination: URL(string: listing.repoUrl)!)
        }
    }

    @ViewBuilder
    private func installButton(_ listing: DirectorySkill) -> some View {
        if library.installingIds.contains(listing.id) {
            ProgressView().controlSize(.small)
        } else if library.isInstalled(listing) {
            Label("Installed", systemImage: "checkmark")
                .font(DS.Typography.description)
                .foregroundStyle(DS.Colors.green)
        } else {
            Button {
                Task { await library.install(listing, to: .claude) }
            } label: {
                Text("Install")
                    .font(DS.Typography.description)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(DS.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .buttonStyle(.plain)
            .help("Install to Claude Code (right-click for Codex)")
        }
    }

    // MARK: - Empty states

    private var examplesView: some View {
        VStack(spacing: 14) {
            Text("Search thousands of public skills and install one in a click.")
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.textSecondary)
            HStack(spacing: 8) {
                ForEach(examples, id: \.self) { example in
                    Button(example) { query = example }
                        .buttonStyle(.plain)
                        .font(DS.Typography.description)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(DS.Colors.bgCard)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(DS.Colors.border, lineWidth: 1))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(DS.Typography.body)
            .foregroundStyle(DS.Colors.textMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
