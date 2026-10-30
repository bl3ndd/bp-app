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

/// "Logbook" look: warm paper, ink-blue text and the icon's blue, white cards
/// with a hairline instead of shadows. Category colors are the AHA chart colors
/// people know from the doctor's office, darkened in light mode for contrast.
enum AppColors {
    static let bgApp = Color(light: 0xF6F3EC, dark: 0x1A1916)
    static let bgCard = Color(light: 0xFFFFFF, dark: 0x24221E)
    /// Fills for inputs, segmented tracks and inactive chips.
    static let bgInput = Color(light: 0xEFEBE2, dark: 0x2F2C27)

    static let textPrimary = Color(light: 0x1B2333, dark: 0xF3EFE6)
    static let textSecondary = Color(light: 0x575D6B, dark: 0xBDB7AC)
    static let separator = Color(light: 0xE6E0D3, dark: 0x34312B)

    static let accent = Color(light: 0x2F5FD0, dark: 0x7EA2F2)
    static let accentTint = Color(light: 0xE5ECFB, dark: 0x26324D)

    static let systolic = Color(light: 0x2F5FD0, dark: 0x7EA2F2)
    static let diastolic = Color(light: 0x0891B2, dark: 0x67E8F9)
    static let pulse = Color(light: 0x6B7280, dark: 0x9CA3AF)

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

    /// Short name for the scale under a reading.
    var shortTitle: String {
        switch self {
        case .low: "Low"
        case .normal: "Normal"
        case .elevated: "Elevated"
        case .stage1: "Stage 1"
        case .stage2: "Stage 2"
        case .crisis: "Crisis"
        }
    }
}

enum AppFont {
    /// Reading numbers: rounded and heavy, like Apple Health. Callers scale `size` with `@ScaledMetric`.
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
}

enum AppShape {
    static let cardRadius: CGFloat = 22
}
