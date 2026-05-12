import SwiftUI
import SwiftData

struct SignTabView: View {
    @Query(sort: \Course.startsAt) private var courses: [Course]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            if let current = currentCourse {
                SigningView(course: current)
            } else {
                noLessonView
            }
        }
    }

    private var currentCourse: Course? {
        courses.first { $0.isCurrent }
    }

    private var noLessonView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.3))

            Text("Aucun cours en ce moment")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text("Revenez pendant un cours pour signer votre présence")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#Preview {
    SignTabView()
        .modelContainer(for: [Course.self, Signature.self], inMemory: true)
        .preferredColorScheme(.dark)
}
