import SwiftUI

// MARK: - Palette

enum Palette {
    static let bg        = Color(hex: 0x000000)
    static let surface   = Color(hex: 0x0E0E10)
    static let card      = Color(hex: 0x161618)
    static let cardHigh  = Color(hex: 0x222226)
    static let cardSoft  = Color(hex: 0x121214)
    static let stroke    = Color.white.opacity(0.08)
    static let strokeHi  = Color.white.opacity(0.16)
    static let text      = Color.white
    static let textDim   = Color(hex: 0x9A9AA1)
    static let textFaint = Color(hex: 0x66666D)

    // 功能语义色
    static let green     = Color(hex: 0x3FD47A)
    static let greenText = Color(hex: 0x7BEDA9)
    static let greenDeep = Color(hex: 0x16351F)
    static let lime      = Color(hex: 0xD2FF37)
    static let yellow    = Color(hex: 0xF6D258)
    static let amber     = Color(hex: 0xFFB86B)
    static let red       = Color(hex: 0xFF6B6B)
    static let coral     = Color(hex: 0xC93B2B)
    static let coralHi   = Color(hex: 0xFF5A5F)
    static let blue      = Color(hex: 0x529BFF)
    static let indigo    = Color(hex: 0x6F7BFF)
    static let cyan      = Color(hex: 0x00E5FF)
    static let purple    = Color(hex: 0x9B87FF)
    static let pink      = Color(hex: 0xFF87B7)

    // Apple Watch 三环标准高亮色
    static let ringMove  = Color(hex: 0xFA114F)
    static let ringEx    = Color(hex: 0xA4FF00)
    static let ringStand = Color(hex: 0x00E5FF)

    // 实体拟物卡片色
    static let noteYellow   = Color(hex: 0xFCEB7A)
    static let paperWhite   = Color(hex: 0xF5F5F7)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - Metrics

enum Metrics {
    static let radius: CGFloat = 24
    static let radiusSmall: CGFloat = 16
    static let radiusTiny: CGFloat = 10
    static let page: CGFloat = 16
    static let gap: CGFloat = 12
    /// 底部悬浮液态玻璃导航栏预留安全滚动空间
    static let floatingTabBottomInset: CGFloat = 92
}

// MARK: - Card & Liquid Glass

struct CardBackground: ViewModifier {
    var radius: CGFloat = Metrics.radius
    var fill: Color = Palette.card
    var stroke: Color? = Palette.stroke
    var lineWidth: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(stroke ?? .clear, lineWidth: lineWidth)
            )
    }
}

struct LiquidGlassCapsuleModifier: ViewModifier {
    var tint: Color = Color.white.opacity(0.08)

    func body(content: Content) -> some View {
        content
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule(style: .continuous).fill(tint))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.32),
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
            }
            .shadow(color: .black.opacity(0.45), radius: 20, y: 10)
    }
}

extension View {
    func card(
        radius: CGFloat = Metrics.radius,
        fill: Color = Palette.card,
        stroke: Color? = Palette.stroke,
        lineWidth: CGFloat = 1
    ) -> some View {
        modifier(CardBackground(radius: radius, fill: fill, stroke: stroke, lineWidth: lineWidth))
    }

    func liquidGlassCapsule(tint: Color = Color.black.opacity(0.38)) -> some View {
        modifier(LiquidGlassCapsuleModifier(tint: tint))
    }

    func pagePadding() -> some View {
        padding(.horizontal, Metrics.page)
    }
}

// MARK: - Typography helpers

extension Font {
    static func mono(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Screen scaffold

struct ScreenBackground: View {
    var accent: Color = Palette.green

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            RadialGradient(
                colors: [accent.opacity(0.06), .clear],
                center: .init(x: 0.5, y: -0.18),
                startRadius: 10,
                endRadius: 380
            )
            .ignoresSafeArea()
        }
    }
}
