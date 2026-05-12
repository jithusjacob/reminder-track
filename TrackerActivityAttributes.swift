// Add this file to BOTH the TrackerApp target AND the TrackerWidgetExtension target.
// In TrackerApp's Info.plist add: NSSupportsLiveActivities = YES

import ActivityKit
import Foundation

struct TrackerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var completedCount: Int
        var totalCount: Int
        var completedNames: [String]
    }
}
