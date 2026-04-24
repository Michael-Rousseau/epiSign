import SwiftUI

struct SpectrumVisualizerView: View {
    let spectrumData: [Float]
    let isActive: Bool

    var body: some View {
        ZStack {
            // Outer circle
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 2)
                .frame(width: 220, height: 220)

            // Background fill
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 220, height: 220)

            if isActive && !spectrumData.isEmpty {
                // Real spectrum bars (circular layout)
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius: CGFloat = 60
                    let barCount = min(spectrumData.count, 32)
                    let angleStep = (2 * CGFloat.pi) / CGFloat(barCount)
                    let maxBarHeight: CGFloat = 35

                    for i in 0..<barCount {
                        let angle = angleStep * CGFloat(i) - .pi / 2
                        let magnitude = CGFloat(spectrumData[i * spectrumData.count / barCount])
                        let barHeight = max(4, magnitude * maxBarHeight)

                        let startX = center.x + radius * cos(angle)
                        let startY = center.y + radius * sin(angle)
                        let endX = center.x + (radius + barHeight) * cos(angle)
                        let endY = center.y + (radius + barHeight) * sin(angle)

                        var path = Path()
                        path.move(to: CGPoint(x: startX, y: startY))
                        path.addLine(to: CGPoint(x: endX, y: endY))

                        let opacity = 0.3 + Double(magnitude) * 0.7
                        context.stroke(path, with: .color(.white.opacity(opacity)), lineWidth: 3)
                    }
                }
                .frame(width: 220, height: 220)
            } else {
                // Static icon (5 bars)
                StaticWaveformIcon()
            }
        }
    }
}

struct StaticWaveformIcon: View {
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 10, height: heights[index])
            }
        }
    }

    private let heights: [CGFloat] = [30, 45, 60, 45, 30]
}

#Preview {
    VStack(spacing: 40) {
        SpectrumVisualizerView(
            spectrumData: (0..<64).map { _ in Float.random(in: 0...1) },
            isActive: true
        )
        SpectrumVisualizerView(spectrumData: [], isActive: false)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
