import ActivityKit
import Foundation

struct AlertStatus: Codable, Equatable {
    var locationTitle: String
    var status: String
    var updatedAt: Date
}

actor AirAlertService {
    private let session: URLSession
    private let decoder: JSONDecoder

    init() { session = URLSession(configuration: .ephemeral); decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601 }

    // Use a backend proxy in production. Never commit a personal alerts.in.ua token to the app.
    func fetchStatus(baseURL: URL, bearerToken: String, regionID: Int) async throws -> AlertStatus {
        var request = URLRequest(url: baseURL.appending(path: "v1/iot/active_air_raid_alerts/\(regionID).json"))
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
        let raw = try decoder.decode(String.self, from: data)
        return AlertStatus(locationTitle: "Обрана область", status: raw == "A" ? "active" : "safe", updatedAt: .now)
    }

    func fetchFromBackend(baseURL: URL, regionID: Int) async throws -> AlertStatus {
        var components = URLComponents(url: baseURL.appending(path: "api/alerts"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "region_id", value: String(regionID))]
        guard let url = components?.url else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
        struct BackendPayload: Decodable { let regionID: Int; let status: String; let updatedAt: Date }
        let payload = try decoder.decode(BackendPayload.self, from: data)
        return AlertStatus(locationTitle: "Обрана область \(payload.regionID)", status: payload.status, updatedAt: payload.updatedAt)
    }
}

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    func update(region: String, status: String) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = MiyTylAlertAttributes.ContentState(status: status, region: region, updatedAt: .now)
        if let activity = Activity<MiyTylAlertAttributes>.activities.first {
            await activity.update(ActivityContent(state: content, staleDate: .now.addingTimeInterval(900)))
        } else if status == "active" {
            _ = try? Activity.request(attributes: MiyTylAlertAttributes(region: region), content: ActivityContent(state: content, staleDate: .now.addingTimeInterval(900)), pushType: nil)
        }
    }

    func endAll() async { for activity in Activity<MiyTylAlertAttributes>.activities { await activity.end(nil, dismissalPolicy: .immediate) } }
}
