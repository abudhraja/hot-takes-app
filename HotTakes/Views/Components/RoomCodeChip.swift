import SwiftUI

struct RoomCodeChip: View {
    let code: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "number.circle.fill")
                .font(.system(size: 14, weight: .bold))
            Text(code)
                .font(.system(size: 15, weight: .black, design: .monospaced))
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}
