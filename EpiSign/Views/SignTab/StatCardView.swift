import SwiftUI

struct StatCardView: View {
    let label: String
    let value: Int
    var color: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text("\(value)")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                )
        )
    }
}

#Preview {
    HStack {
        StatCardView(label: "Présences", value: 12)
        StatCardView(label: "Absences", value: 2, color: .red)
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
