import WidgetKit
import SwiftUI

struct NextCourseEntry: TimelineEntry {
    let date: Date
    let title: String?
    let room: String?
    let teacher: String?
    let startsAt: Date?
    let endsAt: Date?
    let slot: String?
}

struct NextCourseProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextCourseEntry {
        NextCourseEntry(date: .now, title: "Mathématiques", room: "Salle 101", teacher: "M. Dupont", startsAt: .now, endsAt: .now.addingTimeInterval(3600), slot: "morning")
    }

    func getSnapshot(in context: Context, completion: @escaping (NextCourseEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextCourseEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> NextCourseEntry {
        let defaults = UserDefaults(suiteName: "group.com.EpiSign") ?? .standard
        guard let data = defaults.dictionary(forKey: "nextCourse") as? [String: String] else {
            return NextCourseEntry(date: .now, title: nil, room: nil, teacher: nil, startsAt: nil, endsAt: nil, slot: nil)
        }

        let iso = ISO8601DateFormatter()
        let isoFrac: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }()
        func parseDate(_ s: String) -> Date? {
            iso.date(from: s) ?? isoFrac.date(from: s)
        }
        return NextCourseEntry(
            date: .now,
            title: data["title"],
            room: data["room"],
            teacher: data["teacher"],
            startsAt: data["starts_at"].flatMap { parseDate($0) },
            endsAt: data["ends_at"].flatMap { parseDate($0) },
            slot: data["slot"]
        )
    }
}

struct EpiSignWidgetEntryView: View {
    var entry: NextCourseEntry

    var body: some View {
        if let title = entry.title {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(entry.slot == "morning" ? Color.orange : Color.blue)
                        .frame(width: 8, height: 8)
                    Text(slotLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(2)

                if let room = entry.room {
                    Text(room)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if let startsAt = entry.startsAt, let endsAt = entry.endsAt {
                    Text(timeRange(startsAt, endsAt))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
            }
            .padding(2)
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Aucun cours")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }

    private var slotLabel: String {
        entry.slot == "morning" ? "Matin" : "Après-midi"
    }

    private func timeRange(_ start: Date, _ end: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
    }
}

struct EpiSignWidget: Widget {
    let kind = "EpiSignWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextCourseProvider()) { entry in
            EpiSignWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Prochain cours")
        .description("Affiche votre prochain cours")
        .supportedFamilies([.systemSmall])
    }
}
