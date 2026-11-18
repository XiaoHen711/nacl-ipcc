import SwiftUI

/// 颜色/尺寸令牌。改这里就能换整套皮肤。
enum Theme {
    static let bg = Color(hex: 0x060A08)
    static let screen = Color(hex: 0x0A0F0C)
    static let card = Color(hex: 0x111815)
    static let field = Color(hex: 0x0C1210)
    static let line = Color.white.opacity(0.075)

    static let text = Color(hex: 0xECF4EF)
    static let muted = Color(hex: 0x8B9C93)
    static let faint = Color(hex: 0x5D6D66)

    static let accent = Color(hex: 0x3BE08F)
    static let accentDeep = Color(hex: 0x2BBD77)
    static let onAccent = Color(hex: 0x04170D)
    static let danger = Color(hex: 0xFF6A6A)
    static let warn = Color(hex: 0xFFB454)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
