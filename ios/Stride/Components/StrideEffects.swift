import SwiftUI
import UIKit

// MARK: - 1. 物理水波纹按钮样式 + Metal 涟漪触发器 + 液面波浪画布

/// 饮水、补水与液体交互专属按钮：软弹缩 + 冰蓝波纹圈脉冲 + 轻柔触觉反馈。
struct WaterRippleButtonStyle: ButtonStyle {
    var accent: Color = Palette.blue
    var scale: CGFloat = 0.91

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .overlay {
                Circle()
                    .strokeBorder(accent.opacity(configuration.isPressed ? 0.55 : 0), lineWidth: 1.8)
                    .scaleEffect(configuration.isPressed ? 1.32 : 0.92)
                    .allowsHitTesting(false)
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.68), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.85)
                }
            }
    }
}

extension ButtonStyle where Self == WaterRippleButtonStyle {
    static var strideWater: WaterRippleButtonStyle { WaterRippleButtonStyle() }

    static func strideWater(accent: Color) -> WaterRippleButtonStyle {
        WaterRippleButtonStyle(accent: accent)
    }
}

/// 点击/数值变化时触发一次 Metal 物理阻尼水波纹扩散。
struct WaterRippleModifier<Trigger: Equatable>: ViewModifier {
    var trigger: Trigger
    var amplitude: Float = 8
    var frequency: Float = 18
    var decay: Float = 5.5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rippleStart: Date?
    @State private var boxSize: CGSize = CGSize(width: 160, height: 160)

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: rippleStart == nil)) { timeline in
                let elapsed: Float = {
                    guard let start = rippleStart else { return 0 }
                    let diff = Float(timeline.date.timeIntervalSince(start))
                    return (diff > 0 && diff < 1.1) ? diff : 0
                }()
                let origin = CGPoint(x: boxSize.width * 0.5, y: boxSize.height * 0.62)
                content
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { boxSize = geo.size }
                                .onChange(of: geo.size) { _, newSize in boxSize = newSize }
                        }
                    )
                    .layerEffect(
                        ShaderLibrary.strideRipple(
                            .float2(origin),
                            .float(elapsed),
                            .float(amplitude),
                            .float(frequency),
                            .float(decay)
                        ),
                        maxSampleOffset: CGSize(width: 24, height: 24),
                        isEnabled: elapsed > 0
                    )
                    .onChange(of: timeline.date) { _, now in
                        if let start = rippleStart, now.timeIntervalSince(start) >= 1.1 {
                            rippleStart = nil
                        }
                    }
            }
            .onChange(of: trigger) { _, _ in
                rippleStart = Date()
            }
        }
    }
}

/// 液面波动填充画布（双层反相正弦波 + 上升微气泡，加减水瞬间波浪振幅激增后阻尼回稳）。
struct WaterWaveCanvas: View {
    var progress: Double
    var color: Color = Palette.blue
    var boostTrigger: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var boostStart: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let boostAmp: CGFloat = {
                guard let start = boostStart else { return 0 }
                let dt = timeline.date.timeIntervalSince(start)
                return dt < 1.4 ? CGFloat(exp(-dt * 2.2) * 5.0) : 0
            }()

            Canvas { ctx, size in
                let clamped = min(1.0, max(0.03, progress))
                let waterTop = size.height * (1.0 - clamped)

                // 后波
                var backWave = Path()
                backWave.move(to: CGPoint(x: 0, y: size.height))
                let ampBack: CGFloat = (reduceMotion ? 1.5 : 3.4) + boostAmp * 0.8
                for x in stride(from: 0.0, through: Double(size.width), by: 3.0) {
                    let phase = (x / max(1.0, Double(size.width))) * .pi * 2.2 - time * 1.9
                    let y = waterTop + CGFloat(sin(phase)) * ampBack
                    backWave.addLine(to: CGPoint(x: x, y: y))
                }
                backWave.addLine(to: CGPoint(x: size.width, y: size.height))
                backWave.closeSubpath()
                ctx.fill(backWave, with: .color(color.opacity(0.24)))

                // 前波
                var frontWave = Path()
                frontWave.move(to: CGPoint(x: 0, y: size.height))
                let ampFront: CGFloat = (reduceMotion ? 1.2 : 4.2) + boostAmp
                for x in stride(from: 0.0, through: Double(size.width), by: 3.0) {
                    let phase = (x / max(1.0, Double(size.width))) * .pi * 2.6 + time * 2.4
                    let y = waterTop + CGFloat(sin(phase)) * ampFront + 2
                    frontWave.addLine(to: CGPoint(x: x, y: y))
                }
                frontWave.addLine(to: CGPoint(x: size.width, y: size.height))
                frontWave.closeSubpath()
                ctx.fill(
                    frontWave,
                    with: .linearGradient(
                        Gradient(colors: [color.opacity(0.48), color.opacity(0.18)]),
                        startPoint: CGPoint(x: 0, y: waterTop),
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )

                // 上浮气泡
                if clamped > 0.1 && !reduceMotion {
                    for idx in 0..<5 {
                        let seed = Double(idx) * 0.21
                        let cycle = (time * (0.28 + Double(idx) * 0.05) + seed).truncatingRemainder(dividingBy: 1.0)
                        let bx = size.width * CGFloat(0.16 + Double(idx) * 0.17) + CGFloat(sin(time * 2 + Double(idx))) * 3
                        let span = max(8, size.height - waterTop)
                        let by = size.height - CGFloat(cycle) * span
                        if by > waterTop + 3 {
                            let r: CGFloat = idx % 2 == 0 ? 2.4 : 1.7
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: bx - r, y: by - r, width: r * 2, height: r * 2)),
                                with: .color(Color.white.opacity(0.32 * (1 - cycle * 0.5)))
                            )
                        }
                    }
                }
            }
        }
        .onChange(of: boostTrigger) { _, _ in
            boostStart = Date()
        }
    }
}

// MARK: - 2. 力量打卡爆发粒子按钮 + ConfettiBurstView

/// 打卡成功瞬间向四周迸发翡翠/香槟金/冰青微粒火花。
struct ConfettiBurstView: View {
    var trigger: Int
    var colors: [Color] = [Palette.green, Palette.lime, Palette.yellow, Palette.cyan]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false

    private let particleCount = 8

    var body: some View {
        ZStack {
            if !reduceMotion {
                Circle()
                    .strokeBorder(colors.first ?? Palette.green, lineWidth: animating ? 0.5 : 2.5)
                    .frame(width: animating ? 46 : 16, height: animating ? 46 : 16)
                    .opacity(animating ? 0 : 0.85)

                ForEach(0..<particleCount, id: \.self) { idx in
                    let angle = (Double(idx) / Double(particleCount)) * .pi * 2.0
                    let radius: CGFloat = animating ? (idx % 2 == 0 ? 24 : 18) : 2
                    Circle()
                        .fill(colors[idx % colors.count])
                        .frame(width: idx % 2 == 0 ? 4.5 : 3.2, height: idx % 2 == 0 ? 4.5 : 3.2)
                        .offset(
                            x: CGFloat(cos(angle)) * radius,
                            y: CGFloat(sin(angle)) * radius
                        )
                        .opacity(animating ? 0 : 1)
                        .scaleEffect(animating ? 0.4 : 1.15)
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            guard !reduceMotion else { return }
            animating = false
            withAnimation(.easeOut(duration: 0.48)) {
                animating = true
            }
        }
    }
}

/// 力量组完成打勾 / 补剂打卡专属按键：弹性过冲 + 彩色火花爆炸 + 成功震动。
struct SetCheckBurstButton: View {
    let isDone: Bool
    var size: CGFloat = 24
    var accent: Color = Palette.green
    var action: () -> Void

    @State private var burstToken = 0
    @State private var popScale: CGFloat = 1.0

    var body: some View {
        Button {
            let willDone = !isDone
            action()
            if willDone {
                burstToken += 1
                withAnimation(.spring(response: 0.24, dampingFraction: 0.48)) {
                    popScale = 1.26
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                        popScale = 1.0
                    }
                }
            }
        } label: {
            ZStack {
                ConfettiBurstView(trigger: burstToken, colors: [accent, Palette.lime, Palette.yellow, Palette.cyan])
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(isDone ? accent : Palette.strokeHi)
                    .symbolEffect(.bounce, value: isDone)
                    .scaleEffect(popScale)
            }
            .frame(width: max(30, size + 10), height: max(30, size + 10))
            .contentShape(Circle())
        }
        .buttonStyle(StridePressButtonStyle(scale: 0.88, pressedOpacity: 0.9, haptic: isDone ? .light : .medium))
        .sensoryFeedback(.success, trigger: burstToken)
    }
}

// MARK: - 3. 钛金流光扫过 CTA 按钮样式（Metal Shader）

struct ShimmerCTAButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var glowColor: Color = Palette.green

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(ShimmerSweepModifier(enabled: !reduceMotion))
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .shadow(color: glowColor.opacity(configuration.isPressed ? 0.15 : 0.28), radius: configuration.isPressed ? 6 : 14, y: 4)
            .animation(.spring(response: 0.26, dampingFraction: 0.72), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.75)
                }
            }
    }
}

private struct ShimmerSweepModifier: ViewModifier {
    var enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let cycle = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.4)
                let phase = cycle < 1.3 ? Float(-0.4 + (cycle / 1.3) * 1.9) : Float(-1.0)
                content.visualEffect { view, proxy in
                    view.colorEffect(
                        ShaderLibrary.strideShimmerSweep(
                            .float2(proxy.size),
                            .float(phase)
                        )
                    )
                }
            }
        } else {
            content
        }
    }
}

extension ButtonStyle where Self == ShimmerCTAButtonStyle {
    static var strideShimmer: ShimmerCTAButtonStyle { ShimmerCTAButtonStyle() }

    static func strideShimmer(glow: Color) -> ShimmerCTAButtonStyle {
        ShimmerCTAButtonStyle(glowColor: glow)
    }
}

// MARK: - 4. 长按蓄力确认环形按钮（防误触关键操作）

/// 长按蓄力 `duration` 秒后触发完成；途中渐进心跳震动，松手则弹簧归零。
struct HoldToConfirmCircleButton: View {
    let title: String
    var icon: String = "stop.fill"
    var tint: Color = Palette.coralHi
    var duration: Double = 0.85
    var onConfirm: () -> Void

    @State private var isHolding = false
    @State private var progress: CGFloat = 0
    @State private var completed = false
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 34, height: 34)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
                    .frame(width: 34, height: 34)
                    .rotationEffect(.degrees(-90))
                Image(systemName: completed ? "checkmark" : icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(completed ? Palette.green : tint)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(completed ? "已确认" : (isHolding ? "保持按住…" : title))
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(Palette.text)
                Text("长按 0.8 秒防误触")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.textFaint)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            ZStack(alignment: .leading) {
                Capsule(style: .continuous).fill(Palette.cardHigh)
                GeometryReader { geo in
                    Capsule(style: .continuous)
                        .fill(tint.opacity(0.24))
                        .frame(width: geo.size.width * progress)
                }
            }
        )
        .overlay(Capsule(style: .continuous).strokeBorder(tint.opacity(isHolding ? 0.65 : 0.22), lineWidth: 1))
        .scaleEffect(isHolding ? 0.96 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.72), value: isHolding)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isHolding, !completed else { return }
                    startHold()
                }
                .onEnded { _ in
                    cancelHold()
                }
        )
    }

    private func startHold() {
        isHolding = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            let steps = 18
            let stepNs = UInt64((duration / Double(steps)) * 1_000_000_000)
            for idx in 1...steps {
                try? await Task.sleep(nanoseconds: stepNs)
                if Task.isCancelled || !isHolding { return }
                withAnimation(.linear(duration: duration / Double(steps))) {
                    progress = CGFloat(idx) / CGFloat(steps)
                }
                if idx % 5 == 0 {
                    let strength = CGFloat(idx) / CGFloat(steps)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: min(1.0, 0.4 + strength * 0.6))
                }
            }
            completed = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onConfirm()
            try? await Task.sleep(nanoseconds: 350_000_000)
            completed = false
            isHolding = false
            progress = 0
        }
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
        if !completed {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                isHolding = false
                progress = 0
            }
        }
    }
}

// MARK: - 5. 金属滑轨完成滑块（SlideToCompleteBar）

/// 金属轨道横向滑动完成组件（拖到 82% 以上锁定完成并弹出反馈）。
struct SlideToCompleteBar: View {
    let title: String
    var tint: Color = Palette.green
    var icon: String = "checkmark"
    var onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var completed = false
    @State private var arrowPulse = false

    private let knobSize: CGFloat = 48
    private let trackHeight: CGFloat = 56

    var body: some View {
        GeometryReader { geo in
            let maxDrag = max(1, geo.size.width - knobSize - 8)
            let ratio = min(1, max(0, dragOffset / maxDrag))

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Palette.card)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [tint.opacity(0.45), Palette.stroke],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.32), tint.opacity(0.12)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: knobSize + 8 + dragOffset)

                HStack(spacing: 4) {
                    Text(completed ? "完成训练！" : title)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(completed ? tint : Palette.text.opacity(Double(max(0.25, 1.0 - ratio * 1.1))))
                    if !completed {
                        Image(systemName: "chevron.right.2")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(tint.opacity(arrowPulse ? 0.95 : 0.35))
                            .offset(x: arrowPulse ? 3 : 0)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.leading, 22)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: knobSize, height: knobSize)
                    .overlay {
                        Image(systemName: completed ? "checkmark" : icon)
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(Color.black)
                            .symbolEffect(.bounce, value: completed)
                    }
                    .shadow(color: tint.opacity(0.45), radius: 10, y: 2)
                    .padding(.leading, 4)
                    .offset(x: dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard !completed else { return }
                                dragOffset = min(maxDrag, max(0, value.translation.width))
                            }
                            .onEnded { _ in
                                guard !completed else { return }
                                if dragOffset >= maxDrag * 0.82 {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.72)) {
                                        dragOffset = maxDrag
                                        completed = true
                                    }
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    onComplete()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            completed = false
                                            dragOffset = 0
                                        }
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                                        dragOffset = 0
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.35)
                                }
                            }
                    )
            }
        }
        .frame(height: trackHeight)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                arrowPulse = true
            }
        }
    }
}

// MARK: - 6. 360° 旋转刷新按钮样式（SpinActionButtonStyle）

/// 点击旋转回弹按钮（换一条语录、重排课表、同步刷新、齿轮操作）。
struct SpinActionButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .rotationEffect(.degrees(configuration.isPressed ? -28 : 0))
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.65)
                }
            }
    }
}

extension ButtonStyle where Self == SpinActionButtonStyle {
    static var strideSpin: SpinActionButtonStyle { SpinActionButtonStyle() }
}

// MARK: - 7. 心跳弹性按钮样式（HeartPopButtonStyle）

/// 红心收藏、Apple Health 心跳同步、AI 回复点赞专属双峰弹性样式。
struct HeartPopButtonStyle: ButtonStyle {
    var accent: Color = Palette.pink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.22 : 1.0)
            .shadow(color: accent.opacity(configuration.isPressed ? 0.55 : 0.0), radius: 10)
            .animation(.spring(response: 0.24, dampingFraction: 0.52), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.72)
                }
            }
    }
}

extension ButtonStyle where Self == HeartPopButtonStyle {
    static var strideHeart: HeartPopButtonStyle { HeartPopButtonStyle() }

    static func strideHeart(accent: Color) -> HeartPopButtonStyle {
        HeartPopButtonStyle(accent: accent)
    }
}

// MARK: - 8. 机械棘轮微调按钮样式（StepperTactileButtonStyle）

/// ±2.5kg、±1次、±15秒、倍速切换、步频预设专用机械棘轮手感按键。
struct StepperTactileButtonStyle: ButtonStyle {
    var accent: Color = Palette.green

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(accent.opacity(configuration.isPressed ? 0.7 : 0), lineWidth: 1.2)
                    .allowsHitTesting(false)
            )
            .animation(.spring(response: 0.18, dampingFraction: 0.68), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.85)
                }
            }
    }
}

extension ButtonStyle where Self == StepperTactileButtonStyle {
    static var strideStepper: StepperTactileButtonStyle { StepperTactileButtonStyle() }

    static func strideStepper(accent: Color) -> StepperTactileButtonStyle {
        StepperTactileButtonStyle(accent: accent)
    }
}

// MARK: - 9. 极光流动背景 & AuroraGlowButtonStyle（Metal Shader）

/// 动态 3 色极光弥散纹理（用于 AI 卡片、AI 教练入口、AI 发送球）。
struct AuroraBannerBackground: View {
    var colorA: Color = Color(hex: 0x5E6CFF)
    var colorB: Color = Color(hex: 0xBA5CFF)
    var colorC: Color = Color(hex: 0x2DD4BF)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            LinearGradient(
                colors: [colorA.opacity(0.65), colorB.opacity(0.55), colorC.opacity(0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                let t = Float(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000))
                Rectangle()
                    .fill(colorA.opacity(0.85))
                    .visualEffect { view, proxy in
                        view.colorEffect(
                            ShaderLibrary.strideAuroraFlow(
                                .float2(proxy.size),
                                .float(t),
                                .color(colorA),
                                .color(colorB),
                                .color(colorC)
                            )
                        )
                    }
            }
        }
    }
}

/// AI 悬浮球与智能发送键专属极光按钮样式。
struct AuroraGlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .shadow(
                color: Palette.purple.opacity(configuration.isPressed ? 0.72 : 0.36),
                radius: configuration.isPressed ? 18 : 10
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.68), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.8)
                }
            }
    }
}

extension ButtonStyle where Self == AuroraGlowButtonStyle {
    static var strideAurora: AuroraGlowButtonStyle { AuroraGlowButtonStyle() }
}

// MARK: - 10. 激光扫描光束修饰符（食物拍图 / 扫码）

struct ScanBeamOverlayModifier: ViewModifier {
    var active: Bool
    var color: Color = Palette.green

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if active && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let cycle = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8)
                let norm = cycle / 1.8
                let pingPong = Float(norm < 0.5 ? norm * 2.0 : (1.0 - norm) * 2.0)
                content.visualEffect { view, proxy in
                    view.colorEffect(
                        ShaderLibrary.strideScanBeam(
                            .float2(proxy.size),
                            .float(pingPong),
                            .color(color)
                        )
                    )
                }
            }
        } else {
            content
        }
    }
}

// MARK: - 11. 雷达扩散脉冲波 & BPM 同步音频频谱柱

/// 3 层错相扩散脉冲雷达波（手表动作监测 / 耳机低头提醒 / 节拍打点）。
struct RadarPulseRing: View {
    var color: Color = Palette.green
    var isActive: Bool = true
    var size: CGFloat = 120

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            if isActive && !reduceMotion {
                ForEach(0..<3, id: \.self) { idx in
                    Circle()
                        .strokeBorder(color.opacity(pulse ? 0.0 : 0.55), lineWidth: 1.8)
                        .frame(width: size, height: size)
                        .scaleEffect(pulse ? 1.48 : 0.72)
                        .animation(
                            .easeOut(duration: 1.9)
                            .repeatForever(autoreverses: false)
                            .delay(Double(idx) * 0.62),
                            value: pulse
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { pulse = true }
    }
}

/// 5 根动态音频频谱跳动柱（根据 BPM 与活跃态实时律动）。
struct AudioSpectrumBars: View {
    var isPlaying: Bool
    var bpm: Int = 128
    var color: Color = Palette.green
    var barCount: Int = 5
    var maxHeight: CGFloat = 20

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !isPlaying || reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let freq = max(1.0, Double(bpm) / 60.0) * .pi
            HStack(alignment: .bottom, spacing: 2.5) {
                ForEach(0..<barCount, id: \.self) { i in
                    let h: CGFloat = {
                        guard isPlaying && !reduceMotion else {
                            return maxHeight * (0.28 + CGFloat(i % 3) * 0.14)
                        }
                        let raw = sin(t * freq * 1.4 + Double(i) * 1.15) * 0.5 + 0.5
                        return max(4, maxHeight * CGFloat(0.25 + raw * 0.75))
                    }()
                    Capsule(style: .continuous)
                        .fill(color)
                        .frame(width: 3, height: h)
                }
            }
            .frame(height: maxHeight, alignment: .bottom)
        }
    }
}

// MARK: - 12. 物理刻度尺数学 & 滚动选值器 + 跑步 3-2-1-GO 倒计时 + 柱图准星组件

enum TactileRulerMath {
    /// 限制值合法化并吸附至 `step`（例如 0.1kg）的整数倍。
    static func clampAndSnap(_ value: Double, range: ClosedRange<Double>, step: Double) -> Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let s = max(0.01, step)
        let snapped = (clamped / s).rounded() * s
        return (snapped * 1000).rounded() / 1000
    }

    /// 计算与水平拖拽偏移（每 `pointsPerStep` pt 对应 `step` 单位）后的新数值。
    static func valueForDrag(startValue: Double, translationX: CGFloat, pointsPerStep: CGFloat, step: Double, range: ClosedRange<Double>) -> Double {
        let stepsDelta = Double(-translationX / max(1, pointsPerStep))
        return clampAndSnap(startValue + stepsDelta * step, range: range, step: step)
    }
}

/// 精密物理刻度卷尺滑块（支持手指左右平滑拖拽，每跨 0.1kg 发出脆响哒哒触觉）。
struct TactileRulerSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 35...160
    var step: Double = 0.1
    var unit: String = "kg"
    var accent: Color = Palette.green

    @State private var dragStartValue: Double?

    private let pointsPerStep: CGFloat = 10

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", value))
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.text)
                    .monospacedDigit()
                    .numericRoll(value: value)
                Text(unit)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(accent)
            }

            GeometryReader { geo in
                let centerX = geo.size.width / 2
                let halfSpan = Int((geo.size.width / pointsPerStep) / 2) + 4
                let currentTick = Int((value / step).rounded())

                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Palette.cardSoft)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Palette.stroke, lineWidth: 1)
                        )

                    Canvas { ctx, size in
                        let midX = size.width / 2
                        for tick in (currentTick - halfSpan)...(currentTick + halfSpan) {
                            let val = Double(tick) * step
                            guard val >= range.lowerBound - 0.001 && val <= range.upperBound + 0.001 else { continue }
                            let x = midX + CGFloat(Double(tick) - value / step) * pointsPerStep
                            let isMajor = tick % 10 == 0
                            let isHalf = tick % 5 == 0 && !isMajor
                            let tickH: CGFloat = isMajor ? 28 : (isHalf ? 19 : 11)
                            let topY = size.height - tickH - 8

                            var p = Path()
                            p.move(to: CGPoint(x: x, y: topY))
                            p.addLine(to: CGPoint(x: x, y: size.height - 8))
                            ctx.stroke(
                                p,
                                with: .color(isMajor ? Color.white.opacity(0.75) : Color.white.opacity(isHalf ? 0.42 : 0.2)),
                                lineWidth: isMajor ? 1.8 : 1
                            )

                            if isMajor {
                                let label = Text("\(Int(val.rounded()))")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(Palette.textDim)
                                ctx.draw(label, at: CGPoint(x: x, y: 14))
                            }
                        }
                    }

                    // 中心绿色激光指针
                    VStack(spacing: 0) {
                        Circle()
                            .fill(accent)
                            .frame(width: 7, height: 7)
                        Rectangle()
                            .fill(accent)
                            .frame(width: 2.4, height: 48)
                    }
                    .position(x: centerX, y: geo.size.height / 2 + 2)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { gesture in
                            if dragStartValue == nil {
                                dragStartValue = value
                            }
                            let start = dragStartValue ?? value
                            let next = TactileRulerMath.valueForDrag(
                                startValue: start,
                                translationX: gesture.translation.width,
                                pointsPerStep: pointsPerStep,
                                step: step,
                                range: range
                            )
                            if abs(next - value) >= step * 0.5 {
                                value = next
                            }
                        }
                        .onEnded { _ in
                            dragStartValue = nil
                        }
                )
            }
            .frame(height: 76)
            .sensoryFeedback(.selection, trigger: Int((value / step).rounded()))
        }
    }
}

/// 跑步开启 3 → 2 → 1 → GO 全屏弹性倒计时遮罩。
struct CountdownOverlayView: View {
    var tint: Color = Palette.lime
    var onFinished: () -> Void
    var onCancel: () -> Void

    @State private var stepText = "3"
    @State private var scale: CGFloat = 1.4
    @State private var opacity: Double = 0
    @State private var task: Task<Void, Never>?

    var body: some View {
        ZStack {
            Palette.bg.opacity(0.92).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                Text("准备开跑")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.textDim)

                Text(stepText)
                    .font(.system(size: stepText == "GO" ? 84 : 112, weight: .black, design: .rounded))
                    .foregroundStyle(stepText == "GO" ? tint : Palette.text)
                    .scaleEffect(scale)
                    .opacity(opacity)

                Spacer()

                HStack(spacing: 14) {
                    Button("取消") {
                        task?.cancel()
                        onCancel()
                    }
                    .buttonStyle(.stridePress)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.textDim)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Palette.cardHigh))

                    Button("立即出发") {
                        task?.cancel()
                        onFinished()
                    }
                    .buttonStyle(.strideShimmer(glow: tint))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(tint))
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear { runSequence() }
        .onDisappear { task?.cancel() }
    }

    private func runSequence() {
        task?.cancel()
        task = Task { @MainActor in
            let seq: [(String, UIImpactFeedbackGenerator.FeedbackStyle)] = [
                ("3", .light), ("2", .medium), ("1", .heavy), ("GO", .heavy)
            ]
            for (idx, item) in seq.enumerated() {
                if Task.isCancelled { return }
                stepText = item.0
                scale = 1.45
                opacity = 0.2
                UIImpactFeedbackGenerator(style: item.1).impactOccurred()
                withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) {
                    scale = 1.0
                    opacity = 1.0
                }
                let waitNs: UInt64 = idx == seq.count - 1 ? 480_000_000 : 780_000_000
                try? await Task.sleep(nanoseconds: waitNs)
            }
            if !Task.isCancelled {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onFinished()
            }
        }
    }
}

/// 柱状图交互准星条带（按住并左右拖动柱状图，实时显示当前指向柱子的数值浮标 + selection 触觉）。
struct InteractiveBarChartScrubber<Item: Identifiable>: View {
    let items: [Item]
    let valueProvider: (Item) -> Double
    let labelProvider: (Item) -> String
    let valueTextProvider: (Item) -> String
    var barColor: Color = Palette.lime
    var height: CGFloat = 120

    @State private var selectedIndex: Int?

    var body: some View {
        let maxVal = max(1.0, items.map(valueProvider).max() ?? 1.0)
        VStack(spacing: 8) {
            if let idx = selectedIndex, items.indices.contains(idx) {
                HStack(spacing: 6) {
                    Circle().fill(barColor).frame(width: 6, height: 6)
                    Text("\(labelProvider(items[idx])) · \(valueTextProvider(items[idx]))")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.text)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Palette.cardHigh))
                .overlay(Capsule().strokeBorder(barColor.opacity(0.45), lineWidth: 0.8))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                Text("长按并左右滑动查看各周期数值")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Palette.textFaint)
            }

            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(items.indices, id: \.self) { i in
                        let v = valueProvider(items[i])
                        let ratio = v <= 0 ? 0.06 : max(0.10, v / maxVal)
                        let isSelected = selectedIndex == i
                        VStack(spacing: 4) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(
                                    isSelected
                                        ? barColor
                                        : (v > 0 ? barColor.opacity(selectedIndex == nil ? 0.78 : 0.35) : Color.white.opacity(0.1))
                                )
                                .frame(height: (height - 22) * ratio)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .strokeBorder(isSelected ? Color.white.opacity(0.8) : .clear, lineWidth: 1)
                                )
                            Text(labelProvider(items[i]))
                                .font(.system(size: 9, weight: isSelected ? .bold : .regular))
                                .foregroundStyle(isSelected ? barColor : Palette.textFaint)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            guard !items.isEmpty else { return }
                            let rawIdx = Int((gesture.location.x / max(1, geo.size.width)) * CGFloat(items.count))
                            let clamped = min(items.count - 1, max(0, rawIdx))
                            if selectedIndex != clamped {
                                withAnimation(.snappy(duration: 0.14)) {
                                    selectedIndex = clamped
                                }
                            }
                        }
                        .onEnded { _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    selectedIndex = nil
                                }
                            }
                        }
                )
            }
            .frame(height: height)
        }
        .sensoryFeedback(.selection, trigger: selectedIndex)
    }
}

/// 点按测速 (Tap Tempo) 计算器（用于步频节拍器与音乐 BPM 校准）。
enum TapTempoCalculator {
    static func computeBPM(timestamps: [TimeInterval], range: ClosedRange<Int> = 120...220) -> Int? {
        guard timestamps.count >= 2 else { return nil }
        let sorted = timestamps.sorted()
        var intervals: [TimeInterval] = []
        for i in 1..<sorted.count {
            let dt = sorted[i] - sorted[i - 1]
            if dt > 0.18 && dt < 1.5 {
                intervals.append(dt)
            }
        }
        guard !intervals.isEmpty else { return nil }
        let avg = intervals.reduce(0, +) / Double(intervals.count)
        let bpm = Int((60.0 / avg).rounded())
        return min(max(bpm, range.lowerBound), range.upperBound)
    }
}

extension View {
    /// 当 `trigger` 变化时在控件上激起 Metal 物理水波纹。
    func waterRipple<Trigger: Equatable>(trigger: Trigger, amplitude: Float = 8) -> some View {
        modifier(WaterRippleModifier(trigger: trigger, amplitude: amplitude))
    }

    /// 视觉/扫描激活时叠加流动激光扫描光束。
    func strideScanBeam(active: Bool, color: Color = Palette.green) -> some View {
        modifier(ScanBeamOverlayModifier(active: active, color: color))
    }
}
