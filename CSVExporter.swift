import Foundation

struct CSVExporter {

    static func csv(for tracker: Tracker, entries: [Entry]) -> String {
        var lines = ["Date,Value,Completed,Note"]
        for e in entries.sorted(by: { $0.date < $1.date }) {
            let date      = DateFormatter.isoDate.string(from: e.date)
            let completed = e.isCompleted ? "true" : "false"
            let note      = "\"\(e.note.replacingOccurrences(of: "\"", with: "\"\""))\""
            lines.append("\(date),\(e.value),\(completed),\(note)")
        }
        return lines.joined(separator: "\n")
    }

    // Writes CSV to the temp directory and returns a file URL suitable for ShareLink.
    static func fileURL(for tracker: Tracker, entries: [Entry]) -> URL {
        let safe = tracker.name
            .replacingOccurrences(of: "/",  with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":",  with: "-")
        let name = "\(safe)_\(DateFormatter.isoDate.string(from: .now)).csv"
        let url  = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let text = csv(for: tracker, entries: entries)
        try? text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
