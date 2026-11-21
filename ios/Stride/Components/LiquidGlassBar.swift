import SwiftUI

// MARK: - 主页子频道枚举（已按需求移除“推文”）

enum HomeChannel: String, CaseIterable, Identifiable {
    case home = "首页"
    case music = "音乐"
    case run = "跑步"
    case plugins = "插件"

    var id: String { rawValue }
}

// MARK: - 屋顶+心电图主页图标

struct HomePulseIcon: View {
    var active: Bool

    var body: some View {
        ZStack {
            HouseSilhouetteShape()
                .fill(active ? Color.white : Color.clear)
            HouseSilhouetteShape()
                .stroke(active ? Color.white : Color.white.opacity(0.65), style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))

            PulseWaveShape()
                .stroke(
                    active ? Color.black : Color.white.opacity(0.75),
                    style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)
                )
                .padding(.horizontal, 4.5)
                .padding(.top, 5)
                .padding(.bottom, 3)
        }
        .frame(width: 22, height: 20)
    }
}

private struct HouseSilhouetteShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: h * 0.05))
        p.addLine(to: CGPoint(x: w * 0.94, y: h * 0.42))
        p.addLine(to: CGPoint(x: w * 0.94, y: h * 0.90))
        p.addQuadCurve(to: CGPoint(x: w * 0.80, y: h * 0.98), control: CGPoint(x: w * 0.94, y: h * 0.98))
        p.addLine(to: CGPoint(x: w * 0.20, y: h * 0.98))
        p.addQuadCurve(to: CGPoint(x: w * 0.06, y: h * 0.90), control: CGPoint(x: w * 0.06, y: h * 0.98))
        p.addLine(to: CGPoint(x: w * 0.06, y: h * 0.42))
        p.closeSubpath()
        return p
    }
}

private struct PulseWaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let mid = h * 0.54
        var p = Path()
        p.move(to: CGPoint(x: 0, y: mid))
        p.addLine(to: CGPoint(x: w * 0.24, y: mid))
        p.addLine(to: CGPoint(x: w * 0.38, y: h * 0.20))
        p.addLine(to: CGPoint(x: w * 0.56, y: h * 0.85))
        p.addLine(to: CGPoint(x: w * 0.74, y: h * 0.38))
        p.addLine(to: CGPoint(x: w * 0.84, y: mid))
        p.addLine(to: CGPoint(x: w, y: mid))
        return p
    }
}

// MARK: - 底部悬浮液态玻璃 4 Tab 胶囊栏

struct FloatingTabBar: View {
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 4) {
            tabButton(title: "主页", tag: 0) { active in
                HomePulseIcon(active: active)
            }
            tabButton(title: "计划", tag: 1) { active in
                Image(systemName: active ? "list.clipboard.fill" : "list.clipboard")
                    .font(.system(size: 18, weight: .semibold))
            }
            tabButton(title: "记录", tag: 2) { active in
                Image(systemName: active ? "chart.bar.fill" : "chart.bar")
                    .font(.system(size: 18, weight: .semibold))
            }
            tabButton(title: "自己", tag: 3) { active in
                Image(systemName: active ? "person.crop.circle.fill" : "person.crop.circle")
                    .font(.system(size: 19, weight: .semibold))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .liquidGlassCapsule(tint: Color.black.opacity(0.45))
        .padding(.horizontal, 22)
        .padding(.bottom, 6)
    }

    private func tabButton<Icon: View>(
        title: String,
        tag: Int,
        @ViewBuilder icon: (Bool) -> Icon
    ) -> some View {
        let on = selection == tag
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                selection = tag
            }
        } label: {
            VStack(spacing: 3) {
                icon(on)
                    .frame(height: 21)
                Text(title)
                    .font(.system(size: 10, weight: on ? .semibold : .medium))
            }
            .foregroundStyle(on ? Color.white : Color.white.opacity(0.65))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background {
                if on {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.14))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - 主页顶部悬浮分段胶囊栏 + 动态上下文圆按钮

struct HomeTopSegmentBar: View {
    @Binding var channel: HomeChannel
    var onAI: () -> Void
    var onFavoriteMusic: () -> Void
    var onQuickRun: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                ForEach(HomeChannel.allCases) { item in
                    let active = channel == item
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            channel = item
                        }
                    } label: {
                        Text(item.rawValue)
                            .font(.system(size: 14, weight: active ? .semibold : .medium))
                            .foregroundStyle(active ? Color.white : Color.white.opacity(0.68))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background {
                                if active {
                                    Capsule(style: .continuous)
                                        .fill(Color.white.opacity(0.20))
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.6)
                                        )
                                }
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .liquidGlassCapsule(tint: Color.black.opacity(0.42))

            contextTrailingButton
        }
        .padding(.horizontal, Metrics.page)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var contextTrailingButton: some View {
        switch channel {
        case .home, .plugins:
            AIGlowCircleButton(action: onAI)
        case .music:
            Button(action: onFavoriteMusic) {
                Image(systemName: "heart")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.white)
                    .frame(width: 44, height: 44)
                    .liquidGlassCapsule(tint: Color.black.opacity(0.45))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("音乐收藏与歌词")
        case .run:
            Button(action: onQuickRun) {
                Text("GO")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .frame(width: 44, height: 44)
                    .liquidGlassCapsule(tint: Color.black.opacity(0.45))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("快速开始跑步")
        }
    }
}

struct AIGlowCircleButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [
                                Color(hex: 0x6280FF),
                                Color(hex: 0xFF83C6),
                                Color(hex: 0xFFBA6A),
                                Color(hex: 0x65E5AA),
                                Color(hex: 0x6280FF)
                            ],
                            center: .center
                        )
                    )
                    .frame(width: 48, height: 48)
                    .blur(radius: 5)
                    .opacity(0.75)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x5B6CFF), Color(hex: 0x7A49FF)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 43, height: 43)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.75), Color(hex: 0xFFB86B).opacity(0.75)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.4
                            )
                    )

                Text("AI")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 46, height: 46)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("打开 AI 教练")
    }
}
