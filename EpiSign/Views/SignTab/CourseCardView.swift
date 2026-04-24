import SwiftUI

struct CourseCardView: View {
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(course.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Spacer()

                if course.isSigned {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            HStack(spacing: 16) {
                Text(course.formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                Text(course.formattedTime)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                Text(course.room)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.03))
                )
        )
    }
}
