import SwiftUI

// MARK: - 1. AI 训练习惯通栏卡（2 列宽 · 极光呼吸点阵）

struct AIHabitBannerCard: View {
    let summary: TrainingHabitSummary
    var onTap: () -> Void
    @State private var pulse = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(Palette.purple)
                            .symbolEffect(.pulse, value: pulse)
                        Text("AI 节律画像")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Palette.purple)
                    }
                    Text(summary.headline)
                        .font(.system(size: 18.5, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                    Text(summary.subtitle)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Palette.textDim)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                habitDotMatrix
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .luxuryCard(radius: Metrics.radius, accent: Palette.purple, glowCorner: .topTrailing)
        }
        .buttonStyle(.strideCard)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var habitDotMatrix: some View {
        VStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { col in
                        let isCenter = (row == 1 && col == 1)
                        let isAxis = (row == 1 || col == 1)
                        Circle()
                            .fill(
                                isCenter
                                    ? Palette.purple
                                    : (isAxis ? Palette.cyan.opacity(pulse ? 0.85 : 0.45) : Color.white.opacity(0.20))
                            )
                            .frame(width: 8, height: 8)
                            .shadow(color: isCenter ? Palette.purple.opacity(0.6) : .clear, radius: 5)
                    }
                }
            }
        }
    }
}

// MARK: - 2. 饮水 2×2 动态水波 + Metal 涟漪卡片

struct WaterBentoCard: View {
    let ml: Int
    let goal: Int
    @Binding var stepMl: Int
    var onAdjust: (Int) -> Void

    private let stepOptions = [200, 350, 500]
    private var progress: Double { Double(ml) / Double(max(1, goal)) }

    var body: some View {
        ZStack(alignment: .bottom) {
            // 底部实时双层正弦波浪与上升气泡
            WaterWaveCanvas(progress: progress, color: Palette.blue, boostTrigger: ml)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("饮水", systemImage: "drop.fill")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Palette.blue)
                    Spacer()
                    Text("\(min(100, Int((progress * 100).rounded())))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.blue)
                        .numericRoll(value: ml)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(WaterLog.grouped(ml))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.text)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                        .numericRoll(value: ml)
                    Text("/ \(WaterLog.grouped(goal)) ml")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Palette.textDim)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                ZStack(alignment: .bottom) {
                    WaterSemiDial(progress: progress)
                        .frame(height: 76)
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: ml)

                    HStack(spacing: 6) {
                        Button {
                            onAdjust(-stepMl)
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.9))
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Color.white.opacity(0.14)))
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.7))
                        }
                        .buttonStyle(.strideWater(accent: Palette.blue))

                        Button {
                            if let idx = stepOptions.firstIndex(of: stepMl) {
                                stepMl = stepOptions[(idx + 1) % stepOptions.count]
                            } else {
                                stepMl = 500
                            }
                        } label: {
                            Text("\(stepMl) ml")
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.text)
                                .numericRoll(value: stepMl)
                                .padding(.horizontal, 10)
                                .frame(height: 30)
                                .background(Capsule().fill(Color.black.opacity(0.35)))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.7))
                        }
                        .buttonStyle(.strideStepper(accent: Palette.blue))

                        Button {
                            onAdjust(stepMl)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(Color.white)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Palette.blue))
                                .shadow(color: Palette.blue.opacity(0.5), radius: 6, y: 2)
                        }
                        .buttonStyle(.strideWater(accent: Palette.blue))
                    }
                    .padding(.bottom, 2)
                }
            }
            .padding(16)
        }
        .frame(height: 178)
        .luxuryCard(radius: Metrics.radius, accent: Palette.blue, glowCorner: .bottomTrailing)
        .waterRipple(trigger: ml, amplitude: 9)
        .sensoryFeedback(.selection, trigger: stepMl)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: ml)
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
            context.stroke(bgArc, with: .color(Color.white.opacity(0.08)), style: StrokeStyle(lineWidth: 14, lineCap: .round))

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
                context.stroke(fgArc, with: .color(Palette.blue.opacity(0.55)), style: StrokeStyle(lineWidth: 14, lineCap: .round))
            }

            let ticks = 16
            for i in 0...ticks {
                let t = Double(i) / Double(ticks)
                let deg = 192.0 + t * 156.0
                let rad = deg * Double.pi / 180.0
                let isMajor = i % 4 == 0
                let inner = radius - (isMajor ? 13 : 8)
                let outer = radius - 3
                var tick = Path()
                tick.move(to: CGPoint(x: center.x + CGFloat(cos(rad)) * inner, y: center.y + CGFloat(sin(rad)) * inner))
                tick.addLine(to: CGPoint(x: center.x + CGFloat(cos(rad)) * outer, y: center.y + CGFloat(sin(rad)) * outer))
                let lit = t <= clamped + 0.001
                context.stroke(
                    tick,
                    with: .color(lit && clamped > 0 ? Palette.cyan : Color.white.opacity(isMajor ? 0.45 : 0.22)),
                    style: StrokeStyle(lineWidth: isMajor ? 2 : 1.3, lineCap: .round)
                )
            }
        }
    }
}

// MARK: - 3. AI 教练语录便利贴卡片（升级暗夜琥珀鎏金磨砂贴纸）

struct CoachNoteBentoCard: View {
    @Binding var quoteIndex: Int
    @State private var spinAngle: Double = 0
    var onOpenCoach: () -> Void

    private var currentQuote: String {
        let idx = abs(quoteIndex) % max(1, CoachQuoteBook.all.count)
        return CoachQuoteBook.all[idx]
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(currentQuote)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xFAF3E0))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    .id(quoteIndex)
                    .onTapGesture(perform: onOpenCoach)

                Spacer(minLength: 0)

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(Palette.yellow)
                        Text("AI 教练笔记")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Palette.yellow.opacity(0.85))
                    }
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
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(Palette.yellow)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Capsule().fill(Palette.yellow.opacity(0.14)))
                    }
                    .buttonStyle(.strideSpin)
                }
            }
            .padding(.top, 18)
            .padding(.horizontal, 13)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x2C2416), Color(hex: 0x1F1A11)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Palette.yellow.opacity(0.32), lineWidth: 0.9)
                    )
                    .shadow(color: .black.opacity(0.38), radius: 8, y: 4)
            )
            .rotationEffect(.degrees(-1.4))
            .padding(11)

            // 半透明暗金磨砂胶带贴纸
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(Palette.yellow.opacity(0.35))
                .frame(width: 48, height: 13)
                .overlay(
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.5)
                )
                .rotationEffect(.degrees(1.8))
                .offset(y: 4)
        }
        .frame(height: 178)
        .luxuryCard(radius: Metrics.radius, accent: Palette.yellow, glowCorner: .topLeading, fill: Palette.obsidianGold)
        .sensoryFeedback(.selection, trigger: quoteIndex)
    }
}

// MARK: - 4. 补剂清单卡片（接入 SetCheckBurstButton 爆裂火花打卡）

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
        .luxuryCard(radius: Metrics.radius, accent: Palette.purple, glowCorner: .topTrailing)
        .contentShape(Rectangle())
        .onTapGesture(perform: onManage)
        .sensoryFeedback(.success, trigger: takenIDs)
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
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Palette.purple))
                }
                .buttonStyle(.strideShimmer(glow: Palette.purple))
            }
        }
    }

    private var activeState: some View {
        let doneCount = items.filter { takenIDs.contains($0.id) }.count
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("每日补剂")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text("\(doneCount)/\(items.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(doneCount == items.count ? Palette.green : Palette.purple)
                    .numericRoll(value: doneCount)
            }

            ForEach(items.prefix(3)) { item in
                let taken = takenIDs.contains(item.id)
                HStack(spacing: 6) {
                    SetCheckBurstButton(isDone: taken, size: 15, accent: Palette.green) {
                        onToggle(item.id)
                    }
                    .frame(width: 22, height: 22)

                    Button {
                        onToggle(item.id)
                    } label: {
                        HStack {
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
                    }
                    .buttonStyle(.strideRow(radius: 8))
                }
            }

            if items.count > 3 {
                Text("还有 \(items.count - 3) 项 · 点卡片管理")
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
                    .strokeBorder(Palette.purple.opacity(0.55), lineWidth: 2)
                    .frame(width: 28, height: 10)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Palette.purple.opacity(0.55), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Palette.purple.opacity(0.08))
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

// MARK: - 5. 连续训练暗夜鎏金红漆老黄历卡片

struct StreakCalendarBentoCard: View {
    let streak: Int
    let isRestDay: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // 绯红金属漆装订栏 + 双银环孔
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: 0x8F2323), Color(hex: 0x5E1618)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    HStack(spacing: 44) {
                        Circle()
                            .fill(Palette.bg)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.45), lineWidth: 1))
                        Circle()
                            .fill(Palette.bg)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.45), lineWidth: 1))
                    }
                }
                .frame(height: 28)

                VStack(spacing: 2) {
                    Text("连续训练")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Palette.textDim)
                        .padding(.top, 9)

                    Text("\(streak)")
                        .font(.system(size: 50, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Palette.yellow, Palette.coralHi],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .numericRoll(value: streak)

                    Text("天")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.yellow.opacity(0.85))

                    Spacer(minLength: 0)

                    HStack {
                        HStack(spacing: 4) {
                            Text("宜")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(Color.black)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(Palette.green))
                            Text(isRestDay ? "恢复" : "训练")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(Palette.text)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Text("忌")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(Palette.coralHi)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(Palette.coralHi.opacity(0.18)))
                            Text("久坐")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(Palette.textDim)
                        }
                    }
                    .padding(.horizontal, 13)
                    .padding(.bottom, 11)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 178)
            .luxuryCard(radius: Metrics.radius, accent: Palette.coralHi, glowCorner: .bottomLeading, fill: Palette.crimsonDark)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
        }
        .buttonStyle(.strideCard)
    }
}

// MARK: - 6. 还能吃暗夜翡翠热量余额卡片（消除刺眼纯白，升级 Obsidian Emerald）

struct CalorieBalanceBentoCard: View {
    let remaining: Int
    let goal: Int
    var onCamera: () -> Void
    var onManual: () -> Void

    private var isOver: Bool { remaining < 0 }
    private var eatenRatio: Double {
        guard goal > 0 else { return 0 }
        return min(1.0, max(0.0, Double(goal - remaining) / Double(goal)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(isOver ? "热量已超出" : "还能吃")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(isOver ? Palette.coralHi : Palette.greenText)
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isOver ? Palette.coralHi : Palette.green)
            }

            Text(WaterLog.grouped(abs(remaining)))
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(isOver ? Palette.coralHi : Palette.text)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .numericRoll(value: remaining)

            Text("千卡 · 目标 \(WaterLog.grouped(goal))")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.textDim)
                .lineLimit(1)

            BarProgress(
                progress: eatenRatio,
                color: isOver ? Palette.coralHi : Palette.green,
                height: 4
            )
            .padding(.top, 2)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button(action: onCamera) {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12.5, weight: .bold))
                        Text("拍餐")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(Capsule().fill(Palette.green))
                }
                .buttonStyle(.strideShimmer(glow: Palette.green))
                .accessibilityLabel("拍照记餐")

                Button(action: onManual) {
                    Text("记一餐")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(Capsule().fill(Palette.cardHigh))
                        .overlay(Capsule().strokeBorder(Palette.strokeHi, lineWidth: 0.7))
                }
                .buttonStyle(.stridePress)
            }
        }
        .padding(16)
        .frame(height: 178)
        .luxuryCard(
            radius: Metrics.radius,
            accent: isOver ? Palette.coralHi : Palette.green,
            glowCorner: .topTrailing
        )
    }
}
