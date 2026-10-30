import Foundation
import SwiftUI

/// Copy of the app's `WidgetSnapshot` (BPLog/Services/WidgetBridge.swift): change both together.
struct WidgetSnapshot: Codable, Equatable {
    var systolic: Int
    var diastolic: Int
    var pulse: Int?
    var date: Date
    var categoryRaw: Int
    var categoryTitle: String
    var weekSystolic: Int?
    var weekDiastolic: Int?

    static let appGroup = "group.white.tea.BPLog"
    static let key = "widgetSnapshot"
    static let addURL = URL(string: "simplybp://add")!

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static let sample = WidgetSnapshot(systolic: 128, diastolic: 82, pulse: 70, date: Date().addingTimeInterval(-3600),
                                       categoryRaw: 2, categoryTitle: "High · Stage 1", weekSystolic: 126, weekDiastolic: 81)

    /// The app's AHA category colors (BPCategory.color), light and dark.
    var categoryColor: Color {
        switch categoryRaw {
        case -1: Color(light: 0x4338CA, dark: 0xA5B4FC)
        case 0: Color(light: 0x15803D, dark: 0x4ADE80)
        case 1: Color(light: 0xA16207, dark: 0xFACC15)
        case 2: Color(light: 0xC2410C, dark: 0xFB923C)
        case 3: Color(light: 0xB91C1C, dark: 0xF87171)
        default: Color(light: 0x7F1D1D, dark: 0xFCA5A5)
        }
    }
}

extension Color {
    static let brand = Color(light: 0x1D4ED8, dark: 0x60A5FA)

    init(light: UInt, dark: UInt) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}
