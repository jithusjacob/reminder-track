import Foundation

// MARK: - Shared UserDefaults across main app, widget, and Watch
//
// This file is added to all three targets (main app, widget, watch), each of
// which declares "group.com.jsj.reminder.track" under Signing & Capabilities → App Groups.

enum SharedTrackerDefaults {

    static let suiteName = "group.com.jsj.reminder.track"

    static var store: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static let idsKey = "trackerCalendarIds"

    struct TrackerMeta: Codable {
        var icon: String
        var colorHex: String
        var recurrence: String
        var isActive: Bool
        var createdAt: Double
        var reminderHour: Int?
        var reminderMinute: Int?
    }

    static func metaKey(_ id: String) -> String { "trackerMeta_\(id)" }

    static var storedIds: [String] {
        get { store.stringArray(forKey: idsKey) ?? [] }
        set { store.set(newValue, forKey: idsKey) }
    }

    static func meta(for id: String) -> TrackerMeta? {
        guard let data = store.data(forKey: metaKey(id)),
              let meta = try? JSONDecoder().decode(TrackerMeta.self, from: data)
        else { return nil }
        return meta
    }

    static func save(_ meta: TrackerMeta, id: String) {
        if let data = try? JSONEncoder().encode(meta) {
            store.set(data, forKey: metaKey(id))
        }
        if !storedIds.contains(id) {
            storedIds = storedIds + [id]
        }
    }

    static func remove(id: String) {
        store.removeObject(forKey: metaKey(id))
        storedIds = storedIds.filter { $0 != id }
    }
}
