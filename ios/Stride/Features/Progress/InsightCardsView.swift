import SwiftUI
import Charts

// MARK: - 「亮点」单条视图（对应图 73–77）

struct HealthInsightRowView: View {
    let item: HealthInsightItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.category)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(item.tint)

            Text(item.headline)
                .font(.system(size: 16.5, weight: .bold))
                .foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)

            visualBody
                .padding(.top, 2)
        }
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var visualBody: some View {
        switch item.visual {
        case .dualBars(let current, let previous, let unit, let icon):
            DualCompareBarsView(current: current, previous: previous, unit: unit, icon: icon, tint: item.tint)

        case .standGrid(let activeHours, let goalHours):
            StandHoursBarView(activeHours: activeHours, goalHours: goalHours, tint: item.tint)

        case .weekBars(let values, _, let dashedAverage):
            WeekSevenBarsView(values: values, tint: item.tint, dashedAverage: dashedAverage)

        case .gradientGauge(let colors, let left, let right, let prevRatio, let currRatio, let ticks, let capsuleRange):
            GradientGaugeBarView(
                colors: colors,
                leftLabel: left,
                rightLabel: right,
                prevRatio: prevRatio,
                currRatio: currRatio,
                ticks: ticks,
                zoneCapsuleRange: capsuleRange
            )

        case .footprints(let avgSteps, let goalSteps):
            FootprintsPictogramView(avgSteps: avgSteps, goalSteps: goalSteps, tint: item.tint)

        case .flames(let avgKcal, let goalKcal, let riceBowls):
            FlamesPictogramView(avgKcal: avgKcal, goalKcal: goalKcal, riceBowls: riceBowls, tint: item.tint)

        case .hrZones(let pcts):
            HeartRateZonesRowView(zones: pcts)

        case .readinessBars(let sleepScore, let recoveryScore):
            ReadinessDualBarsView(sleepScore: sleepScore, recoveryScore: recoveryScore)

        case .weightArea(let points, let deltaText):
            WeightThirtyAreaView(points: points, deltaText: deltaText, tint: item.tint)

        case .moonRow(let sleepMinutes7d, let goalMin):
            SleepMoonPhaseRowView(minutes: sleepMinutes7d, goalMin: goalMin)
        }
    }
}

// MARK: - 1. 双横向对比条

private struct DualCompareBarsView: View {
    let current: Double
    let previous: Double
    let unit: String
    let icon: String
    let tint: Color

    var body: some View {
        let maxVal = max(1, max(current, previous))
        VStack(spacing: 8) {
            barRow(value: current, maxVal: maxVal, label: "\(fmt(current)) \(unit) · 过去 7 天", fill: tint, active: true)
            barRow(value: previous, maxVal: maxVal, label: "\(fmt(previous)) \(unit) · 之前 7 天", fill: Color.white.opacity(0.14), active: false)
        }
    }

    private func barRow(value: Double, maxVal: Double, label: String, fill: Color, active: Bool) -> some View {
        GeometryReader { geo in
            let w = max(92, geo.size.width * min(1, value / maxVal))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.06))
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                    Text(label)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(active ? Color.black : Palette.textDim)
                .padding(.horizontal, 12)
                .frame(width: w, height: 28, alignment: .leading)
                .background(Capsule().fill(fill))
            }
        }
        .frame(height: 28)
    }

    private func fmt(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))" : String(format: "%.2f", v)
    }
}

// MARK: - 2. 站立 12 格方块

private struct StandHoursBarView: View {
    let activeHours: Int
    let goalHours: Int
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                ForEach(0..<goalHours, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(i < activeHours ? tint : Color.white.opacity(0.12))
                        .frame(height: 18)
                }
            }
            HStack {
                Text("\(activeHours) / \(goalHours) 小时")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textDim)
                Spacer()
                Text("1 格 = 1 小时")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textFaint)
            }
        }
    }
}

// MARK: - 3. 7 日柱状图（含可选平均虚线）

private struct WeekSevenBarsView: View {
    let values: [Double]
    let tint: Color
    var dashedAverage: Double? = nil

    private let dayNames = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        let maxVal = max(1, values.max() ?? 1)
        ZStack(alignment: .center) {
            if let dashedAverage, maxVal > 0 {
                GeometryReader { geo in
                    let yRatio = 1 - min(1, max(0, dashedAverage / maxVal))
                    Path { p in
                        let y = geo.size.height * 0.72 * yRatio
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(values.indices, id: \.self) { i in
                    let v = values[i]
                    let barH = v <= 0 ? 6 : max(10, 56 * (v / maxVal))
                    let isLast = i == values.count - 1
                    VStack(spacing: 6) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(v <= 0 ? Color.white.opacity(0.10) : (isLast ? tint : tint.opacity(0.7)))
                            .frame(height: barH)
                        Text(dayLabel(offsetFromEnd: values.count - 1 - i))
                            .font(.system(size: 10.5, weight: isLast ? .bold : .medium))
                            .foregroundStyle(isLast ? tint : Palette.textFaint)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 76)
        }
    }

    private func dayLabel(offsetFromEnd: Int) -> String {
        let d = Calendar.current.date(byAdding: .day, value: -offsetFromEnd, to: Date()) ?? Date()
        let wd = Calendar.current.component(.weekday, from: d)
        return dayNames[max(0, min(6, wd - 1))]
    }
}

// MARK: - 4. 分段渐变标尺与对比针

private struct GradientGaugeBarView: View {
    let colors: [Color]
    let leftLabel: String
    let rightLabel: String
    let prevRatio: Double
    let currRatio: Double
    var ticks: [String] = []
    var zoneCapsuleRange: ClosedRange<Double>? = nil

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    HStack(spacing: 3) {
                        ForEach(colors.indices, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(colors[i])
                        }
                    }
                    .frame(height: 14)

                    if let range = zoneCapsuleRange {
                        let startX = w * min(1, max(0, range.lowerBound))
                        let spanW = max(18, w * min(1, max(0, range.upperBound - range.lowerBound)))
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.65), lineWidth: 1.5)
                            .frame(width: spanW, height: 18)
                            .offset(x: startX)
                    }

                    // 之前 7 天细标线
                    Capsule()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 2.5, height: 22)
                        .offset(x: max(0, min(w - 3, w * prevRatio)))

                    // 过去 7 天主白竖针
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 3.5, height: 24)
                        .shadow(color: .black.opacity(0.5), radius: 3)
                        .offset(x: max(0, min(w - 4, w * currRatio)))
                }
            }
            .frame(height: 24)

            if !ticks.isEmpty {
                HStack {
                    ForEach(ticks.indices, id: \.self) { i in
                        Text(ticks[i])
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.textFaint)
                        if i < ticks.count - 1 { Spacer() }
                    }
                }
            }

            HStack {
                Text(leftLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textFaint)
                Spacer()
                Text(rightLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.textDim)
            }
        }
    }
}

// MARK: - 5. 步数脚印象形图

private struct FootprintsPictogramView: View {
    let avgSteps: Int
    let goalSteps: Int
    let tint: Color

    var body: some View {
        let litCount = min(10, max(1, Int((Double(avgSteps) / Double(max(1, goalSteps)) * 10.0).rounded())))
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(0..<10, id: \.self) { i in
                    Image(systemName: "shoeprints.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(i < litCount ? tint : Color.white.opacity(0.14))
                        .frame(maxWidth: .infinity)
                }
            }
            HStack {
                Text("1 个脚印 = 1,000 步")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textFaint)
                Spacer()
                Text(WaterLog.grouped(goalSteps))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Palette.textFaint)
            }
        }
    }
}

// MARK: - 6. 活动火焰象形图

private struct FlamesPictogramView: View {
    let avgKcal: Int
    let goalKcal: Int
    let riceBowls: Double
    let tint: Color

    var body: some View {
        let litCount = min(10, max(1, Int((Double(avgKcal) / Double(max(1, goalKcal)) * 10.0).rounded())))
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(0..<10, id: \.self) { i in
                    Image(systemName: "flame.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(i < litCount ? tint : Color.white.opacity(0.14))
                        .frame(maxWidth: .infinity)
                }
            }
            HStack {
                Text(String(format: "≈ %.1f 碗米饭", riceBowls))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textFaint)
                Spacer()
                Text("/ \(goalKcal) 千卡")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Palette.textFaint)
            }
        }
    }
}

// MARK: - 7. 心率 5 区间条

private struct HeartRateZonesRowView: View {
    let zones: [(label: String, pct: Int, color: Color)]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(zones.indices, id: \.self) { idx in
                let z = zones[idx]
                VStack(alignment: .leading, spacing: 4) {
                    Text(z.label)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Palette.textDim)
                    Text(z.pct > 0 ? "\(z.pct)%" : "–")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(z.pct > 0 ? z.color : Palette.textFaint)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.1))
                            Capsule().fill(z.color)
                                .frame(width: max(4, geo.size.width * CGFloat(z.pct) / 100.0))
                        }
                    }
                    .frame(height: 5)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - 8. 今日状态双进度条

private struct ReadinessDualBarsView: View {
    let sleepScore: Int
    let recoveryScore: Int

    var body: some View {
        VStack(spacing: 8) {
            row(score: sleepScore, label: "睡眠", color: Palette.purple)
            row(score: recoveryScore, label: "恢复", color: Palette.green)
        }
    }

    private func row(score: Int, label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Text("\(score) · \(label)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.textDim)
                .frame(width: 78, alignment: .leading)
            BarProgress(progress: Double(score) / 100.0, color: color, height: 7)
        }
    }
}

// MARK: - 9. 30 天体重面积曲线

private struct WeightThirtyAreaView: View {
    let points: [(label: String, kg: Double)]
    let deltaText: String
    let tint: Color

    var body: some View {
        let minKg = (points.map(\.kg).min() ?? 60) - 0.8
        let maxKg = (points.map(\.kg).max() ?? 80) + 0.8
        VStack(spacing: 6) {
            Chart(points.indices, id: \.self) { i in
                LineMark(
                    x: .value("点", i),
                    y: .value("体重", points[i].kg)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(tint)

                AreaMark(
                    x: .value("点", i),
                    yStart: .value("底", minKg),
                    yEnd: .value("体重", points[i].kg)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(colors: [tint.opacity(0.30), .clear], startPoint: .top, endPoint: .bottom)
                )

                if i == points.count - 1 {
                    PointMark(x: .value("点", i), y: .value("体重", points[i].kg))
                        .foregroundStyle(Color.white)
                }
            }
            .chartYScale(domain: minKg...maxKg)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 68)

            HStack {
                Text(points.first?.label ?? "")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Palette.textFaint)
                Spacer()
                Text(deltaText)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                Spacer()
                Text(points.last?.label ?? "今天")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Palette.textFaint)
            }
        }
    }
}

// MARK: - 10. 7 晚金色月相球

struct SleepMoonPhaseRowView: View {
    let minutes: [Int]
    let goalMin: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(minutes.indices, id: \.self) { idx in
                let ratio = min(1.0, Double(minutes[idx]) / Double(max(1, goalMin)))
                let isLast = idx == minutes.count - 1
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: 0xFFF0B3), Color(hex: 0xD4A12A), Color(hex: 0x4A3810)],
                                center: .init(x: 0.35, y: 0.35),
                                startRadius: 2,
                                endRadius: 16
                            )
                        )
                        .opacity(0.4 + 0.6 * ratio)
                        .frame(width: 28, height: 28)

                    if isLast {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 1.8)
                            .frame(width: 34, height: 34)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
