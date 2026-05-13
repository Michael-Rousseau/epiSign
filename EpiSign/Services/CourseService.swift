import Foundation
import SwiftData
import Supabase
import Auth
import PostgREST
import WidgetKit

struct RemoteCourse: Decodable {
    let id: String
    let title: String
    let date: String
    let slot: String
    let room: String
    let teacher_id: String
    let starts_at: String
    let ends_at: String
    // Joined teacher name
    let teachers: TeacherInfo?

    struct TeacherInfo: Decodable {
        let name: String
    }
}

struct RemoteSignature: Decodable {
    let id: String
    let student_id: String
    let course_id: String
    let slot: String
    let timestamp: String
    let image_path: String?
}

actor CourseService {
    private let iso = ISO8601DateFormatter()
    private let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func fetchCourses() async throws -> [RemoteCourse] {
        do {
            let result: [RemoteCourse] = try await supabase
                .from("courses")
                .select("*, teachers(name)")
                .order("starts_at")
                .execute()
                .value
            print("[Sync] fetched \(result.count) courses WITH teacher join")
            return result
        } catch {
            print("[Sync] teacher join failed: \(error), falling back to *")
            let result: [RemoteCourse] = try await supabase
                .from("courses")
                .select("*")
                .order("starts_at")
                .execute()
                .value
            print("[Sync] fetched \(result.count) courses WITHOUT teacher join")
            return result
        }
    }

    func fetchSignatures(studentId: String) async throws -> [RemoteSignature] {
        let sigs: [RemoteSignature] = try await supabase
            .from("signatures")
            .select()
            .eq("student_id", value: studentId)
            .execute()
            .value
        return sigs
    }

    func syncToLocal(context: ModelContext) async throws {
        guard let user = try? await supabase.auth.session.user else { return }

        let remoteCourses = try await fetchCourses()
        let remoteSigs = try await fetchSignatures(studentId: user.id.uuidString)

        // Signed course+slot combos
        let signedSet = Set(remoteSigs.map { "\($0.course_id)_\($0.slot)" })

        // Clear existing local data
        try context.delete(model: Course.self)

        for rc in remoteCourses {
            print("[Sync] course '\(rc.title)' teacher: \(String(describing: rc.teachers))")
            let course = Course(
                id: UUID(uuidString: rc.id) ?? UUID(),
                title: rc.title,
                teacherName: rc.teachers?.name ?? "Enseignant",
                room: rc.room,
                date: dateFmt.date(from: rc.date) ?? .now,
                slot: rc.slot == "morning" ? .morning : .afternoon,
                startsAt: iso.date(from: rc.starts_at) ?? .now,
                endsAt: iso.date(from: rc.ends_at) ?? .now
            )
            context.insert(course)

            // If signed, create local signature record
            let key = "\(rc.id)_\(rc.slot)"
            if signedSet.contains(key) {
                if let sig = remoteSigs.first(where: { "\($0.course_id)_\($0.slot)" == key }) {
                    let localSig = Signature(
                        id: UUID(uuidString: sig.id) ?? UUID(),
                        course: course,
                        slot: rc.slot == "morning" ? .morning : .afternoon,
                        timestamp: iso.date(from: sig.timestamp) ?? .now,
                        isSynced: true
                    )
                    context.insert(localSig)
                }
            }
        }
        try context.save()
        await updateWidgetData(courses: remoteCourses)
    }

    @MainActor
    func updateWidgetData(courses: [RemoteCourse]) {
        let defaults = UserDefaults(suiteName: "group.com.EpiSign") ?? .standard
        let now = Date()
        let iso = ISO8601DateFormatter()
        let isoFrac: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }()
        func parseDate(_ s: String) -> Date? {
            iso.date(from: s) ?? isoFrac.date(from: s)
        }
        let upcoming = courses
            .compactMap { rc -> [String: String]? in
                guard let end = parseDate(rc.ends_at), end > now else { return nil }
                return [
                    "title": rc.title,
                    "room": rc.room,
                    "teacher": rc.teachers?.name ?? "Enseignant",
                    "starts_at": rc.starts_at,
                    "ends_at": rc.ends_at,
                    "slot": rc.slot
                ]
            }
        print("[Widget] upcoming courses: \(upcoming.count), total: \(courses.count)")
        if let next = upcoming.first {
            defaults.set(next, forKey: "nextCourse")
            print("[Widget] wrote next course: \(next["title"] ?? "?")")
        } else {
            defaults.removeObject(forKey: "nextCourse")
            print("[Widget] no upcoming courses")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
