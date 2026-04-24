import Foundation
import SwiftData

enum Slot: String, Codable, CaseIterable {
    case morning = "morning"
    case afternoon = "afternoon"
}

@Model
final class Course {
    @Attribute(.unique) var id: UUID
    var title: String
    var teacherName: String
    var room: String
    var date: Date
    var slot: Slot
    var startsAt: Date
    var endsAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Signature.course)
    var signatures: [Signature] = []

    init(id: UUID = UUID(), title: String, teacherName: String, room: String, date: Date, slot: Slot, startsAt: Date, endsAt: Date) {
        self.id = id
        self.title = title
        self.teacherName = teacherName
        self.room = room
        self.date = date
        self.slot = slot
        self.startsAt = startsAt
        self.endsAt = endsAt
    }

    var isSigned: Bool {
        !signatures.isEmpty
    }

    var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd/MM/yyyy"
        return fmt.string(from: date)
    }

    var formattedTime: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "H'h'"
        let start = fmt.string(from: startsAt)
        let end = fmt.string(from: endsAt)
        return "\(start) - \(end)"
    }

    var formattedTimeArrow: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let start = fmt.string(from: startsAt)
        let end = fmt.string(from: endsAt)
        return "\(start) \u{2192} \(end)"
    }
}
