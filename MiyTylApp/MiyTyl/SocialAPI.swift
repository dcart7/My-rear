import Foundation

struct SocialPost: Codable, Identifiable, Equatable {
    let id: UUID
    let category: String
    let area: String
    let message: String
    let displayName: String?
    let createdAt: Date
    enum CodingKeys: String, CodingKey { case id, category, area, message, displayName = "display_name", createdAt = "created_at" }
}

actor SocialAPI {
    private let baseURL: URL
    private let session = URLSession(configuration: .ephemeral)
    private var token: String?

    init(baseURL: URL) { self.baseURL = baseURL }
    func setToken(_ value: String?) { token = value }

    func feed(limit: Int = 20) async throws -> [SocialPost] {
        var components = URLComponents(url: baseURL.appending(path: "v1/feed"), resolvingAgainstBaseURL: false); components?.queryItems = [URLQueryItem(name: "limit", value: String(min(max(limit, 1), 50)))]; guard let url = components?.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try JSONDecoder.miyTyl.decode(FeedResponse.self, from: data).posts
    }

    func createPost(category: String, area: String, message: String) async throws -> SocialPost {
        var request = URLRequest(url: baseURL.appending(path: "v1/posts")); request.httpMethod = "POST"; request.httpBody = try JSONEncoder().encode(PostPayload(category: category, area: area, message: message)); request.setValue("application/json", forHTTPHeaderField: "Content-Type"); addAuth(&request)
        let (data, response) = try await session.data(for: request); try validate(response); return try JSONDecoder.miyTyl.decode(PostResponse.self, from: data).post
    }

    private func addAuth(_ request: inout URLRequest) { if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") } }
    private func validate(_ response: URLResponse) throws { guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) } }
}

private struct FeedResponse: Codable { let posts: [SocialPost] }
private struct PostResponse: Codable { let post: SocialPost }
private struct PostPayload: Codable { let category: String; let area: String; let message: String }
private extension JSONDecoder { static let miyTyl: JSONDecoder = { let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return decoder }() }
