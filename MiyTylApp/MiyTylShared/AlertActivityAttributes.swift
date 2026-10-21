import ActivityKit
import Foundation

struct MiyTylAlertAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
        var region: String
        var updatedAt: Date
    }

    var region: String
}
