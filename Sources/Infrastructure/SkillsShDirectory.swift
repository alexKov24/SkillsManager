import Foundation
import Domain

/// Infrastructure: Searches skills.sh (Vercel's open skills directory). No API key needed.
public struct SkillsShDirectory: SkillDirectory {

    public init() {}

    public func search(_ query: String) async throws -> [DirectorySkill] {
        var components = URLComponents(string: "https://skills.sh/api/search")!
        components.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "limit", value: "50")]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try Self.parse(data)
    }

    static func parse(_ data: Data) throws -> [DirectorySkill] {
        struct Response: Decodable {
            struct Item: Decodable {
                let source: String
                let skillId: String
                let installs: Int?
            }
            let skills: [Item]
        }
        return try JSONDecoder().decode(Response.self, from: data).skills.map {
            DirectorySkill(repo: $0.source, skillId: $0.skillId, installs: $0.installs ?? 0)
        }
    }
}
