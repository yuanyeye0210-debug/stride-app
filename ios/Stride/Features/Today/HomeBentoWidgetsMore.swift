import SwiftUI

// MARK: - 7. 肌肉恢复 2×2 卡片（曜石荧光渐变柱）

struct MuscleRecoveryBentoCard: View {
    let items: [MuscleRecoveryItem]
    var onTap: () -> Void
    @State private var barsAppeared = false

    private var recommendedName: String {
        items.first(where: \.isRecommended)?.group.rawValue ?? "肩"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("肌肉恢复")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(Palette.text)
                    Spacer()
                    Circle()
                        .fill(Palette.lime)
                        .frame(width: 6, height: 6)
                        .shadow(color: Palette.lime, radius: 4)
                }

                (
                    Text("今天练 ")
                        .foregroundColor(Palette.textDim)
                    + Text(recommendedName)
                        .fontWeight(.bold)
                        .foregroundColor(Palette.lime)
                    + Text(" 最合适")
                        .foregroundColor(Palette.textDim)
                )
                .font(.system(size: 11.5))
                .lineLimit(1)

                Spacer(minLength: 4)

                HStack(spacing: 8) {
                    ForEach(items) { item in
                        VStack(spacing: 5) {
                            GeometryReader { geo in
                                let ratio = barsAppeared ? CGFloat(max(8, min(100, item.percent))) / 100.0 : 0.0
                                let barColor: Color = {
                                    if item.isRecommended { return Palette.lime }
                                    if item.percent >= 70 { return Palette.green }
                                    return Palette.amber
                                }()
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [barColor, barColor.opacity(0.55)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(height: geo.size.height * ratio)
                                        .animation(.spring(response: 0.62, dampingFraction: 0.8), value: barsAppeared)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(
                                            item.isRecommended ? Color.white.opacity(0.75) : Color.white.opacity(0.14),
                                            lineWidth: item.isRecommended ? 1.3 : 0.7
                                        )
                                )
                            }
                            .frame(height: 60)

                            VStack(spacing: 1) {
                                Text(item.group.rawValue)
                                    .font(.system(size: 10.5, weight: item.isRecommended ? .bold : .medium))
                                    .foregroundStyle(item.isRecommended ? Palette.lime : Palette.textDim)
                                Text("\(item.percent)%")
                                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(item.isRecommended ? Palette.lime : Palette.textFaint)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .frame(height: 178)
            .luxuryCard(radius: Metrics.radius, accent: Palette.lime, glowCorner: .topTrailing)
        }
        .buttonStyle(.strideCard)
        .onAppear {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.8)) {
                barsAppeared = true
            }
        }
    }
}

// MARK: - 8. 咖啡因代谢卡片（琥珀流光时间窗）

struct CaffeineBentoCard: View {
    let todayMg: Int
    let limitMg: Int
    let sleepHour: Int
    let sleepMinute: Int
    var onAdd: () -> Void

    private var window: (morningLabel: String, windowLabel: String) {
        CaffeineCalculator.optimalWindowText(sleepHour: sleepHour, sleepMinute: sleepMinute)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("咖啡因")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(Palette.amber)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Palette.amber.opacity(0.16)))
                        .overlay(Circle().strokeBorder(Palette.amber.opacity(0.35), lineWidth: 0.7))
                }
                .buttonStyle(.strideStepper(accent: Palette.amber))
                .accessibilityLabel("记一杯咖啡因")
            }

            HStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(todayMg)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(todayMg > limitMg ? Palette.coralHi : Palette.text)
                        .numericRoll(value: todayMg)
                    Text("/ \(limitMg) mg")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.textDim)
                }
                Spacer()
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.amber.opacity(0.85))
            }

            Spacer(minLength: 2)

            VStack(spacing: 5) {
                Text("最佳饮用窗口")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.textFaint)

                HStack(spacing: 4) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.7))
                        .frame(width: 28, height: 13)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0xD97B29), Color(hex: 0xFFB04F), Color(hex: 0xD97B29)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(Capsule().strokeBorder(Color(hex: 0xFFD48D).opacity(0.75), lineWidth: 0.8))
                        .shadow(color: Color(hex: 0xFF9E3D).opacity(0.45), radius: 6)
                        .frame(maxWidth: .infinity)
                        .frame(height: 13)

                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.7))
                        .frame(width: 32, height: 13)
                }

                HStack {
                    Text(window.morningLabel)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Palette.textFaint)
                    Spacer()
                    Text(window.windowLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Palette.amber)
                    Spacer()
                    Text("入睡")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Palette.textFaint)
                }
            }

            HStack(spacing: 5) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.purple)
                Text("入睡 \(CaffeineCalculator.formattedSleepTime(hour: sleepHour, minute: sleepMinute))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.textDim)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(height: 178)
        .luxuryCard(radius: Metrics.radius, accent: Palette.amber, glowCorner: .topTrailing)
        .contentShape(Rectangle())
        .onTapGesture(perform: onAdd)
    }
}

// MARK: - 9. Stride 食堂暗夜碳黑锯齿小票卡片（告别灰白底，升级 Obsidian Receipt）

struct FoodReceiptBentoCard: View {
    let foods: [FoodEntry]
    let eatenKcal: Int
    let remainingKcal: Int
    var onAddFood: () -> Void

    private var dateBadge: String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        return f.string(from: Date())
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(Brand.canteenTitle) · \(dateBadge)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.yellow)
                    .frame(maxWidth: .infinity, alignment: .center)

                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 0.7)

                if foods.isEmpty {
                    Text("今天还没记 · 点 + 记一餐")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Palette.textDim)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 3) {
                        ForEach(foods.suffix(2)) { entry in
                            HStack {
                                Text(entry.items.first?.name ?? entry.meal.rawValue)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundStyle(Palette.text)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(Int(entry.kcal.rounded()))")
                                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Palette.textDim)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                DashedLine()
                    .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(height: 1)

                HStack {
                    Text("合计")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.text)
                    Spacer()
                    Text(WaterLog.grouped(eatenKcal))
                        .font(.system(size: 13.5, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Palette.text)
                        .numericRoll(value: eatenKcal)
                }

                HStack {
                    Text(remainingKcal >= 0 ? "还能吃" : "超出")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(remainingKcal >= 0 ? Palette.green : Palette.coralHi)
                    Spacer()
                    Text(WaterLog.grouped(abs(remainingKcal)))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(remainingKcal >= 0 ? Palette.green : Palette.coralHi)
                        .numericRoll(value: remainingKcal)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ReceiptPaperShape(toothCount: 13)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x1D2130), Palette.receiptDark],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        ReceiptPaperShape(toothCount: 13)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
            )
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 10)

            Button(action: onAddFood) {
                Image(systemName: "plus")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Palette.green))
                    .shadow(color: Palette.green.opacity(0.45), radius: 6, y: 2)
            }
            .buttonStyle(.strideShimmer(glow: Palette.green))
            .padding(10)
            .accessibilityLabel("记一餐")
        }
        .frame(height: 178)
        .luxuryCard(radius: Metrics.radius, accent: Palette.green, glowCorner: .bottomTrailing, fill: Palette.cardSoft)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onAddFood)
    }
}

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return p
    }
}

private struct ReceiptPaperShape: Shape {
    var toothCount: Int = 12

    func path(in rect: CGRect) -> Path {
        let toothHeight: CGFloat = 5.5
        let topRadius: CGFloat = 10
        let bottomY = rect.height - toothHeight

        var p = Path()
        p.move(to: CGPoint(x: 0, y: topRadius))
        p.addQuadCurve(to: CGPoint(x: topRadius, y: 0), control: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: rect.width - topRadius, y: 0))
        p.addQuadCurve(to: CGPoint(x: rect.width, y: topRadius), control: CGPoint(x: rect.width, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: bottomY))

        let step = rect.width / CGFloat(max(2, toothCount))
        for i in stride(from: toothCount, to: 0, by: -1) {
            let xRight = CGFloat(i) * step
            let xMid = xRight - step / 2
            let xLeft = xRight - step
            p.addLine(to: CGPoint(x: xMid, y: rect.height))
            p.addLine(to: CGPoint(x: xLeft, y: bottomY))
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - 10. 活动三环 2×2 卡片（带心电呼吸中心）

struct ActivityRingsBentoCard: View {
    let moveProgress: Double
    let exerciseProgress: Double
    let standProgress: Double
    var onTap: () -> Void
    @State private var ecgBeat = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RingView(
                    progress: moveProgress,
                    lineWidth: 14,
                    colors: [Palette.ringMove, Color(hex: 0xFF3E6C)],
                    track: Palette.ringMove.opacity(0.18)
                )
                .frame(width: 136, height: 136)

                RingView(
                    progress: exerciseProgress,
                    lineWidth: 14,
                    colors: [Palette.ringEx, Color(hex: 0xD8FF3E)],
                    track: Palette.ringEx.opacity(0.18)
                )
                .frame(width: 102, height: 102)

                RingView(
                    progress: standProgress,
                    lineWidth: 14,
                    colors: [Palette.ringStand, Color(hex: 0x56F0FF)],
                    track: Palette.ringStand.opacity(0.18)
                )
                .frame(width: 68, height: 68)

                Circle()
                    .fill(Palette.cardHigh)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
                    .overlay {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.ringMove)
                            .scaleEffect(ecgBeat ? 1.12 : 0.94)
                    }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 178)
            .luxuryCard(radius: Metrics.radius, accent: Palette.ringMove, glowCorner: .topLeading)
        }
        .buttonStyle(.strideCard)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                ecgBeat = true
            }
        }
        .accessibilityLabel("今日活动三环")
    }
}

// MARK: - 11. 本月训练时长黑金卷尺卡片

struct MonthlyHoursBentoCard: View {
    let hours: Double
    let count: Int
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text("本月训练")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.text)

                    Spacer(minLength: 0)

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: "%.1f", hours))
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(Palette.yellow)
                            .numericRoll(value: hours)
                        Text("H")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.text)
                        Spacer()
                        Text("\(count) 次")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Palette.textDim)
                            .numericRoll(value: count)
                    }
                }
                .padding(16)

                TapeMeasureView(value: hours)
                    .frame(height: 54)
                    .rotationEffect(.degrees(-8))
                    .offset(y: -2)
            }
            .frame(height: 178)
            .luxuryCard(radius: Metrics.radius, accent: Palette.yellow, glowCorner: .bottomTrailing)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
        }
        .buttonStyle(.strideCard)
    }
}

private struct TapeMeasureView: View {
    let value: Double

    var body: some View {
        Canvas { context, size in
            let bandTop: CGFloat = 10
            let bandHeight: CGFloat = 34
            let rect = CGRect(x: -20, y: bandTop, width: size.width + 40, height: bandHeight)

            context.fill(
                Path(rect),
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xD9B036), Color(hex: 0xF7D768), Color(hex: 0xC89D24)]),
                    startPoint: CGPoint(x: 0, y: bandTop),
                    endPoint: CGPoint(x: size.width, y: bandTop + bandHeight)
                )
            )

            // 刻度：每 1 小时 = 38pt
            let pxPerUnit: CGFloat = 38
            let centerVal = max(0, value)
            let minTick = Int(floor((centerVal - 3) * 5))
            let maxTick = Int(ceil((centerVal + 3) * 5))

            for step in minTick...maxTick {
                let tickVal = Double(step) / 5.0
                guard tickVal >= 0 else { continue }
                let x = size.width / 2 + CGFloat(tickVal - centerVal) * pxPerUnit
                guard x >= -16, x <= size.width + 16 else { continue }
                let isMajor = step % 5 == 0
                let tickH: CGFloat = isMajor ? 11 : 6

                var topTick = Path()
                topTick.move(to: CGPoint(x: x, y: bandTop))
                topTick.addLine(to: CGPoint(x: x, y: bandTop + tickH))
                context.stroke(topTick, with: .color(.black.opacity(0.85)), lineWidth: isMajor ? 1.6 : 1)

                var botTick = Path()
                botTick.move(to: CGPoint(x: x, y: bandTop + bandHeight))
                botTick.addLine(to: CGPoint(x: x, y: bandTop + bandHeight - tickH * 0.7))
                context.stroke(botTick, with: .color(.black.opacity(0.65)), lineWidth: isMajor ? 1.4 : 0.9)

                if isMajor {
                    let label = Text("\(Int(tickVal.rounded()))")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(.black)
                    context.draw(label, at: CGPoint(x: x, y: bandTop + bandHeight * 0.56))
                }
            }

            // 绯红指针 + 顶部三角
            let cx = size.width / 2
            var needle = Path()
            needle.move(to: CGPoint(x: cx, y: 2))
            needle.addLine(to: CGPoint(x: cx, y: size.height - 2))
            context.stroke(needle, with: .color(Color(hex: 0xE62E2D)), lineWidth: 2.2)

            var tri = Path()
            tri.move(to: CGPoint(x: cx - 5.5, y: 3))
            tri.addLine(to: CGPoint(x: cx + 5.5, y: 3))
            tri.addLine(to: CGPoint(x: cx, y: 11))
            tri.closeSubpath()
            context.fill(tri, with: .color(Color(hex: 0xE62E2D)))
        }
    }
}
