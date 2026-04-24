import Foundation
import SwiftData
import Supabase
import Auth
import PostgREST

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
        let courses: [RemoteCourse] = try await supabase
            .from("courses")
            .select("*, teachers(name)")
            .order("starts_at")
            .execute()
            .value
        return courses
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
    }
}
