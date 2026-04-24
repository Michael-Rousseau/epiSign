import Foundation
import SwiftData

struct MockData {
    static func seed(context: ModelContext) {
        let descriptor = FetchDescriptor<Course>()
        let existing = (try? context.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }

        let cal = Calendar.current

        func makeDate(year: Int, month: Int, day: Int) -> Date {
            cal.date(from: DateComponents(year: year, month: month, day: day))!
        }

        func makeTime(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
            cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
        }

        let courses: [(String, String, String, Int, Int, Int, Slot, Int, Int, Int, Int)] = [
            ("iOS Development",   "M. Fournier", "SM Apple", 2026, 4, 27, .morning,   9, 0, 13, 0),
            ("iOS Development",   "M. Fournier", "SM Apple", 2026, 4, 27, .afternoon, 14, 0, 18, 0),
            ("Swift Avancé",      "M. Fournier", "SM Apple", 2026, 4, 28, .morning,   9, 0, 13, 0),
            ("Swift Avancé",      "M. Fournier", "SM Apple", 2026, 4, 28, .afternoon, 14, 0, 18, 0),
            ("Projet EpiSign",    "M. Fournier", "SM Apple", 2026, 4, 29, .morning,   9, 0, 13, 0),
            ("Projet EpiSign",    "M. Fournier", "SM Apple", 2026, 4, 29, .afternoon, 14, 0, 18, 0),
        ]

        for c in courses {
            let course = Course(
                title: c.0,
                teacherName: c.1,
                room: c.2,
                date: makeDate(year: c.3, month: c.4, day: c.5),
                slot: c.6,
                startsAt: makeTime(year: c.3, month: c.4, day: c.5, hour: c.7, minute: c.8),
                endsAt: makeTime(year: c.3, month: c.4, day: c.5, hour: c.9, minute: c.10)
            )
            context.insert(course)
        }

        try? context.save()
    }
}
