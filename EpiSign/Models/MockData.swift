import Foundation
import SwiftData

struct MockData {
    static func seed(context: ModelContext) {
        // Always clear and re-seed with current week's courses
        let descriptor = FetchDescriptor<Course>()
        if let existing = try? context.fetch(descriptor) {
            for course in existing { context.delete(course) }
        }

        let cal = Calendar.current

        func makeDate(year: Int, month: Int, day: Int) -> Date {
            cal.date(from: DateComponents(year: year, month: month, day: day))!
        }

        func makeTime(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
            cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
        }

        // Mon 12 → Fri 16 May 2026
        let courses: [(String, String, String, Int, Int, Int, Slot, Int, Int, Int, Int)] = [
            ("iOS Development",   "M. Fournier", "SM Apple", 2026, 5, 12, .morning,   9, 0, 13, 0),
            ("iOS Development",   "M. Fournier", "SM Apple", 2026, 5, 12, .afternoon, 14, 0, 18, 0),
            ("Swift Avancé",      "M. Fournier", "SM Apple", 2026, 5, 13, .morning,   9, 0, 13, 0),
            ("Swift Avancé",      "M. Fournier", "SM Apple", 2026, 5, 13, .afternoon, 14, 0, 18, 0),
            ("Projet EpiSign",    "M. Fournier", "SM Apple", 2026, 5, 14, .morning,   9, 0, 13, 0),
            ("Projet EpiSign",    "M. Fournier", "SM Apple", 2026, 5, 14, .afternoon, 14, 0, 18, 0),
            ("iOS Development",   "M. Fournier", "SM Apple", 2026, 5, 15, .morning,   9, 0, 13, 0),
            ("iOS Development",   "M. Fournier", "SM Apple", 2026, 5, 15, .afternoon, 14, 0, 18, 0),
            ("Soutenance Projet", "M. Fournier", "SM Apple", 2026, 5, 16, .morning,   9, 0, 13, 0),
            ("Soutenance Projet", "M. Fournier", "SM Apple", 2026, 5, 16, .afternoon, 14, 0, 18, 0),
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
