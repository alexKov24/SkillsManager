import Foundation

/// An AI coding harness (CLI or editor agent) that may use skills
public struct Harness: Sendable, Identifiable, Equatable {
    public let name: String
    /// Folder that exists when the harness is installed (relative to home)
    public let folder: String
    /// Where its session logs live, if known (relative to home)
    public let logs: String?
    /// Whether SessionLogUsageRepository already counts its skill uses
    public let isCounted: Bool
    public var isInstalled = false

    public var id: String { name }
}

/// Infrastructure: Finds which harnesses are installed and builds a prompt
/// an LLM can follow to count skill uses for the ones we don't read yet.
public struct HarnessDetector: Sendable {

    private let homePath: String

    public init(homePath: String = FileManager.default.homeDirectoryForCurrentUser.path) {
        self.homePath = homePath
    }

    /// Harnesses checked, in display order
    public static let known: [Harness] = [
        Harness(name: "Claude Code", folder: ".claude", logs: ".claude/projects", isCounted: true),
        Harness(name: "Codex", folder: ".codex", logs: ".codex/sessions", isCounted: true),
        Harness(name: "Gemini CLI", folder: ".gemini", logs: ".gemini/tmp", isCounted: false),
        Harness(name: "Cursor", folder: ".cursor", logs: "Library/Application Support/Cursor", isCounted: false),
        Harness(name: "OpenCode", folder: ".local/share/opencode", logs: ".local/share/opencode", isCounted: false),
        Harness(name: "GitHub Copilot CLI", folder: ".copilot", logs: ".copilot/session-state", isCounted: false),
        Harness(name: "Pi", folder: ".pi", logs: ".pi/agent", isCounted: false),
        Harness(name: "Windsurf", folder: ".codeium/windsurf", logs: nil, isCounted: false),
        Harness(name: "Factory Droid", folder: ".factory", logs: nil, isCounted: false),
    ]

    public func detect() -> [Harness] {
        Self.known.map { harness in
            var harness = harness
            harness.isInstalled = FileManager.default.fileExists(atPath: "\(homePath)/\(harness.folder)")
            return harness
        }
    }

    /// Prompt for an LLM agent running on this Mac
    public func prompt(for harnesses: [Harness]) -> String {
        let uncounted = harnesses.filter { $0.isInstalled && !$0.isCounted }
        let list = uncounted.map { harness in
            let logs = harness.logs.map { ", logs probably in ~/\($0)" } ?? ""
            return "- \(harness.name) (installed at ~/\(harness.folder)\(logs))"
        }.joined(separator: "\n")

        return """
        I use agent skills (folders with a SKILL.md) across several AI coding tools on this Mac. \
        I want to know how many times each skill was actually used.

        Claude Code (~/.claude/projects/**/*.jsonl) and Codex (~/.codex/sessions/**/*.jsonl) are already counted. \
        Count skill uses for these other tools:
        \(list.isEmpty ? "- (none detected; check for any other AI coding tools I have installed)" : list)

        For each tool:
        1. Find where it stores session or conversation history (JSONL, JSON, SQLite, etc.). Confirm the path exists.
        2. Work out what a skill use looks like there: a skill tool call, a /skill-name command, or the agent reading a skills/<name>/SKILL.md file. \
        Don't count skills that are only listed in a system prompt or tool list.
        3. Count uses per skill name. If the same message appears in more than one file (forked or resumed sessions), count it once.

        Only read files; don't change or delete anything. Reply with:
        - per tool: the log path and the pattern you matched
        - a JSON object of total counts, like {"pdf": 12, "diagnose": 3}
        """
    }
}
