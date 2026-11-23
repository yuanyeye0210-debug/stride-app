import SwiftUI

// MARK: - Obsidian Carbon 高奢暗黑美学配色系统

enum Palette {
    // 曜石炭黑层级底色（告别死板纯黑，构建深邃空间层次）
    static let bg        = Color(hex: 0x07080C)
    static let surface   = Color(hex: 0x0F1118)
    static let card      = Color(hex: 0x151822)
    static let cardHigh  = Color(hex: 0x1F2433)
    static let cardSoft  = Color(hex: 0x10131C)
    static let stroke    = Color.white.opacity(0.085)
    static let strokeHi  = Color.white.opacity(0.20)
    static let text      = Color(hex: 0xF5F6FA)
    static let textDim   = Color(hex: 0x99A0B3)
    static let textFaint = Color(hex: 0x62687A)

    // 高级纯正语义色（翡翠绿 / 香槟金 / 冰河蓝 / 极光紫 / 绯红珊瑚）
    static let green     = Color(hex: 0x34D88B)
    static let greenText = Color(hex: 0x7CF2B8)
    static let greenDeep = Color(hex: 0x123325)
    static let lime      = Color(hex: 0xC8F542)
    static let yellow    = Color(hex: 0xF4C95D)
    static let amber     = Color(hex: 0xF59E42)
    static let red       = Color(hex: 0xF44D5D)
    static let coral     = Color(hex: 0xD94B43)
    static let coralHi   = Color(hex: 0xFF5E6C)
    static let blue      = Color(hex: 0x4F9DFF)
    static let indigo    = Color(hex: 0x6B7CFF)
    static let cyan      = Color(hex: 0x2DD4BF)
    static let purple    = Color(hex: 0x9E7BFF)
    static let pink      = Color(hex: 0xFF7EB6)

    // Apple Watch 三环标准高亮色
    static let ringMove  = Color(hex: 0xFA114F)
    static let ringEx    = Color(hex: 0xA4FF00)
    static let ringStand = Color(hex: 0x00E5FF)

    // 实体拟物材质色（保留兼容引用）
    static let noteYellow   = Color(hex: 0xFCEB7A)
    static let paperWhite   = Color(hex: 0xF5F5F7)

    // 新增 Obsidian 高奢深邃材质色
    static let obsidianGold  = Color(hex: 0x241F14)
    static let obsidianGlass = Color(hex: 0x181C28)
    static let receiptDark   = Color(hex: 0x161923)
    static let crimsonDark   = Color(hex: 0x28131A)
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

/// 升级后的深炭微渐层玻璃卡片背景 + 方向性镜面折射边框。
struct CardBackground: ViewModifier {
    var radius: CGFloat = Metrics.radius
    var fill: Color = Palette.card
    var stroke: Color? = Palette.stroke
    var lineWidth: CGFloat = 1

    private var isDefaultStroke: Bool {
        stroke == Palette.stroke
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(
                ZStack {
                    shape.fill(fill)
                    shape.fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.038),
                                Color.white.opacity(0.006),
                                Color.black.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            )
            .overlay(
                Group {
                    if let stroke {
                        if isDefaultStroke {
                            shape.strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.17),
                                        Color.white.opacity(0.065),
                                        Color.white.opacity(0.025)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: lineWidth
                            )
                        } else {
                            shape.strokeBorder(
                                LinearGradient(
                                    colors: [
                                        stroke,
                                        stroke.opacity(0.45),
                                        stroke.opacity(0.22)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: lineWidth
                            )
                        }
                    }
                }
            )
            .shadow(color: .black.opacity(0.28), radius: 14, y: 6)
    }
}

/// 借鉴 Ultrahuman / WHOOP 的高奢暗夜玻璃卡片：一角克制氛围光晕 + 顶边 0.6pt 镜面高光。
struct LuxuryCardModifier: ViewModifier {
    var radius: CGFloat = Metrics.radius
    var accent: Color = Palette.green
    var glowCorner: UnitPoint = .topTrailing
    var fill: Color = Palette.card

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(
                ZStack {
                    shape.fill(fill)
                    shape.fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.045),
                                Color.clear,
                                Color.black.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    shape.fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(0.16),
                                accent.opacity(0.04),
                                .clear
                            ],
                            center: glowCorner,
                            startRadius: 4,
                            endRadius: 210
                        )
                    )
                }
            )
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            accent.opacity(0.22),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
            )
            .shadow(color: .black.opacity(0.32), radius: 16, y: 8)
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
                                Color.white.opacity(0.34),
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.20)
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

    /// 曜石深邃氛围玻璃卡片（含单角极光光晕与镜面渐变边）
    func luxuryCard(
        radius: CGFloat = Metrics.radius,
        accent: Color = Palette.green,
        glowCorner: UnitPoint = .topTrailing,
        fill: Color = Palette.card
    ) -> some View {
        modifier(LuxuryCardModifier(radius: radius, accent: accent, glowCorner: glowCorner, fill: fill))
    }

    func liquidGlassCapsule(tint: Color = Color.black.opacity(0.42)) -> some View {
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
    var secondaryAccent: Color = Palette.blue

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            RadialGradient(
                colors: [accent.opacity(0.085), accent.opacity(0.02), .clear],
                center: .init(x: 0.5, y: -0.16),
                startRadius: 10,
                endRadius: 400
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [secondaryAccent.opacity(0.045), .clear],
                center: .init(x: 0.88, y: 0.95),
                startRadius: 10,
                endRadius: 340
            )
            .ignoresSafeArea()
        }
    }
}
