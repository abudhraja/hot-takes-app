import SwiftUI

extension Color {
    static let htBackground    = Color(red: 0.05, green: 0.05, blue: 0.12)
    static let htCard          = Color(red: 0.10, green: 0.10, blue: 0.22)
    static let htCardPressed   = Color(red: 0.18, green: 0.18, blue: 0.35)
    static let htAccent        = Color(red: 1.00, green: 0.18, blue: 0.35)
    static let htGold          = Color(red: 1.00, green: 0.82, blue: 0.00)
    static let htGreen         = Color(red: 0.18, green: 0.90, blue: 0.45)
    static let htDanger        = Color(red: 1.00, green: 0.25, blue: 0.25)
}

struct HTButtonStyle: ButtonStyle {
    var color: Color = .htAccent
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct HTCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(Color.htCard)
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

extension View {
    func htCard() -> some View { modifier(HTCardStyle()) }
}
