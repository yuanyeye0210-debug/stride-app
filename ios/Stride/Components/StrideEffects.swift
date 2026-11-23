import SwiftUI
import UIKit

// MARK: - 1. 物理水波纹按钮样式 + 按需激活的 Metal 涟漪 + 零后台开销液面画布

/// 饮水、补水与液体交互专属按钮：极速软弹缩 + 冰蓝波纹圈脉冲 + 预热零阻塞触觉反馈。
struct WaterRippleButtonStyle: ButtonStyle {
    var accent: Color = Palette.blue
    var scale: CGFloat = 0.91

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .overlay {
                Circle()
                    .strokeBorder(accent.opacity(configuration.isPressed ? 0.55 : 0), lineWidth: 1.6)
                    .scaleEffect(configuration.isPressed ? 1.24 : 0.94)
                    .allowsHitTesting(false)
            }
            .animation(.snappy(duration: 0.14), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    StrideHaptics.shared.impact(.soft, intensity: 0.75)
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

/// 按需激活的 Metal 水波纹：平时静止时 0 开销（不挂载 layerEffect 与 TimelineView），仅在点击后的 0.65 秒内运行。
struct WaterRippleModifier<Trigger: Equatable>: ViewModifier {
    var trigger: Trigger
    var amplitude: Float = 7
    var frequency: Float = 18
    var decay: Float = 6.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rippleStart: Date?

    func body(content: Content) -> some View {
        Group {
            if let start = rippleStart, !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let diff = Float(timeline.date.timeIntervalSince(start))
                    let elapsed = (diff > 0 && diff < 0.65) ? diff : 0
                    content
                        .visualEffect { view, proxy in
                            view.layerEffect(
                                ShaderLibrary.strideRipple(
                                    .float2(CGPoint(x: proxy.size.width * 0.5, y: proxy.size.height * 0.65)),
                                    .float(elapsed),
                                    .float(amplitude),
                                    .float(frequency),
                                    .float(decay)
                                ),
                                maxSampleOffset: CGSize(width: 16, height: 16),
                                isEnabled: elapsed > 0
                            )
                        }
                        .onChange(of: timeline.date) { _, now in
                            if now.timeIntervalSince(start) >= 0.65 {
                                rippleStart = nil
                            }
                        }
                }
            } else {
                content
            }
        }
        .onChange(of: trigger) { _, _ in
            guard !reduceMotion else { return }
            rippleStart = Date()
        }
    }
}

/// 液面波动填充画布：平时静止 0% CPU 开销，仅在加减水后的 0.85 秒内激活波浪晃动动画。
struct WaterWaveCanvas: View {
    var progress: Double
    var color: Color = Palette.blue
    var boostTrigger: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var boostStart: Date?

    var body: some View {
        Group {
            if let start = boostStart, !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let dt = timeline.date.timeIntervalSince(start)
                    let boostAmp = dt < 0.85 ? CGFloat(exp(-dt * 3.0) * 5.0) : 0
                    waveCanvas(phaseTime: dt * 2.5, boostAmp: boostAmp)
                        .onChange(of: timeline.date) { _, now in
                            if now.timeIntervalSince(start) >= 0.85 {
                                boostStart = nil
                            }
                        }
                }
            } else {
                waveCanvas(phaseTime: 0.4, boostAmp: 0)
            }
        }
        .onChange(of: boostTrigger) { _, _ in
            guard !reduceMotion else { return }
            boostStart = Date()
        }
    }

    private func waveCanvas(phaseTime: Double, boostAmp: CGFloat) -> some View {
        Canvas { ctx, size in
            let clamped = min(1.0, max(0.03, progress))
            let waterTop = size.height * (1.0 - clamped)

            var backWave = Path()
            backWave.move(to: CGPoint(x: 0, y: size.height))
            let ampBack: CGFloat = 2.8 + boostAmp * 0.7
            for x in stride(from: 0.0, through: Double(size.width), by: 6.0) {
                let phase = (x / max(1.0, Double(size.width))) * .pi * 2.2 - phaseTime * 1.8
                let y = waterTop + CGFloat(sin(phase)) * ampBack
                backWave.addLine(to: CGPoint(x: x, y: y))
            }
            backWave.addLine(to: CGPoint(x: size.width, y: size.height))
            backWave.closeSubpath()
            ctx.fill(backWave, with: .color(color.opacity(0.22)))

            var frontWave = Path()
            frontWave.move(to: CGPoint(x: 0, y: size.height))
            let ampFront: CGFloat = 3.4 + boostAmp
            for x in stride(from: 0.0, through: Double(size.width), by: 6.0) {
                let phase = (x / max(1.0, Double(size.width))) * .pi * 2.5 + phaseTime * 2.2
                let y = waterTop + CGFloat(sin(phase)) * ampFront + 2
                frontWave.addLine(to: CGPoint(x: x, y: y))
            }
            frontWave.addLine(to: CGPoint(x: size.width, y: size.height))
            frontWave.closeSubpath()
            ctx.fill(
                frontWave,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(0.45), color.opacity(0.16)]),
                    startPoint: CGPoint(x: 0, y: waterTop),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
        }
    }
}

// MARK: - 2. 力量打卡爆发粒子按钮 + ConfettiBurstView

/// 打卡成功瞬间向四周迸发翡翠/香槟金/冰青微粒火花（平时不渲染任何节点，零后台开销）。
struct ConfettiBurstView: View {
    var trigger: Int
    var colors: [Color] = [Palette.green, Palette.lime, Palette.yellow, Palette.cyan]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var active = false
    @State private var animating = false

    private let particleCount = 8

    var body: some View {
        ZStack {
            if active && !reduceMotion {
                Circle()
                    .strokeBorder(colors.first ?? Palette.green, lineWidth: animating ? 0.5 : 2.2)
                    .frame(width: animating ? 42 : 16, height: animating ? 42 : 16)
                    .opacity(animating ? 0 : 0.85)

                ForEach(0..<particleCount, id: \.self) { idx in
                    let angle = (Double(idx) / Double(particleCount)) * .pi * 2.0
                    let radius: CGFloat = animating ? (idx % 2 == 0 ? 22 : 16) : 2
                    Circle()
                        .fill(colors[idx % colors.count])
                        .frame(width: idx % 2 == 0 ? 4.2 : 3.0, height: idx % 2 == 0 ? 4.2 : 3.0)
                        .offset(
                            x: CGFloat(cos(angle)) * radius,
                            y: CGFloat(sin(angle)) * radius
                        )
                        .opacity(animating ? 0 : 1)
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            guard !reduceMotion else { return }
            active = true
            animating = false
            withAnimation(.easeOut(duration: 0.38)) {
                animating = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                active = false
            }
        }
    }
}

/// 力量组完成打勾 / 补剂打卡专属按键：弹性过冲 + 彩色火花爆炸 + 预热零延迟成功震动。
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
                StrideHaptics.shared.notification(.success)
                withAnimation(.snappy(duration: 0.14)) {
                    popScale = 1.22
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.snappy(duration: 0.16)) {
                        popScale = 1.0
                    }
                }
            } else {
                StrideHaptics.shared.impact(.light, intensity: 0.5)
            }
        } label: {
            ZStack {
                ConfettiBurstView(trigger: burstToken, colors: [accent, Palette.lime, Palette.yellow, Palette.cyan])
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(isDone ? accent : Palette.strokeHi)
                    .scaleEffect(popScale)
            }
            .frame(width: max(30, size + 10), height: max(30, size + 10))
            .contentShape(Circle())
        }
        .buttonStyle(StridePressButtonStyle(scale: 0.90, pressedOpacity: 0.92, haptic: nil))
    }
}

// MARK: - 3. 钛金微光 CTA 按钮样式（移除常驻 TimelineView 与离屏阴影，120Hz 零延迟响应）

struct ShimmerCTAButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var glowColor: Color = Palette.green

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(configuration.isPressed ? 0.24 : 0.10),
                        Color.clear,
                        Color.white.opacity(0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .allowsHitTesting(false)
            )
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.snappy(duration: 0.13), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    StrideHaptics.shared.impact(.medium, intensity: 0.7)
                }
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
        .scaleEffect(isHolding ? 0.97 : 1.0)
        .animation(.snappy(duration: 0.15), value: isHolding)
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
        StrideHaptics.shared.impact(.light, intensity: 0.5)
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            let steps = 16
            let stepNs = UInt64((duration / Double(steps)) * 1_000_000_000)
            for idx in 1...steps {
                try? await Task.sleep(nanoseconds: stepNs)
                if Task.isCancelled || !isHolding { return }
                withAnimation(.linear(duration: duration / Double(steps))) {
                    progress = CGFloat(idx) / CGFloat(steps)
                }
                if idx % 5 == 0 {
                    let strength = CGFloat(idx) / CGFloat(steps)
                    StrideHaptics.shared.impact(.medium, intensity: min(1.0, 0.45 + strength * 0.5))
                }
            }
            completed = true
            StrideHaptics.shared.notification(.success)
            onConfirm()
            try? await Task.sleep(nanoseconds: 300_000_000)
            completed = false
            isHolding = false
            progress = 0
        }
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
        if !completed {
            withAnimation(.snappy(duration: 0.2)) {
                isHolding = false
                progress = 0
            }
        }
    }
}

// MARK: - 5. 金属滑轨完成滑块（SlideToCompleteBar）

struct SlideToCompleteBar: View {
    let title: String
    var tint: Color = Palette.green
    var icon: String = "checkmark"
    var onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var completed = false

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
                    Text(completed ? "完成！" : title)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(completed ? tint : Palette.text.opacity(Double(max(0.25, 1.0 - ratio * 1.1))))
                    if !completed {
                        Image(systemName: "chevron.right.2")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(tint.opacity(0.75))
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
                    }
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
                                    withAnimation(.snappy(duration: 0.18)) {
                                        dragOffset = maxDrag
                                        completed = true
                                    }
                                    StrideHaptics.shared.notification(.success)
                                    onComplete()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        withAnimation(.snappy(duration: 0.22)) {
                                            completed = false
                                            dragOffset = 0
                                        }
                                    }
                                } else {
                                    withAnimation(.snappy(duration: 0.22)) {
                                        dragOffset = 0
                                    }
                                    StrideHaptics.shared.impact(.light, intensity: 0.35)
                                }
                            }
                    )
            }
        }
        .frame(height: trackHeight)
    }
}

// MARK: - 6. 极速旋转回弹按钮样式（SpinActionButtonStyle）

struct SpinActionButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .rotationEffect(.degrees(configuration.isPressed ? -22 : 0))
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.snappy(duration: 0.14), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    StrideHaptics.shared.impact(.rigid, intensity: 0.6)
                }
            }
    }
}

extension ButtonStyle where Self == SpinActionButtonStyle {
    static var strideSpin: SpinActionButtonStyle { SpinActionButtonStyle() }
}

// MARK: - 7. 心跳弹性按钮样式（HeartPopButtonStyle）

struct HeartPopButtonStyle: ButtonStyle {
    var accent: Color = Palette.pink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.18 : 1.0)
            .animation(.snappy(duration: 0.14), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    StrideHaptics.shared.impact(.medium, intensity: 0.68)
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

struct StepperTactileButtonStyle: ButtonStyle {
    var accent: Color = Palette.green

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(accent.opacity(configuration.isPressed ? 0.65 : 0), lineWidth: 1.0)
                    .allowsHitTesting(false)
            )
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    StrideHaptics.shared.impact(.rigid, intensity: 0.75)
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

// MARK: - 9. 零后台开销极光渐变背景 & AuroraGlowButtonStyle

/// 零常驻 TimelineView 开销的高奢极光渐变背景（硬件直接合成）。
struct AuroraBannerBackground: View {
    var colorA: Color = Color(hex: 0x5E6CFF)
    var colorB: Color = Color(hex: 0xBA5CFF)
    var colorC: Color = Color(hex: 0x2DD4BF)

    var body: some View {
        LinearGradient(
            colors: [colorA, colorB, colorC],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct AuroraGlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.91 : 1.0)
            .opacity(configuration.isPressed ? 0.90 : 1.0)
            .animation(.snappy(duration: 0.14), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    StrideHaptics.shared.impact(.medium, intensity: 0.72)
                }
            }
    }
}

extension ButtonStyle where Self == AuroraGlowButtonStyle {
    static var strideAurora: AuroraGlowButtonStyle { AuroraGlowButtonStyle() }
}

// MARK: - 10. 激光扫描光束修饰符（仅在正在扫描识别时激活 Metal Shader）

struct ScanBeamOverlayModifier: ViewModifier {
    var active: Bool
    var color: Color = Palette.green

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if active && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
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

// MARK: - 11. 雷达扩散脉冲波 & 按需激活的音频频谱柱

struct RadarPulseRing: View {
    var color: Color = Palette.green
    var isActive: Bool = true
    var size: CGFloat = 120

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            if isActive && !reduceMotion {
                ForEach(0..<2, id: \.self) { idx in
                    Circle()
                        .strokeBorder(color.opacity(pulse ? 0.0 : 0.48), lineWidth: 1.5)
                        .frame(width: size, height: size)
                        .scaleEffect(pulse ? 1.42 : 0.78)
                        .animation(
                            .easeOut(duration: 1.8)
                            .repeatForever(autoreverses: false)
                            .delay(Double(idx) * 0.9),
                            value: pulse
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            if isActive { pulse = true }
        }
        .onChange(of: isActive) { _, active in
            pulse = active
        }
    }
}

/// 5 根动态音频频谱跳动柱（仅在 isPlaying == true 时激活 12fps 轻量动画；静止时 0 开销）。
struct AudioSpectrumBars: View {
    var isPlaying: Bool
    var bpm: Int = 128
    var color: Color = Palette.green
    var barCount: Int = 5
    var maxHeight: CGFloat = 20

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if isPlaying && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let freq = max(1.0, Double(bpm) / 60.0) * .pi
                HStack(alignment: .bottom, spacing: 2.5) {
                    ForEach(0..<barCount, id: \.self) { i in
                        let raw = sin(t * freq * 1.2 + Double(i) * 1.15) * 0.5 + 0.5
                        let h = max(4, maxHeight * CGFloat(0.25 + raw * 0.75))
                        Capsule(style: .continuous)
                            .fill(color)
                            .frame(width: 3, height: h)
                    }
                }
                .frame(height: maxHeight, alignment: .bottom)
            }
        } else {
            HStack(alignment: .bottom, spacing: 2.5) {
                ForEach(0..<barCount, id: \.self) { i in
                    Capsule(style: .continuous)
                        .fill(color)
                        .frame(width: 3, height: maxHeight * (0.32 + CGFloat(i % 3) * 0.18))
                }
            }
            .frame(height: maxHeight, alignment: .bottom)
        }
    }
}

// MARK: - 12. 物理刻度尺数学 & 滚动选值器 + 跑步 3-2-1-GO 倒计时 + 柱图准星组件

enum TactileRulerMath {
    static func clampAndSnap(_ value: Double, range: ClosedRange<Double>, step: Double) -> Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let s = max(0.01, step)
        let snapped = (clamped / s).rounded() * s
        return (snapped * 1000).rounded() / 1000
    }

    static func valueForDrag(startValue: Double, translationX: CGFloat, pointsPerStep: CGFloat, step: Double, range: ClosedRange<Double>) -> Double {
        let stepsDelta = Double(-translationX / max(1, pointsPerStep))
        return clampAndSnap(startValue + stepsDelta * step, range: range, step: step)
    }
}

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
                                StrideHaptics.shared.selection()
                            }
                        }
                        .onEnded { _ in
                            dragStartValue = nil
                        }
                )
            }
            .frame(height: 76)
        }
    }
}

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
                scale = 1.38
                opacity = 0.2
                StrideHaptics.shared.impact(item.1)
                withAnimation(.snappy(duration: 0.24)) {
                    scale = 1.0
                    opacity = 1.0
                }
                let waitNs: UInt64 = idx == seq.count - 1 ? 450_000_000 : 750_000_000
                try? await Task.sleep(nanoseconds: waitNs)
            }
            if !Task.isCancelled {
                StrideHaptics.shared.notification(.success)
                onFinished()
            }
        }
    }
}

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
                                selectedIndex = clamped
                                StrideHaptics.shared.selection()
                            }
                        }
                        .onEnded { _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                selectedIndex = nil
                            }
                        }
                )
            }
            .frame(height: height)
        }
    }
}

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
    func waterRipple<Trigger: Equatable>(trigger: Trigger, amplitude: Float = 7) -> some View {
        modifier(WaterRippleModifier(trigger: trigger, amplitude: amplitude))
    }

    func strideScanBeam(active: Bool, color: Color = Palette.green) -> some View {
        modifier(ScanBeamOverlayModifier(active: active, color: color))
    }
}
