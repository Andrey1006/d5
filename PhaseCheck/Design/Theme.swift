
import SwiftUI

enum PCColor {
    static let base = Color(red: 15 / 255, green: 19 / 255, blue: 32 / 255)
    static let layer = Color(red: 27 / 255, green: 33 / 255, blue: 53 / 255)
    static let structure = Color(red: 44 / 255, green: 49 / 255, blue: 71 / 255)
    static let secondaryText = Color(red: 122 / 255, green: 128 / 255, blue: 145 / 255)
    static let balance = Color(red: 76 / 255, green: 175 / 255, blue: 80 / 255)
    static let skew = Color(red: 242 / 255, green: 169 / 255, blue: 59 / 255)
    static let critical = Color(red: 214 / 255, green: 69 / 255, blue: 69 / 255)
    static let dataBlue = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)

    static func status(_ status: BalanceStatus) -> Color {
        switch status {
        case .balanced: return balance
        case .skewed: return skew
        case .critical: return critical
        }
    }
}

enum PCGradients {
    static let indigoBlue = LinearGradient(
        colors: [Color(red: 0.25, green: 0.2, blue: 0.45), PCColor.dataBlue.opacity(0.85)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let greenLime = LinearGradient(
        colors: [Color(red: 0.2, green: 0.55, blue: 0.35), Color(red: 0.55, green: 0.9, blue: 0.45)],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let orangeYellow = LinearGradient(
        colors: [Color(red: 0.95, green: 0.45, blue: 0.15), PCColor.skew],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let cardSheen = LinearGradient(
        colors: [PCColor.structure.opacity(0.9), PCColor.layer],
        startPoint: .top,
        endPoint: .bottom
    )
}

enum PCMetrics {
    static let cornerRadius: CGFloat = 8
    static let cornerRadiusSmall: CGFloat = 6
    static let borderWidth: CGFloat = 1
    static let topAccentHeight: CGFloat = 3
}
