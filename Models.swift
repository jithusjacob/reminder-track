import Foundation
import EventKit
import SwiftUI

// MARK: - RecurrenceType

enum RecurrenceType: String, CaseIterable, Codable {
    case daily    = "daily"
    case weekdays = "weekdays"
    case weekly   = "weekly"
}

// MARK: - Tracker

struct Tracker: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var icon: String
    var color: Color
    var reminderTime: DateComponents?
    var recurrence: RecurrenceType
    var isActive: Bool
    var createdAt: Date

    var colorHex: String {
        #if canImport(UIKit)
        return UIColor(color).hexString
        #else
        return "6366F1"
        #endif
    }

    // tracker://schedule?trackerId=<id>  — embedded in the daily notification reminder
    var scheduleURL: URL? {
        var c        = URLComponents()
        c.scheme     = "tracker"
        c.host       = "schedule"
        c.queryItems = [URLQueryItem(name: "trackerId", value: id)]
        return c.url
    }

    // tracker://config?icon=...&color=...&recurrence=...&active=...&created=...&rh=H&rm=M
    var configURL: URL? {
        var c        = URLComponents()
        c.scheme     = "tracker"
        c.host       = "config"
        c.queryItems = [
            URLQueryItem(name: "icon",       value: icon),
            URLQueryItem(name: "color",      value: colorHex),
            URLQueryItem(name: "recurrence", value: recurrence.rawValue),
            URLQueryItem(name: "active",     value: isActive ? "1" : "0"),
            URLQueryItem(name: "created",    value: "\(Int(createdAt.timeIntervalSince1970))"),
            URLQueryItem(name: "rh",         value: reminderTime?.hour.map(String.init) ?? ""),
            URLQueryItem(name: "rm",         value: reminderTime?.minute.map(String.init) ?? "")
        ]
        return c.url
    }

    // Parse from the hidden "config_track_metadata_user_can_ignore" reminder (new format).
    static func from(configReminder: EKReminder) -> Tracker? {
        guard
            let raw = configReminder.url?.absoluteString,
            let url = URL(string: raw),
            let cal = configReminder.calendar
        else { return nil }
        return decode(configURL: url, id: cal.calendarIdentifier, name: cal.title)
    }

    /// Pure decode of a `configURL` (see above) into a Tracker, given the id/name
    /// that live on the EventKit calendar rather than in the URL itself. Split out
    /// from `from(configReminder:)` so the encode ↔ decode round trip is testable
    /// without needing a saved `EKReminder`/`EKCalendar` pair.
    static func decode(configURL url: URL, id: String, name: String) -> Tracker? {
        guard
            url.scheme == "tracker", url.host == "config",
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }

        func q(_ name: String) -> String? {
            comps.queryItems?.first(where: { $0.name == name })?.value
        }

        var rt: DateComponents? = nil
        if let h = q("rh").flatMap(Int.init), let m = q("rm").flatMap(Int.init) {
            var dc = DateComponents(); dc.hour = h; dc.minute = m
            rt = dc
        }

        return Tracker(
            id:           id,
            name:         name,
            icon:         q("icon") ?? "checkmark",
            color:        Color(hex: q("color") ?? "") ?? .indigo,
            reminderTime: rt,
            recurrence:   RecurrenceType(rawValue: q("recurrence") ?? "") ?? .daily,
            isActive:     q("active") == "1",
            createdAt:    q("created").flatMap(Double.init)
                            .map(Date.init(timeIntervalSince1970:)) ?? .now
        )
    }

    // Parse from the old pipe-encoded calendar title (migration only).
    static func from(calendar: EKCalendar) -> Tracker? {
        let p = calendar.title.components(separatedBy: "|")
        guard p.count >= 10, p[0] == "_tracker_" else { return nil }
        return Tracker(
            id:           calendar.calendarIdentifier,
            name:         p[2],
            icon:         p[3],
            color:        Color(hex: p[4]) ?? .indigo,
            reminderTime: nil,
            recurrence:   RecurrenceType(rawValue: p[8]) ?? .daily,
            isActive:     p[9] == "1",
            createdAt:    p.count >= 11
                            ? Date(timeIntervalSince1970: Double(p[10]) ?? 0)
                            : Date()
        )
    }
}

// MARK: - Entry

struct Entry: Identifiable, Equatable {
    let id: String
    let trackerId: String
    var date: Date
    var value: Double
    var note: String
    var isCompleted: Bool
    var completionDate: Date?

    // tracker://entry?trackerId=X&value=Y&date=Z
    var metadataURL: URL? {
        var c        = URLComponents()
        c.scheme     = "tracker"
        c.host       = "entry"
        c.queryItems = [
            URLQueryItem(name: "trackerId", value: trackerId),
            URLQueryItem(name: "value",     value: String(value)),
            URLQueryItem(name: "date",
                         value: ISO8601DateFormatter().string(from: date))
        ]
        return c.url
    }

    static func from(reminder: EKReminder) -> Entry? {
        guard
            let raw   = reminder.url?.absoluteString,
            let url   = URL(string: raw),
            url.scheme == "tracker",
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }

        switch url.host {
        case "entry":
            guard
                let tid   = comps.queryItems?.first(where: { $0.name == "trackerId" })?.value,
                let valS  = comps.queryItems?.first(where: { $0.name == "value"     })?.value,
                let dateS = comps.queryItems?.first(where: { $0.name == "date"      })?.value,
                let val   = Double(valS),
                let date  = ISO8601DateFormatter().date(from: dateS)
            else { return nil }
            return Entry(
                id:             reminder.calendarItemIdentifier,
                trackerId:      tid,
                date:           date,
                value:          val,
                note:           reminder.notes ?? "",
                isCompleted:    reminder.isCompleted,
                completionDate: reminder.completionDate
            )

        case "schedule":
            // Marking the daily notification reminder done in Reminders.app counts as logging.
            // Only completed occurrences are meaningful; pending ones are ignored.
            guard
                reminder.isCompleted,
                let tid            = comps.queryItems?.first(where: { $0.name == "trackerId" })?.value,
                let completionDate = reminder.completionDate
            else { return nil }
            // Suffix "-sched" lets deduplication in fetchFiltered prefer explicit entry
            // reminders over schedule-derived ones when both exist for the same day.
            return Entry(
                id:             reminder.calendarItemIdentifier + "-sched",
                trackerId:      tid,
                date:           Calendar.current.startOfDay(for: completionDate),
                value:          1,
                note:           reminder.notes ?? "",
                isCompleted:    true,
                completionDate: completionDate
            )

        default:
            return nil
        }
    }
}

// MARK: - DateRange

struct DateRange {
    let start: Date
    let end:   Date

    static func week(containing date: Date = .now) -> DateRange {
        let cal   = Calendar.current
        let start = cal.date(from: cal.dateComponents(
            [.yearForWeekOfYear, .weekOfYear], from: date))!
        return DateRange(start: start,
                         end:   cal.date(byAdding: .day, value: 6, to: start)!)
    }

    static func month(containing date: Date = .now) -> DateRange {
        let cal   = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: date))!
        let end   = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
        return DateRange(start: start, end: end)
    }

    static func year(containing date: Date = .now) -> DateRange {
        let cal   = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year], from: date))!
        let end   = cal.date(byAdding: DateComponents(year: 1, day: -1), to: start)!
        return DateRange(start: start, end: end)
    }
}

// MARK: - Color ↔ Hex

extension Color {
    init?(hex: String) {
        let h   = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var rgb: UInt64 = 0
        guard Scanner(string: h).scanHexInt64(&rgb) else { return nil }
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}

#if canImport(UIKit)
extension UIColor {
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X",
                      Int((r * 255).rounded()),
                      Int((g * 255).rounded()),
                      Int((b * 255).rounded()))
    }
}
#endif

extension DateFormatter {
    static let isoDate: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
}
