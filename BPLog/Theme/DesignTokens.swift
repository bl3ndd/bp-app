import SwiftUI

extension Color {
    init(light: UInt, dark: UInt) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: 1)
        })
    }
}

/// Clinical, high-contrast palette for US adults 50+: white surfaces, a
/// trust-blue accent, and the AHA chart colors people already know from the
/// doctor's office. Secondary text stays dark enough for WCAG AA.
enum AppColors {
    static let bgApp = Color(light: 0xF2F4F7, dark: 0x000000)
    static let bgCard = Color(light: 0xFFFFFF, dark: 0x1C1C1E)
    static let bgInput = Color(light: 0xF2F4F7, dark: 0x2C2C2E)

    static let textPrimary = Color(light: 0x111827, dark: 0xF9FAFB)
    static let textSecondary = Color(light: 0x4B5563, dark: 0xC7CBD1)
    static let separator = Color(light: 0xE5E7EB, dark: 0x38383A)

    static let accent = Color(light: 0x1D4ED8, dark: 0x60A5FA)

    static let systolic = Color(light: 0x1D4ED8, dark: 0x60A5FA)
    static let diastolic = Color(light: 0x0891B2, dark: 0x67E8F9)
    static let pulse = Color(light: 0x6B7280, dark: 0x9CA3AF)

    // AHA blood pressure chart colors, darkened in light mode so text on white stays readable.
    // Low sits off the green→red scale in indigo: it's a different concern, not "better than normal".
    static let low = Color(light: 0x4338CA, dark: 0xA5B4FC)
    static let normal = Color(light: 0x15803D, dark: 0x4ADE80)
    static let elevated = Color(light: 0xA16207, dark: 0xFACC15)
    static let stage1 = Color(light: 0xC2410C, dark: 0xFB923C)
    static let stage2 = Color(light: 0xB91C1C, dark: 0xF87171)
    static let crisis = Color(light: 0x7F1D1D, dark: 0xFCA5A5)
}

extension BPCategory {
    var color: Color {
        switch self {
        case .low: AppColors.low
        case .normal: AppColors.normal
        case .elevated: AppColors.elevated
        case .stage1: AppColors.stage1
        case .stage2: AppColors.stage2
        case .crisis: AppColors.crisis
        }
    }
}

enum AppFont {
    /// Reading numbers: rounded and heavy, like Apple Health. Callers scale `size` with `@ScaledMetric`.
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
}
