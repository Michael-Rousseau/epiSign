import SwiftUI

struct AudioVisualizerView: View {
    @State private var animating = false
    let barCount = 5
    let isActive: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                .frame(width: 200, height: 200)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 200, height: 200)

            HStack(spacing: 6) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(isActive ? 0.8 : 0.4))
                        .frame(width: 10, height: barHeight(for: index))
                        .animation(
                            isActive
                                ? .easeInOut(duration: 0.4 + Double(index) * 0.1)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.08)
                                : .easeInOut(duration: 0.3),
                            value: animating
                        )
                }
            }
        }
        .onAppear {
            if isActive {
                animating = true
            }
        }
        .onChange(of: isActive) { _, newValue in
            animating = newValue
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        if !animating {
            return baseHeights[index % baseHeights.count]
        }
        return animatedHeights[index % animatedHeights.count]
    }

    private let baseHeights: [CGFloat] = [30, 45, 60, 45, 30]
    private let animatedHeights: [CGFloat] = [60, 80, 50, 75, 55]
}

#Preview {
    VStack(spacing: 40) {
        AudioVisualizerView(isActive: true)
        AudioVisualizerView(isActive: false)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
