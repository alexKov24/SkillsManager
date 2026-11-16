import Testing
import Foundation
@testable import Infrastructure

@Suite
struct HarnessDetectorTests {

    @Test func `detects harnesses whose folder exists`() throws {
        let home = try makeHome(folders: [".claude", ".gemini"])

        let harnesses = HarnessDetector(homePath: home).detect()

        #expect(harnesses.first { $0.name == "Claude Code" }?.isInstalled == true)
        #expect(harnesses.first { $0.name == "Gemini CLI" }?.isInstalled == true)
        #expect(harnesses.first { $0.name == "Codex" }?.isInstalled == false)
    }

    @Test func `prompt lists installed harnesses that are not counted yet`() throws {
        let home = try makeHome(folders: [".claude", ".gemini", ".cursor"])
        let detector = HarnessDetector(homePath: home)

        let prompt = detector.prompt(for: detector.detect())

        #expect(prompt.contains("Gemini CLI"))
        #expect(prompt.contains("Cursor"))
        #expect(!prompt.contains("- Claude Code"))
        #expect(!prompt.contains("- Codex"))
    }

    private func makeHome(folders: [String]) throws -> String {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        for folder in folders {
            try FileManager.default.createDirectory(atPath: "\(home)/\(folder)", withIntermediateDirectories: true)
        }
        return home
    }
}
