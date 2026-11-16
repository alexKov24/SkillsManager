import Foundation
import Domain

/// Infrastructure: Counts skill uses from Claude Code and Codex session logs.
///
/// Apps that wrap these CLIs (T3 Code, Orca, ...) write to the same logs.
/// - Claude (`~/.claude/projects/**/*.jsonl`): `Skill` tool calls and `/skill` slash commands
/// - Codex (`~/.codex/sessions/**/*.jsonl`): tool calls that read a `skills/<name>/SKILL.md`
///
/// Forked sessions copy earlier messages, so each use is counted once per message id.
public struct SessionLogUsageRepository: SkillUsageRepository {

    private let claudeDir: URL?
    private let codexDir: URL?

    public init(
        claudeDir: URL? = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects"),
        codexDir: URL? = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions")
    ) {
        self.claudeDir = claudeDir
        self.codexDir = codexDir
    }

    public func usageCounts() async -> [String: Int] {
        var seen = Set<String>()
        var counts: [String: Int] = [:]

        func count(_ name: String, id: String?) {
            let skill = name.split(separator: ":").last.map(String.init) ?? name
            guard seen.insert("\(id ?? UUID().uuidString)|\(skill)").inserted else { return }
            counts[skill, default: 0] += 1
        }

        for file in Self.logFiles(in: claudeDir) {
            for line in Self.lines(in: file, containing: [#""name":"Skill","input":{"skill":""#, "<command-name>/"]) {
                let id = Self.firstMatch(of: Self.uuid, in: line)
                for name in Self.matches(of: Self.skillToolCall, in: line) {
                    count(name, id: id)
                }
                // Slash commands typed by the user (tool output can quote them too)
                if line.contains(#""type":"user""#), !line.contains(#""tool_use_id""#) {
                    for name in Self.matches(of: Self.slashCommand, in: line) {
                        count(name, id: id)
                    }
                }
            }
        }

        for file in Self.logFiles(in: codexDir) {
            for line in Self.lines(in: file, containing: ["SKILL.md"]) where line.contains(#""type":"function_call""#) {
                let id = Self.firstMatch(of: Self.callId, in: line)
                for name in Self.matches(of: Self.skillFileRead, in: line) {
                    count(name, id: id)
                }
            }
        }

        return counts
    }

    // MARK: - Patterns

    private static var skillToolCall: Regex<(Substring, Substring)> { #/"name":"Skill","input":\{"skill":"([^"]+)"/# }
    private static var slashCommand: Regex<(Substring, Substring)> { #/<command-name>/?([A-Za-z0-9_.:-]+)</command-name>/# }
    private static var skillFileRead: Regex<(Substring, Substring)> { #//skills/([A-Za-z0-9_.-]+)/SKILL\.md/# }
    private static var uuid: Regex<(Substring, Substring)> { #/"uuid":"([^"]+)"/# }
    private static var callId: Regex<(Substring, Substring)> { #/"call_id":"([^"]+)"/# }

    private static func matches(of regex: Regex<(Substring, Substring)>, in line: String) -> [String] {
        line.matches(of: regex).map { String($0.output.1) }
    }

    private static func firstMatch(of regex: Regex<(Substring, Substring)>, in line: String) -> String? {
        line.firstMatch(of: regex).map { String($0.output.1) }
    }

    // MARK: - Files

    private static func logFiles(in dir: URL?) -> [URL] {
        guard let dir,
              let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "jsonl" }
    }

    /// Lines of a file that contain any marker. Scans raw bytes so only matching lines are decoded.
    /// Plain reads, not mmap: page faults made mmap ~5x slower on these logs.
    private static func lines(in file: URL, containing markers: [String]) -> [String] {
        guard let data = try? Data(contentsOf: file) else { return [] }
        var starts = Set<Int>()
        var lines: [String] = []

        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard let base = buffer.baseAddress else { return }
            let bytes = base.assumingMemoryBound(to: UInt8.self)
            let size = buffer.count

            for marker in markers {
                let needle = Array(marker.utf8)
                let skip = skipTable(for: needle)
                var offset = 0
                while offset < size,
                      let position = find(needle, skip: skip, in: bytes, size: size, from: offset) {
                    var start = position
                    while start > 0, bytes[start - 1] != 0x0A { start -= 1 }
                    var end = position
                    while end < size, bytes[end] != 0x0A { end += 1 }

                    if starts.insert(start).inserted {
                        lines.append(String(decoding: UnsafeBufferPointer(start: bytes + start, count: end - start), as: UTF8.self))
                    }
                    offset = end
                }
            }
        }
        return lines
    }

    /// Boyer-Moore-Horspool search. Much faster than `memmem` on macOS for multi-GB logs.
    private static func find(
        _ needle: [UInt8], skip: [Int], in bytes: UnsafePointer<UInt8>, size: Int, from start: Int
    ) -> Int? {
        let last = needle.count - 1
        var i = start
        while i + last < size {
            var j = last
            while j >= 0, bytes[i + j] == needle[j] { j -= 1 }
            if j < 0 { return i }
            i += skip[Int(bytes[i + last])]
        }
        return nil
    }

    private static func skipTable(for needle: [UInt8]) -> [Int] {
        var table = [Int](repeating: needle.count, count: 256)
        for (index, byte) in needle.dropLast().enumerated() {
            table[Int(byte)] = needle.count - 1 - index
        }
        return table
    }
}
