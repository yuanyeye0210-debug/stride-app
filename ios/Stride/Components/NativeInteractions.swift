import SwiftUI
import UIKit

// MARK: - Apple 原生按压弹性与微光高亮 ButtonStyle

/// 通用按压弹性按钮样式：按下微缩并伴随物理弹簧回弹。
struct StridePressButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var pressedOpacity: Double = 0.88
    var haptic: UIImpactFeedbackGenerator.FeedbackStyle? = .light

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? pressedOpacity : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed, let haptic {
                    UIImpactFeedbackGenerator(style: haptic).impactOccurred(intensity: 0.55)
                }
            }
    }
}

/// 卡片按压弹性 + 边缘微光点亮样式：按下时边框泛起柔和高光并微缩。
struct StrideCardButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 22
    var scale: CGFloat = 0.972

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(configuration.isPressed ? 0.34 : 0.0),
                        lineWidth: 1.2
                    )
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(configuration.isPressed ? 0.05 : 0.0))
                    )
                    .allowsHitTesting(false)
            )
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.74), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
                }
            }
    }
}

extension ButtonStyle where Self == StridePressButtonStyle {
    static var stridePress: StridePressButtonStyle { StridePressButtonStyle() }
}

extension ButtonStyle where Self == StrideCardButtonStyle {
    static var strideCard: StrideCardButtonStyle { StrideCardButtonStyle() }
}

// MARK: - 滚动景深、数字跳变、半屏抽屉、iOS 18 原生 Zoom 转场兼容封装

extension View {
    /// 列表滚动景深过渡（iOS 17+ 原生 `.scrollTransition`）：滑入/离开视口边缘时柔和缩放与渐显。
    func strideScrollDepth(minScale: CGFloat = 0.94, minOpacity: Double = 0.7) -> some View {
        self.scrollTransition(.interactive.threshold(.visible(0.18))) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1.0 : minScale)
                .opacity(phase.isIdentity ? 1.0 : minOpacity)
        }
    }

    /// 数字翻页滚动过渡（`.contentTransition(.numericText())`）。
    func numericRoll<V: Equatable>(value: V, countsDown: Bool = false) -> some View {
        self
            .contentTransition(.numericText(countsDown: countsDown))
            .animation(.snappy(duration: 0.35), value: value)
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
}
