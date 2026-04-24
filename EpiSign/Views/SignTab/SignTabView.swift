import SwiftUI
import SwiftData

struct SignTabView: View {
    @Query(sort: \Course.startsAt) private var courses: [Course]
    @Query private var signatures: [Signature]
    @State private var isRefreshing = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    attendanceSection
                    planningSection
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await refreshFromSupabase()
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
    }

    // MARK: - Planning

    private var planningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Planning")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            ForEach(upcomingCourses) { course in
                NavigationLink(destination: SigningView(course: course)) {
                    CourseCardView(course: course)
                }
                .buttonStyle(.plain)
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

    private var upcomingCourses: [Course] {
        courses
    }

    // MARK: - Refresh

    private func refreshFromSupabase() async {
        let service = CourseService()
        try? await service.syncToLocal(context: modelContext)
    }
}

#Preview {
    SignTabView()
        .modelContainer(for: [Course.self, Signature.self], inMemory: true)
        .preferredColorScheme(.dark)
}
