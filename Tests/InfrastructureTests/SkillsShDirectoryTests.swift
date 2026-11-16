import Testing
import Foundation
@testable import Infrastructure

@Suite
struct SkillsShDirectoryTests {

    @Test func `parses skills.sh search results`() throws {
        let json = #"""
        {"query":"pdf","skills":[
          {"id":"anthropics/skills/pdf","source":"anthropics/skills","skillId":"pdf","name":"pdf","installs":230421},
          {"id":"openai/skills/pdf","source":"openai/skills","skillId":"pdf","name":"pdf","installs":13866}
        ]}
        """#

        let skills = try SkillsShDirectory.parse(Data(json.utf8))

        #expect(skills.map(\.id) == ["anthropics/skills/pdf", "openai/skills/pdf"])
        #expect(skills[0].repo == "anthropics/skills")
        #expect(skills[0].skillId == "pdf")
        #expect(skills[0].installs == 230421)
        #expect(skills[0].repoUrl == "https://github.com/anthropics/skills")
    }
}
