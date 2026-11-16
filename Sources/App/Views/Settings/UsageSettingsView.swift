import SwiftUI
import AppKit
import Infrastructure

/// Settings tab: which harnesses are installed, which ones the usage counter reads,
/// and a prompt to hand an LLM for the rest.
struct UsageSettingsView: View {
    @State private var harnesses = HarnessDetector().detect()
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Skill use counts come from the session logs on this Mac. Apps that run Claude Code or Codex (T3 Code, Orca) are counted too.")
                    .font(DS.Typography.description)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 0) {
                    ForEach(harnesses) { harness in
                        row(harness)
                        if harness != harnesses.last {
                            Divider().overlay(DS.Colors.border)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(DS.Colors.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.border, lineWidth: 1))

                VStack(alignment: .leading, spacing: 8) {
                    Button(action: copyPrompt) {
                        Label(copied ? "Copied" : "Copy prompt for an LLM", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(DS.Typography.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(DS.Colors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .buttonStyle(.plain)

                    Text("Paste it into Claude Code, Codex or another agent. It finds the logs of the tools marked \u{201C}not counted\u{201D} and reports per-skill counts. It only reads files.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(24)
        }
        .background(DS.Colors.bgPrimary)
        .onAppear { harnesses = HarnessDetector().detect() }
    }

    private func row(_ harness: Harness) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color(for: harness))
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 1) {
                Text(harness.name)
                    .font(DS.Typography.body)
                    .foregroundStyle(harness.isInstalled ? DS.Colors.textPrimary : DS.Colors.textMuted)
                if harness.isInstalled, let logs = harness.logs {
                    Text("~/\(logs)")
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(DS.Colors.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            Text(status(for: harness))
                .font(DS.Typography.caption)
                .foregroundStyle(color(for: harness))
        }
        .padding(.vertical, 8)
    }

    private func status(for harness: Harness) -> String {
        if !harness.isInstalled { return "Not found" }
        return harness.isCounted ? "Counted" : "Not counted"
    }

    private func color(for harness: Harness) -> Color {
        if !harness.isInstalled { return DS.Colors.textMuted }
        return harness.isCounted ? DS.Colors.green : DS.Colors.orange
    }

    private func copyPrompt() {
        let prompt = HarnessDetector().prompt(for: harnesses)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }
}
