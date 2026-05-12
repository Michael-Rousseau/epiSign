import SwiftUI
import SwiftData

struct TimetableView: View {
    @Query(sort: \Course.startsAt) private var courses: [Course]
    @Query private var signatures: [Signature]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    attendanceSection
                    timetableSection
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                let service = CourseService()
                try? await service.syncToLocal(context: modelContext)
            }
        }
    }

    // MARK: - Assiduité

    private var attendanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assiduité")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                StatCardView(label: "Présences", value: signedCount)
                StatCardView(label: "Absences", value: absentCount)
                StatCardView(label: "Retards", value: 0)
                StatCardView(label: "Total", value: courses.count)
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }

    // MARK: - Timetable

    private var timetableSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Emploi du temps")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal)

            ForEach(groupedByDay, id: \.0) { day, dayCourses in
                VStack(alignment: .leading, spacing: 10) {
                    Text(day)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal)

                    ForEach(dayCourses) { course in
                        TimetableRowView(course: course)
                            .padding(.horizontal)
                    }
                }
            }
        }
    } 
    // MARK: - Computed

    private var signedCount: Int {
        courses.filter { $0.isSigned }.count
    }

    private var absentCount: Int {
        let now = Date()
        return courses.filter { !$0.isSigned && $0.endsAt < now }.count
    }

    private var groupedByDay: [(String, [Course])] {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "fr_FR")
        fmt.dateFormat = "EEEE d MMMM"

        let grouped = Dictionary(grouping: courses) { course in
            fmt.string(from: course.date)
        }

        return grouped
            .sorted { lhs, rhs in
                guard let l = lhs.value.first?.date, let r = rhs.value.first?.date else { return false }
                return l < r
            }
            .map { ($0.key.capitalized, $0.value.sorted { $0.startsAt < $1.startsAt }) }
    }
}

struct TimetableRowView: View {
    let course: Course

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(timeString(course.startsAt))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text(timeString(course.endsAt))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(width: 50)

            RoundedRectangle(cornerRadius: 2)
                .fill(course.isSigned ? Color.green : Color.white.opacity(0.3))
                .frame(width: 4, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(course.title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("\(course.room) \u{00B7} \(course.teacherName)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            if course.isSigned {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func timeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }
}

#Preview {
    TimetableView()
        .modelContainer(for: [Course.self, Signature.self], inMemory: true)
        .preferredColorScheme(.dark)
}
