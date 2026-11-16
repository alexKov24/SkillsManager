import Testing
import Foundation
@testable import Infrastructure

@Suite
struct SessionLogUsageRepositoryTests {

    @Test func `counts Claude Skill tool calls without plugin prefix`() async throws {
        let dir = try makeDir()
        try write(dir, "a.jsonl", [
            #"{"uuid":"u1","message":{"content":[{"type":"tool_use","id":"toolu_1","name":"Skill","input":{"skill":"frontend-design:frontend-design"}}]}}"#,
            #"{"uuid":"u2","message":{"content":[{"type":"tool_use","id":"toolu_2","name":"Skill","input":{"skill":"dataviz","args":"x"}}]}}"#,
        ])

        let counts = await SessionLogUsageRepository(claudeDir: dir, codexDir: nil).usageCounts()

        #expect(counts["frontend-design"] == 1)
        #expect(counts["dataviz"] == 1)
    }

    @Test func `counts slash commands typed by the user, not quoted in tool output`() async throws {
        let dir = try makeDir()
        try write(dir, "a.jsonl", [
            #"{"type":"user","message":{"role":"user","content":"<command-message>leyman</command-message>\n<command-name>/leyman</command-name>"},"uuid":"u1"}"#,
            #"{"type":"user","message":{"content":[{"tool_use_id":"t1","content":"<command-name>/leyman</command-name>"}]},"uuid":"u2"}"#,
        ])

        let counts = await SessionLogUsageRepository(claudeDir: dir, codexDir: nil).usageCounts()

        #expect(counts["leyman"] == 1)
    }

    @Test func `counts the same message copied into forked sessions once`() async throws {
        let dir = try makeDir()
        let line = #"{"uuid":"u1","message":{"content":[{"type":"tool_use","id":"toolu_1","name":"Skill","input":{"skill":"close"}}]}}"#
        try write(dir, "a.jsonl", [line])
        try write(dir, "b.jsonl", [line])

        let counts = await SessionLogUsageRepository(claudeDir: dir, codexDir: nil).usageCounts()

        #expect(counts["close"] == 1)
    }

    @Test func `counts Codex SKILL md reads only in tool calls`() async throws {
        let dir = try makeDir()
        try write(dir, "rollout.jsonl", [
            #"{"type":"response_item","payload":{"type":"message","content":"- diagnose: (file: /Users/me/.agents/skills/diagnose/SKILL.md)"}}"#,
            #"{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\"cmd\":\"sed -n '1,220p' /Users/me/.agents/skills/diagnose/SKILL.md\"}","call_id":"call_1"}}"#,
        ])

        let counts = await SessionLogUsageRepository(claudeDir: nil, codexDir: dir).usageCounts()

        #expect(counts["diagnose"] == 1)
    }

    @Test func `scans nested folders`() async throws {
        let dir = try makeDir()
        try write(dir.appendingPathComponent("2026/11/16"), "rollout.jsonl", [
            #"{"type":"response_item","payload":{"type":"function_call","arguments":"cat ~/.codex/skills/pdf/SKILL.md","call_id":"call_9"}}"#,
        ])

        let counts = await SessionLogUsageRepository(claudeDir: nil, codexDir: dir).usageCounts()

        #expect(counts["pdf"] == 1)
    }

    // MARK: - Helpers

    private func makeDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(_ dir: URL, _ name: String, _ lines: [String]) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try lines.joined(separator: "\n").write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
}
