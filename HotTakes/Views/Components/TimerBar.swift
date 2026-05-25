import SwiftUI

struct TimerBar: View {
    let remaining: Int
    let total: Int

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(remaining) / Double(total)
    }

    private var barColor: Color {
        if fraction > 0.5 { return .htGreen }
        if fraction > 0.25 { return .htGold }
        return .htDanger
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule()
                        .fill(barColor)
                        .frame(width: max(0, geo.size.width * fraction))
                        .animation(.linear(duration: 1), value: fraction)
                }
            }
            .frame(height: 8)

            Text("\(remaining)s")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
