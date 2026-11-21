import SwiftUI

// MARK: - 1. AI 训练习惯通栏卡（2 列宽）

struct AIHabitBannerCard: View {
    let summary: TrainingHabitSummary
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(summary.headline)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                    Text(summary.subtitle)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Palette.textDim)
                }
                Spacer(minLength: 8)
                habitDotMatrix
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
            .card(radius: Metrics.radius, fill: Palette.card, stroke: Palette.stroke)
        }
        .buttonStyle(.plain)
    }

    private var habitDotMatrix: some View {
        VStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { col in
                        let isCenter = (row == 1 && col == 1)
                        let isAxis = (row == 1 || col == 1)
                        Circle()
                            .fill(Color.white.opacity(isCenter ? 1.0 : (isAxis ? 0.52 : 0.24)))
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
    }
}

// MARK: - 2. 饮水 2×2 半圆刻度表盘卡片

struct WaterBentoCard: View {
    let ml: Int
    let goal: Int
    @Binding var stepMl: Int
    var onAdjust: (Int) -> Void

    private let stepOptions = [200, 350, 500]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("饮水")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.text)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(WaterLog.grouped(ml))")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.text)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                Text("/ \(WaterLog.grouped(goal)) 毫升")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Palette.textDim)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            ZStack(alignment: .bottom) {
                WaterSemiDial(progress: Double(ml) / Double(max(1, goal)))
                    .frame(height: 82)

                HStack(spacing: 6) {
                    Button {
                        onAdjust(-stepMl)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.85))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.white.opacity(0.14)))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.7))
                    }
                    .buttonStyle(.plain)

                    Button {
                        if let idx = stepOptions.firstIndex(of: stepMl) {
                            stepMl = stepOptions[(idx + 1) % stepOptions.count]
                        } else {
                            stepMl = 500
                        }
                    } label: {
                        Text("\(stepMl) 毫升")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.text)
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(Capsule().fill(Color.white.opacity(0.15)))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.20), lineWidth: 0.7))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onAdjust(stepMl)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Palette.blue))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 2)
            }
        }
        .padding(16)
        .frame(height: 178)
        .card(radius: Metrics.radius, fill: Palette.card, stroke: Palette.stroke)
    }
}

private struct WaterSemiDial: View {
    var progress: Double

    var body: some View {
        Canvas { context, size in
            let clamped = min(1, max(0, progress))
            let center = CGPoint(x: size.width / 2, y: size.height + 12)
            let radius = min(size.width * 0.48, size.height + 2)

            var bgArc = Path()
            bgArc.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(190),
                endAngle: .degrees(350),
                clockwise: false
            )
            context.stroke(bgArc, with: .color(Color.white.opacity(0.08)), style: StrokeStyle(lineWidth: 16, lineCap: .round))

            if clamped > 0.001 {
                var fgArc = Path()
                let endDeg = 190.0 + 160.0 * clamped
                fgArc.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(190),
                    endAngle: .degrees(endDeg),
                    clockwise: false
                )
                context.stroke(fgArc, with: .color(Palette.blue.opacity(0.45)), style: StrokeStyle(lineWidth: 16, lineCap: .round))
            }

            let ticks = 16
            for i in 0...ticks {
                let t = Double(i) / Double(ticks)
                let deg = 192.0 + t * 156.0
                let rad = deg * Double.pi / 180.0
                let isMajor = i % 4 == 0
                let inner = radius - (isMajor ? 14 : 9)
                let outer = radius - 3
                var tick = Path()
                tick.move(to: CGPoint(x: center.x + CGFloat(cos(rad)) * inner, y: center.y + CGFloat(sin(rad)) * inner))
                tick.addLine(to: CGPoint(x: center.x + CGFloat(cos(rad)) * outer, y: center.y + CGFloat(sin(rad)) * outer))
                let lit = t <= clamped + 0.001
                context.stroke(
                    tick,
                    with: .color(lit && clamped > 0 ? Palette.blue : Color.white.opacity(isMajor ? 0.5 : 0.25)),
                    style: StrokeStyle(lineWidth: isMajor ? 2 : 1.4, lineCap: .round)
                )
            }
        }
    }
}

// MARK: - 3. AI 教练语录便利贴卡片

struct CoachNoteBentoCard: View {
    @Binding var quoteIndex: Int
    @State private var spinAngle: Double = 0
    var onOpenCoach: () -> Void

    private var currentQuote: String {
        let idx = abs(quoteIndex) % max(1, CoachQuoteBook.all.count)
        return CoachQuoteBook.all[idx]
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                .fill(Palette.paperWhite)

            ZStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentQuote)
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(Color(hex: 0x222018))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .onTapGesture(perform: onOpenCoach)

                    Spacer(minLength: 0)

                    HStack {
                        Text("— AI 教练")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Color(hex: 0x6F6742))
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                quoteIndex = CoachQuoteBook.nextIndex(after: quoteIndex)
                                spinAngle += 360
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Text("换一条")
                                Image(systemName: "arrow.clockwise")
                                    .rotationEffect(.degrees(spinAngle))
                            }
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x6F6742))
                            .padding(.vertical, 3)
                            .padding(.horizontal, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 13)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Palette.noteYellow)
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                )
                .rotationEffect(.degrees(-1.6))
                .padding(11)

                // 半透明白色胶带贴纸
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.white.opacity(0.68))
                    .frame(width: 52, height: 15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5)
                    )
                    .rotationEffect(.degrees(2.0))
                    .offset(y: 4)
            }
        }
        .frame(height: 178)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
    }
}

// MARK: - 4. 补剂清单卡片

struct SupplementBentoCard: View {
    let items: [SupplementItem]
    let takenIDs: Set<UUID>
    var onToggle: (UUID) -> Void
    var onManage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if items.isEmpty {
                emptyState
            } else {
                activeState
            }
        }
        .padding(16)
        .frame(height: 178)
        .card(radius: Metrics.radius, fill: Palette.card, stroke: Palette.stroke)
        .contentShape(Rectangle())
        .onTapGesture(perform: onManage)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 4)
            HStack(alignment: .center, spacing: 10) {
                SupplementBottleIcon()
                    .frame(width: 44, height: 60)

                VStack(alignment: .leading, spacing: 4) {
                    Text("还没有补剂")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(Palette.text)
                    Text("加进每日清单，一键记一份")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 6)
            HStack {
                Spacer()
                Button(action: onManage) {
                    Text("添加")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x161224))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Palette.purple.opacity(0.88)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var activeState: some View {
        let doneCount = items.filter { takenIDs.contains($0.id) }.count
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("每日补剂")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text("\(doneCount)/\(items.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(doneCount == items.count ? Palette.green : Palette.purple)
            }

            ForEach(items.prefix(3)) { item in
                let taken = takenIDs.contains(item.id)
                Button {
                    onToggle(item.id)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: taken ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(taken ? Palette.green : Palette.purple)
                        Text(item.name)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(taken ? Palette.textDim : Palette.text)
                            .strikethrough(taken)
                            .lineLimit(1)
                        Spacer()
                        Text(item.dosage)
                            .font(.system(size: 10.5, design: .rounded))
                            .foregroundStyle(Palette.textFaint)
                    }
                    .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
            }

            if items.count > 3 {
                Text("还有 \(items.count - 3) 项")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Palette.textFaint)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct SupplementBottleIcon: View {
    var body: some View {
        ZStack {
            VStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.32), lineWidth: 2)
                    .frame(width: 28, height: 10)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.32), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay {
                        Rectangle()
                            .fill(Palette.purple.opacity(0.38))
                            .frame(height: 18)
                    }
                    .frame(width: 38, height: 46)
            }
        }
    }
}

// MARK: - 5. 连续训练老黄历卡片

struct StreakCalendarBentoCard: View {
    let streak: Int
    let isRestDay: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // 砖红装订栏 + 双孔
                ZStack {
                    Palette.coral
                    HStack(spacing: 44) {
                        Circle().fill(Color.white).frame(width: 7, height: 7)
                        Circle().fill(Color.white).frame(width: 7, height: 7)
                    }
                }
                .frame(height: 28)

                VStack(spacing: 2) {
                    Text("连续训练")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color(hex: 0x7E7A72))
                        .padding(.top, 9)

                    Text("\(streak)")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.coral)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text("天")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x2C2926))

                    Spacer(minLength: 0)

                    HStack {
                        HStack(spacing: 3) {
                            Text("宜")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundStyle(Palette.coral)
                            Text(isRestDay ? "恢复" : "训练")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(Color(hex: 0x2C2926))
                        }
                        Spacer()
                        HStack(spacing: 3) {
                            Text("忌")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundStyle(Color(hex: 0x7E7A72))
                            Text("久坐")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(Color(hex: 0x5B5752))
                        }
                    }
                    .padding(.horizontal, 13)
                    .padding(.bottom, 11)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: 0xF8F6F2))
            }
            .frame(height: 178)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 6. 还能吃白色热量余额卡片

struct CalorieBalanceBentoCard: View {
    let remaining: Int
    let goal: Int
    var onCamera: () -> Void
    var onManual: () -> Void

    private var isOver: Bool { remaining < 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(isOver ? "已超出" : "还能吃")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Color(hex: 0x222226))

            Text(WaterLog.grouped(abs(remaining)))
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .foregroundStyle(isOver ? Palette.coral : Color(hex: 0x0E0E10))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text("千卡 · 目标 \(WaterLog.grouped(goal))")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color(hex: 0x7B7B84))
                .lineLimit(1)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button(action: onCamera) {
                    Image(systemName: "camera")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Capsule().fill(Color(hex: 0x0F0F12)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("拍照记餐")

                Button(action: onManual) {
                    Text("记一餐")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x161618))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Capsule().fill(Color(hex: 0xEBEBED)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(height: 178)
        .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Color.white))
    }
}
