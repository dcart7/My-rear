// xcode: set sdk=iOS

import ActivityKit
import SwiftUI
import WidgetKit

struct MiyTylAlertAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: String
        var region: String
        var updatedAt: Date
    }
    var region: String
}

struct MiyTylLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MiyTylAlertAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: context.state.status == "active" ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                    .foregroundStyle(context.state.status == "active" ? .red : .green)
                VStack(alignment: .leading) {
                    Text(context.state.status == "active" ? "Повітряна тривога" : "Небезпеки не зафіксовано").font(.headline)
                    Text(context.attributes.region).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Image(systemName: "shield.fill") }
                DynamicIslandExpandedRegion(.center) { Text(context.state.status == "active" ? "Тривога" : "Спокій") }
                DynamicIslandExpandedRegion(.trailing) { Text(context.attributes.region).font(.caption2) }
            } compactLeading: { Image(systemName: "shield.fill") } compactTrailing: { Text(context.state.status == "active" ? "!" : "✓") } minimal: { Image(systemName: "shield.fill") }
        }
    }
}

@main struct MiyTylLiveActivityBundle: WidgetBundle { var body: some Widget { MiyTylLiveActivity() } }
