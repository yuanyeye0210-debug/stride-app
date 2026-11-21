import SwiftUI

// MARK: - 7. 肌肉恢复 2×2 卡片

struct MuscleRecoveryBentoCard: View {
    let items: [MuscleRecoveryItem]
    var onTap: () -> Void

    private var recommendedName: String {
        items.first(where: \.isRecommended)?.group.rawValue ?? "肩"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text("肌肉恢复")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.text)

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
                                let ratio = CGFloat(max(8, min(100, item.percent))) / 100.0
                                let barColor: Color = {
                                    if item.isRecommended { return Palette.lime }
                                    if item.percent >= 70 { return Palette.green }
                                    return Palette.amber
                                }()
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(barColor)
                                        .frame(height: geo.size.height * ratio)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(
                                            item.isRecommended ? Color.white.opacity(0.75) : Color.white.opacity(0.15),
                                            lineWidth: item.isRecommended ? 1.4 : 0.8
                                        )
                                )
                            }
                            .frame(height: 62)

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
            .card(radius: Metrics.radius, fill: Palette.card, stroke: Palette.stroke)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 8. 咖啡因代谢卡片

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
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("记一杯咖啡因")
            }

            HStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(todayMg)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(todayMg > limitMg ? Palette.amber : Palette.text)
                    Text("/ \(limitMg) 毫克")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.textDim)
                }
                Spacer()
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.white.opacity(0.75))
            }

            Spacer(minLength: 2)

            VStack(spacing: 5) {
                Text("最佳饮用时间")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.textFaint)

                HStack(spacing: 4) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.7))
                        .frame(width: 30, height: 14)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0xD97B29), Color(hex: 0xFFB04F), Color(hex: 0xD97B29)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(Capsule().strokeBorder(Color(hex: 0xFFD48D).opacity(0.7), lineWidth: 0.8))
                        .shadow(color: Color(hex: 0xFF9E3D).opacity(0.45), radius: 6)
                        .frame(maxWidth: .infinity)
                        .frame(height: 14)

                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.7))
                        .frame(width: 34, height: 14)
                }

                HStack {
                    Text(window.morningLabel)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Palette.textFaint)
                    Spacer()
                    Text(window.windowLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Palette.text)
                    Spacer()
                    Text("入睡")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Palette.textFaint)
                }
            }

            HStack(spacing: 5) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.purple)
                Text("预计入睡 \(CaffeineCalculator.formattedSleepTime(hour: sleepHour, minute: sleepMinute))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.textDim)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(height: 178)
        .card(radius: Metrics.radius, fill: Palette.card, stroke: Palette.stroke)
        .contentShape(Rectangle())
        .onTapGesture(perform: onAdd)
    }
}

// MARK: - 9. Stride 食堂锯齿小票卡片

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
            RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                .fill(Color(hex: 0xECECEE))

            VStack(alignment: .leading, spacing: 6) {
                Text("\(Brand.canteenTitle) · \(dateBadge)")
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: 0x1E1E22))
                    .frame(maxWidth: .infinity, alignment: .center)

                Rectangle()
                    .fill(Color.black.opacity(0.14))
                    .frame(height: 0.7)

                if foods.isEmpty {
                    Text("今天还没记 · 点 + 记一餐")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color(hex: 0x7A7A82))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 3) {
                        ForEach(foods.suffix(2)) { entry in
                            HStack {
                                Text(entry.items.first?.name ?? entry.meal.rawValue)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundStyle(Color(hex: 0x2B2B30))
                                    .lineLimit(1)
                                Spacer()
                                Text("\(Int(entry.kcal.rounded()))")
                                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Color(hex: 0x55555D))
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                DashedLine()
                    .stroke(Color.black.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(height: 1)

                HStack {
                    Text("合计")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(Color(hex: 0x18181B))
                    Spacer()
                    Text(WaterLog.grouped(eatenKcal))
                        .font(.system(size: 13.5, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color(hex: 0x18181B))
                }

                HStack {
                    Text(remainingKcal >= 0 ? "还能吃" : "超出")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(remainingKcal >= 0 ? Palette.green : Palette.coral)
                    Spacer()
                    Text(WaterLog.grouped(abs(remainingKcal)))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(remainingKcal >= 0 ? Palette.green : Palette.coral)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ReceiptPaperShape(toothCount: 13)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            )
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 10)

            Button(action: onAddFood) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color(hex: 0x0F0F12)))
                    .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel("记一餐")
        }
        .frame(height: 178)
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

// MARK: - 10. 活动三环 2×2 卡片

struct ActivityRingsBentoCard: View {
    let moveProgress: Double
    let exerciseProgress: Double
    let standProgress: Double
    var onTap: () -> Void

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
                    .fill(Color.white)
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.black)
                    }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 178)
            .card(radius: Metrics.radius, fill: Palette.card, stroke: Palette.stroke)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("今日活动三环")
    }
}

// MARK: - 11. 本月训练时长卷尺卡片

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
                        Text("H")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.text)
                        Spacer()
                        Text("\(count) 次")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Palette.textFaint)
                    }
                }
                .padding(16)

                TapeMeasureView(value: hours)
                    .frame(height: 54)
                    .rotationEffect(.degrees(-8))
                    .offset(y: -2)
            }
            .frame(height: 178)
            .card(radius: Metrics.radius, fill: Palette.card, stroke: Palette.stroke)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
        }
        .buttonStyle(.plain)
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
                    Gradient(colors: [Color(hex: 0xE6C619), Color(hex: 0xFFE338), Color(hex: 0xDFBA12)]),
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

            // 红色指针 + 顶部三角
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
