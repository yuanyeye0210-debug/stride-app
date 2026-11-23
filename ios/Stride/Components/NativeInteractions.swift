import SwiftUI
import UIKit

// MARK: - 全局预热零阻塞触觉反馈单例（消除每次点击新建 UIImpactFeedbackGenerator 导致的 20-40ms 主线程 XPC 卡顿）

@MainActor
final class StrideHaptics {
    static let shared = StrideHaptics()

    private let lightGen = UIImpactFeedbackGenerator(style: .light)
    private let mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGen = UIImpactFeedbackGenerator(style: .heavy)
    private let softGen = UIImpactFeedbackGenerator(style: .soft)
    private let rigidGen = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionGen = UISelectionFeedbackGenerator()
    private let notifyGen = UINotificationFeedbackGenerator()

    private var lastFireTime: TimeInterval = 0
    private let minInterval: TimeInterval = 0.045

    private init() {
        lightGen.prepare()
        mediumGen.prepare()
        softGen.prepare()
        rigidGen.prepare()
        selectionGen.prepare()
    }

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat = 0.65) {
        let now = CACurrentMediaTime()
        guard now - lastFireTime >= minInterval else { return }
        lastFireTime = now

        switch style {
        case .light:
            lightGen.impactOccurred(intensity: intensity)
            lightGen.prepare()
        case .medium:
            mediumGen.impactOccurred(intensity: intensity)
            mediumGen.prepare()
        case .heavy:
            heavyGen.impactOccurred(intensity: intensity)
            heavyGen.prepare()
        case .soft:
            softGen.impactOccurred(intensity: intensity)
            softGen.prepare()
        case .rigid:
            rigidGen.impactOccurred(intensity: intensity)
            rigidGen.prepare()
        @unknown default:
            lightGen.impactOccurred(intensity: intensity)
        }
    }

    func selection() {
        let now = CACurrentMediaTime()
        guard now - lastFireTime >= minInterval else { return }
        lastFireTime = now
        selectionGen.selectionChanged()
        selectionGen.prepare()
    }

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let now = CACurrentMediaTime()
        guard now - lastFireTime >= minInterval else { return }
        lastFireTime = now
        notifyGen.notificationOccurred(type)
        notifyGen.prepare()
    }
}

// MARK: - Apple 原生极速跟手按压弹性 ButtonStyle（120Hz 零延迟响应）

/// 通用按压弹性按钮样式：按下微缩并伴随超快物理弹簧回弹。
struct StridePressButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var pressedOpacity: Double = 0.88
    var haptic: UIImpactFeedbackGenerator.FeedbackStyle? = .light

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? pressedOpacity : 1.0)
            .animation(.snappy(duration: 0.14), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed, let haptic {
                    StrideHaptics.shared.impact(haptic, intensity: 0.55)
                }
            }
    }
}

/// 卡片按压弹性 + 边缘微光点亮样式：按下时边框点亮并极速回弹（零离屏阴影重算）。
struct StrideCardButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 22
    var scale: CGFloat = 0.976

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(configuration.isPressed ? 0.28 : 0.0),
                        lineWidth: 1.0
                    )
                    .allowsHitTesting(false)
            )
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.snappy(duration: 0.14), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    StrideHaptics.shared.impact(.light, intensity: 0.5)
                }
            }
    }
}

extension ButtonStyle where Self == StridePressButtonStyle {
    static var stridePress: StridePressButtonStyle { StridePressButtonStyle() }
}

extension ButtonStyle where Self == StrideCardButtonStyle {
    static var strideCard: StrideCardButtonStyle { StrideCardButtonStyle() }

    static func strideCard(radius: CGFloat) -> StrideCardButtonStyle {
        StrideCardButtonStyle(cornerRadius: radius)
    }
}

/// 列表行按压弹性 + 轻底色高亮样式：适配列表行、设置项、日历格等中等密度容器。
struct StrideRowButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.984
    var cornerRadius: CGFloat = 14
    var haptic: UIImpactFeedbackGenerator.FeedbackStyle? = .light

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.05 : 0.0))
            )
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed, let haptic {
                    StrideHaptics.shared.impact(haptic, intensity: 0.45)
                }
            }
    }
}

extension ButtonStyle where Self == StrideRowButtonStyle {
    static var strideRow: StrideRowButtonStyle { StrideRowButtonStyle() }

    static func strideRow(radius: CGFloat) -> StrideRowButtonStyle {
        StrideRowButtonStyle(cornerRadius: radius)
    }
}

private struct StrideAppearModifier: ViewModifier {
    var delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 6)
            .onAppear {
                guard !shown else { return }
                withAnimation(.snappy(duration: 0.24).delay(delay)) {
                    shown = true
                }
            }
    }
}

// MARK: - 滚动过渡、数字跳变、半屏抽屉、iOS 18 原生 Zoom 转场兼容封装

extension View {
    /// 极轻量滚动过渡（避免在复杂卡片列表滚动时触发多图层离屏缩放重排）。
    func strideScrollDepth(minScale: CGFloat = 0.96, minOpacity: Double = 0.85) -> some View {
        self
    }

    /// 数字翻页滚动过渡（`.contentTransition(.numericText())`）。
    func numericRoll<V: Equatable>(value: V, countsDown: Bool = false) -> some View {
        self
            .contentTransition(.numericText(countsDown: countsDown))
            .animation(.snappy(duration: 0.24), value: value)
    }

    /// 原生可拖拽半屏/全屏 Sheet 高度配置。
    func strideSheetDetents(_ detents: Set<PresentationDetent> = [.medium, .large]) -> some View {
        self
            .presentationDetents(detents)
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
    }

    /// iOS 18+ 原生卡片放大转场起点；iOS 17 自动无感降级。
    @ViewBuilder
    func strideZoomSource<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// iOS 18+ 原生卡片放大转场终点；iOS 17 自动无感降级。
    @ViewBuilder
    func strideZoomDestination<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }

    /// 轻量入场平滑上浮渐显动画。
    func strideAppear(delay: Double = 0) -> some View {
        modifier(StrideAppearModifier(delay: delay))
    }

    /// 图标微弹跳（iOS 17+ 原生 `.symbolEffect(.bounce)`）。
    func strideSymbolBounce<V: Equatable>(trigger: V) -> some View {
        self.symbolEffect(.bounce, value: trigger)
    }

    /// 卡片可按压微缩交互与发光边框便捷包装。
    func strideCardInteractive(cornerRadius: CGFloat = 22) -> some View {
        self
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .hoverEffect(.highlight)
    }
}
