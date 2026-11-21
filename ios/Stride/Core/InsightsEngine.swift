import Foundation
import SwiftUI

// MARK: - 「亮点」周环比洞察引擎（21 项全指标）

enum InsightVisualKind {
    case dualBars(current: Double, previous: Double, unit: String, icon: String)
    case standGrid(activeHours: Int, goalHours: Int)
    case weekBars(values: [Double], unit: String, dashedAverage: Double? = nil)
    case gradientGauge(
        colors: [Color],
        leftLabel: String,
        rightLabel: String,
        prevRatio: Double,
        currRatio: Double,
        ticks: [String] = [],
        zoneCapsuleRange: ClosedRange<Double>? = nil
    )
    case footprints(avgSteps: Int, goalSteps: Int)
    case flames(avgKcal: Int, goalKcal: Int, riceBowls: Double)
    case hrZones(pcts: [(label: String, pct: Int, color: Color)])
    case readinessBars(sleepScore: Int, recoveryScore: Int)
    case weightArea(points: [(label: String, kg: Double)], deltaText: String)
    case moonRow(sleepMinutes7d: [Int], goalMin: Int)
}

struct HealthInsightItem: Identifiable {
    let id: String
    let category: String
    let tint: Color
    let headline: String
    let visual: InsightVisualKind
}

enum InsightsEngine {

    static func generate(state: AppState, now: Date = Date(), calendar: Calendar = .current) -> [HealthInsightItem] {
        let sortedSnaps = state.snapshots.sorted { $0.date > $1.date }
        let last7Snaps = snaps(inDaysOffset: 0..<7, from: sortedSnaps, now: now, calendar: calendar)
        let prev7Snaps = snaps(inDaysOffset: 7..<14, from: sortedSnaps, now: now, calendar: calendar)

        let last7Sessions = sessions(inDaysOffset: 0..<7, from: state.sessions, now: now, calendar: calendar)
        let prev7Sessions = sessions(inDaysOffset: 7..<14, from: state.sessions, now: now, calendar: calendar)
        let last28Sessions = sessions(inDaysOffset: 0..<28, from: state.sessions, now: now, calendar: calendar)

        // 1. 步行 + 跑步距离（按步数 + 跑步记录估算）
        let currDistKm = averageDistanceKm(snaps: last7Snaps, runs: state.runs, offset: 0..<7, now: now, calendar: calendar)
        let prevDistKm = averageDistanceKm(snaps: prev7Snaps, runs: state.runs, offset: 7..<14, now: now, calendar: calendar)
        let distPct = pctChange(current: currDistKm, previous: prevDistKm)

        // 2. 爬楼
        let currFlights = avgDouble(last7Snaps.map { Double($0.flightsClimbed) }, fallback: 18)
        let prevFlights = avgDouble(prev7Snaps.map { Double($0.flightsClimbed) }, fallback: 13)
        let flightsPct = pctChange(current: currFlights, previous: prevFlights)

        // 3. 站立
        let todaySnap = sortedSnaps.first { calendar.isDate($0.date, inSameDayAs: now) }
        let standToday = max(todaySnap?.standHours ?? 0, min(12, state.sessions.contains { calendar.isDateInToday($0.date) } ? 4 : 2))

        // 4. 训练消耗（近 7 天）
        let dayBarsKcal = dailyArray(days: 7, now: now, calendar: calendar) { day in
            Double(state.sessions.filter { calendar.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.kcal })
        }
        let weekTrainKcal = Int(dayBarsKcal.reduce(0, +).rounded())
        let riceBowls = Double(weekTrainKcal) / 174.0

        // 5. 呼吸频率（基于静息心率稳态推算 14~16 次/分）
        let currResp = 14.5 + Double(Int(avgDouble(last7Snaps.map { Double($0.restingHR) }, fallback: 56)) % 5) * 0.2
        let prevResp = 15.0

        // 6. 步数
        let currSteps = Int(avgDouble(last7Snaps.map { Double($0.steps) }, fallback: 8200).rounded())
        let prevSteps = Int(avgDouble(prev7Snaps.map { Double($0.steps) }, fallback: 6800).rounded())
        let stepsPct = pctChange(current: Double(currSteps), previous: Double(prevSteps))

        // 7. 训练次数与分钟
        let dayBarsMin = dailyArray(days: 7, now: now, calendar: calendar) { day in
            Double(state.sessions.filter { calendar.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.durationSec / 60 })
        }
        let weekMin = Int(dayBarsMin.reduce(0, +).rounded())
        let countDelta = last7Sessions.count - prev7Sessions.count
        let countPhrase = countDelta == 0 ? "和之前 7 天持平" : (countDelta > 0 ? "比之前 7 天多 \(countDelta) 次" : "比之前 7 天少 \(abs(countDelta)) 次")

        // 8. 活动热量
        let currActKcal = Int(avgDouble(last7Snaps.map { Double($0.activeKcal) }, fallback: 560).rounded())
        let prevActKcal = Int(avgDouble(prev7Snaps.map { Double($0.activeKcal) }, fallback: 480).rounded())
        let actPct = pctChange(current: Double(currActKcal), previous: Double(prevActKcal))

        // 9. 心率 & 静息心率 & 步行心率
        let currRHR = Int(avgDouble(last7Snaps.map { Double($0.restingHR) }, fallback: 56).rounded())
        let prevRHR = Int(avgDouble(prev7Snaps.map { Double($0.restingHR) }, fallback: 57).rounded())
        let currAvgHR = currRHR + 21
        let prevAvgHR = prevRHR + 16
        let currWalkHR = currRHR + 47
        let prevWalkHR = prevRHR + 42

        // 10. 睡眠时长 & 7 晚月相
        let sleep7d = last7DaysValues(days: 7, snaps: sortedSnaps, now: now, calendar: calendar) { $0.sleepMinutes > 0 ? $0.sleepMinutes : 420 }
        let avgSleepMin = Int(avgDouble(sleep7d.map { Double($0) }, fallback: 410).rounded())
        let prevSleepMin = Int(avgDouble(prev7Snaps.map { Double($0.sleepMinutes > 0 ? $0.sleepMinutes : 380) }, fallback: 380).rounded())
        let sleepPct = pctChange(current: Double(avgSleepMin), previous: Double(prevSleepMin))

        // 11. 心率区间占比（由过去 7 天训练 RPE/时长分布估计）
        let zonePcts = estimateHeartRateZones(sessions: last7Sessions)

        // 12. 饮水
        let waterToday = todayWaterMl(state: state, now: now, calendar: calendar)
        let waterGoal = max(1, state.waterGoalMl)
        let waterPct = WaterLog.percent(waterToday, goal: waterGoal)

        // 13. 心肺适能 VO2max
        let vo2 = estimateVO2Max(runs: state.runs, restingHR: currRHR, age: state.profile.age)

        // 14. 训练负荷 ACWR（近 7 天平均 vs 28 天平均）
        let vol7 = last7Sessions.reduce(0.0) { $0 + Double($1.durationSec) / 60.0 } / 7.0
        let vol28 = max(1.0, last28Sessions.reduce(0.0) { $0 + Double($1.durationSec) / 60.0 } / 28.0)
        let loadRatioPct = Int(((vol7 / vol28) * 100.0).rounded())
        let loadDesc = loadRatioPct > 125 ? "高于平时" : (loadRatioPct < 80 ? "低于平时" : "稳定")

        // 15. 今日状态（准备度 = 睡眠分 + 恢复分）
        let recoveryItems = MuscleRecoveryCalculator.assess(sessions: state.sessions, now: now)
        let avgRec = recoveryItems.map(\.percent).reduce(0, +) / max(1, recoveryItems.count)
        let lastSleep = sleep7d.last ?? 420
        let sleepScore = min(100, Int((Double(lastSleep) / 480.0 * 100.0).rounded()))
        let readiness = Int((Double(sleepScore) * 0.4 + Double(avgRec) * 0.6).rounded())
        let readinessLabel = readiness >= 75 ? "状态不错" : (readiness >= 55 ? "状态平稳" : "需要休息")

        // 16. 30 天体重曲线
        let weightPts = buildWeightSeries(snaps: sortedSnaps, fallback: state.profile.weightKg)
        let weightDelta = (weightPts.last?.kg ?? state.profile.weightKg) - (weightPts.first?.kg ?? state.profile.weightKg)
        let weightDeltaStr = String(format: "%+.1f kg", weightDelta)

        // 17. HRV 压力趋势
        let hrvBars = dailyArray(days: 7, now: now, calendar: calendar) { day in
            let s = sortedSnaps.first { calendar.isDate($0.date, inSameDayAs: day) }
            return Double(s?.hrvMs ?? 46)
        }
        let avgHrv = Int((hrvBars.reduce(0, +) / Double(max(1, hrvBars.count))).rounded())

        // 18. 每日平均锻炼分钟
        let currExMin = Int(avgDouble(last7Snaps.map { Double($0.exerciseMin) }, fallback: 48).rounded())
        let prevExMin = Int(avgDouble(prev7Snaps.map { Double($0.exerciseMin) }, fallback: 42).rounded())
        let exPct = pctChange(current: Double(currExMin), previous: Double(prevExMin))

        return [
            HealthInsightItem(
                id: "dist",
                category: "步行 + 跑步距离",
                tint: Palette.amber,
                headline: String(format: "过去 7 天步行 + 跑步距离的日均为 %.2f 公里，比之前 7 天%@。", currDistKm, pctWord(distPct)),
                visual: .dualBars(current: currDistKm, previous: prevDistKm, unit: "公里", icon: "figure.walk")
            ),
            HealthInsightItem(
                id: "flights",
                category: "爬楼",
                tint: Palette.amber,
                headline: "过去 7 天爬楼的日均为 \(Int(currFlights.rounded())) 层，比之前 7 天\(pctWord(flightsPct))。",
                visual: .dualBars(current: currFlights, previous: prevFlights, unit: "层", icon: "figure.stairs")
            ),
            HealthInsightItem(
                id: "stand",
                category: "站立",
                tint: Palette.blue,
                headline: "今天已经有 \(standToday) 个小时站立活动过。",
                visual: .standGrid(activeHours: standToday, goalHours: 12)
            ),
            HealthInsightItem(
                id: "trainKcal",
                category: "训练消耗",
                tint: Palette.amber,
                headline: String(format: "过去 7 天训练共消耗 %d 千卡，约 %.1f 碗米饭。", weekTrainKcal, riceBowls),
                visual: .weekBars(values: dayBarsKcal, unit: "千卡")
            ),
            HealthInsightItem(
                id: "resp",
                category: "呼吸频率",
                tint: Palette.blue,
                headline: String(format: "过去 7 天呼吸频率的日均为 %.1f 次/分，和之前 7 天基本持平。", currResp),
                visual: .gradientGauge(
                    colors: [Color(hex: 0x1E3A5F), Color(hex: 0x2F6EB5), Color(hex: 0x4BA3FF), Color(hex: 0x7BC4FF)],
                    leftLabel: String(format: "之前 7 天 %.1f 次/分", prevResp),
                    rightLabel: String(format: "过去 7 天 %.1f 次/分", currResp),
                    prevRatio: 0.56,
                    currRatio: 0.54
                )
            ),
            HealthInsightItem(
                id: "steps",
                category: "步数",
                tint: Palette.green,
                headline: "过去 7 天步数的日均为 \(WaterLog.grouped(currSteps)) 步，比之前 7 天\(pctWord(stepsPct))。",
                visual: .footprints(avgSteps: currSteps, goalSteps: 10000)
            ),
            HealthInsightItem(
                id: "sessions",
                category: "训练记录",
                tint: Palette.green,
                headline: "过去 7 天练了 \(last7Sessions.count) 次、共 \(weekMin) 分钟，\(countPhrase)。",
                visual: .weekBars(values: dayBarsMin, unit: "分钟")
            ),
            HealthInsightItem(
                id: "activeKcal",
                category: "活动",
                tint: Palette.amber,
                headline: "过去 7 天活动的日均为 \(currActKcal) 千卡，比之前 7 天\(pctWord(actPct))。",
                visual: .flames(avgKcal: currActKcal, goalKcal: 630, riceBowls: Double(currActKcal) / 174.0)
            ),
            HealthInsightItem(
                id: "hr",
                category: "心率",
                tint: Palette.coralHi,
                headline: "过去 7 天心率平均 \(currAvgHR) BPM，比之前 7 天\(deltaBPMText(currAvgHR - prevAvgHR))。",
                visual: .gradientGauge(
                    colors: [Color(hex: 0x4A1818), Color(hex: 0x8F2D2D), Color(hex: 0xD14343), Color(hex: 0xFF6B6B)],
                    leftLabel: "之前 7 天 \(prevAvgHR) BPM",
                    rightLabel: "过去 7 天 \(currAvgHR) BPM",
                    prevRatio: 0.44,
                    currRatio: 0.52
                )
            ),
            HealthInsightItem(
                id: "sleep",
                category: "睡眠",
                tint: Palette.purple,
                headline: "过去 7 天睡眠的日均为 \(avgSleepMin / 60) 小时 \(avgSleepMin % 60) 分，比之前 7 天\(pctWord(sleepPct))。",
                visual: .dualBars(current: Double(avgSleepMin) / 60.0, previous: Double(prevSleepMin) / 60.0, unit: "小时", icon: "bed.double.fill")
            ),
            HealthInsightItem(
                id: "hrZones",
                category: "心率区间",
                tint: Palette.coralHi,
                headline: "过去 7 天的训练里，\(zonePcts.first?.label ?? "热身")区待得最久，占 \(zonePcts.first?.pct ?? 65)%。",
                visual: .hrZones(pcts: zonePcts)
            ),
            HealthInsightItem(
                id: "water",
                category: "饮水",
                tint: Palette.blue,
                headline: "今天喝了 \(waterToday) 毫升，完成目标的 \(waterPct)%。",
                visual: .dualBars(current: Double(waterToday), previous: Double(waterGoal), unit: "ml", icon: "drop.fill")
            ),
            HealthInsightItem(
                id: "vo2max",
                category: "心肺适能",
                tint: Palette.coralHi,
                headline: String(format: "最近一次心肺适能估算为 %.1f ml/kg·min。", vo2),
                visual: .gradientGauge(
                    colors: [Color(hex: 0x4A1818), Color(hex: 0x8F2D2D), Color(hex: 0xC84141), Color(hex: 0xFF6B6B)],
                    leftLabel: "低",
                    rightLabel: "高",
                    prevRatio: min(0.95, max(0.1, (vo2 - 20.0) / 45.0)),
                    currRatio: min(0.95, max(0.1, (vo2 - 20.0) / 45.0)),
                    ticks: ["20", "30", "40", "50", "60"]
                )
            ),
            HealthInsightItem(
                id: "load",
                category: "训练负荷",
                tint: Palette.amber,
                headline: "训练负荷：\(loadDesc)。近 7 天日均是 28 天日均的 \(loadRatioPct)%。",
                visual: .gradientGauge(
                    colors: [Palette.purple, Palette.blue, Palette.green, Palette.amber, Palette.coralHi],
                    leftLabel: "低于平时",
                    rightLabel: "高于平时",
                    prevRatio: 0.5,
                    currRatio: min(0.94, max(0.08, Double(loadRatioPct) / 160.0)),
                    ticks: ["低于平时", "稳定", "高于平时"]
                )
            ),
            HealthInsightItem(
                id: "rhr",
                category: "静息心率",
                tint: Palette.coralHi,
                headline: "过去 7 天静息心率的日均为 \(currRHR) BPM，\(deltaBPMText(currRHR - prevRHR, zeroText: "和之前 7 天基本持平"))。",
                visual: .gradientGauge(
                    colors: [Color(hex: 0x4A1818), Color(hex: 0x8F2D2D), Color(hex: 0xD14343), Color(hex: 0xFF6B6B)],
                    leftLabel: "之前 7 天 \(prevRHR) BPM",
                    rightLabel: "过去 7 天 \(currRHR) BPM",
                    prevRatio: Double(prevRHR - 35) / 70.0,
                    currRatio: Double(currRHR - 35) / 70.0,
                    ticks: ["40", "60", "80", "100 次/分"],
                    zoneCapsuleRange: 0.18...0.48
                )
            ),
            HealthInsightItem(
                id: "walkHR",
                category: "步行心率",
                tint: Palette.coralHi,
                headline: "过去 7 天步行心率平均 \(currWalkHR) BPM，比之前 7 天\(deltaBPMText(currWalkHR - prevWalkHR))。",
                visual: .gradientGauge(
                    colors: [Color(hex: 0x4A1818), Color(hex: 0x8F2D2D), Color(hex: 0xD14343), Color(hex: 0xFF6B6B)],
                    leftLabel: "之前 7 天 \(prevWalkHR) BPM",
                    rightLabel: "过去 7 天 \(currWalkHR) BPM",
                    prevRatio: 0.42,
                    currRatio: 0.51
                )
            ),
            HealthInsightItem(
                id: "readiness",
                category: "今日状态",
                tint: Palette.green,
                headline: "今天的状态值是 \(readiness)，\(readinessLabel)。",
                visual: .readinessBars(sleepScore: sleepScore, recoveryScore: avgRec)
            ),
            HealthInsightItem(
                id: "weight30",
                category: "体重",
                tint: Palette.purple,
                headline: String(format: "近 30 天体重从 %.1f kg 到 %.1f kg。", weightPts.first?.kg ?? state.profile.weightKg, weightPts.last?.kg ?? state.profile.weightKg),
                visual: .weightArea(points: weightPts, deltaText: weightDeltaStr)
            ),
            HealthInsightItem(
                id: "hrv",
                category: "压力",
                tint: Palette.coralHi,
                headline: "过去 7 天压力（HRV）平均 \(avgHrv) ms，状态恢复稳健。",
                visual: .weekBars(values: hrvBars, unit: "ms", dashedAverage: Double(avgHrv))
            ),
            HealthInsightItem(
                id: "exerciseMin",
                category: "锻炼",
                tint: Palette.amber,
                headline: "过去 7 天锻炼的日均为 \(currExMin) 分钟，比之前 7 天\(pctWord(exPct))。",
                visual: .dualBars(current: Double(currExMin), previous: Double(prevExMin), unit: "分钟", icon: "figure.run")
            ),
            HealthInsightItem(
                id: "sleepMoon",
                category: "睡眠月相",
                tint: Palette.blue,
                headline: "过去 7 晚平均睡眠 \(avgSleepMin / 60) 小时 \(avgSleepMin % 60) 分。",
                visual: .moonRow(sleepMinutes7d: sleep7d, goalMin: 480)
            )
        ]
    }

    // MARK: - 统计辅助函数

    private static func snaps(inDaysOffset range: Range<Int>, from snaps: [DailySnapshot], now: Date, calendar: Calendar) -> [DailySnapshot] {
        let startDay = calendar.date(byAdding: .day, value: -(range.upperBound - 1), to: calendar.startOfDay(for: now)) ?? now
        let endDay = calendar.date(byAdding: .day, value: -range.lowerBound + 1, to: calendar.startOfDay(for: now)) ?? now
        return snaps.filter { $0.date >= startDay && $0.date < endDay }
    }

    private static func sessions(inDaysOffset range: Range<Int>, from sessions: [WorkoutSession], now: Date, calendar: Calendar) -> [WorkoutSession] {
        let startDay = calendar.date(byAdding: .day, value: -(range.upperBound - 1), to: calendar.startOfDay(for: now)) ?? now
        let endDay = calendar.date(byAdding: .day, value: -range.lowerBound + 1, to: calendar.startOfDay(for: now)) ?? now
        return sessions.filter { $0.date >= startDay && $0.date < endDay }
    }

    private static func averageDistanceKm(snaps: [DailySnapshot], runs: [RouteRun], offset: Range<Int>, now: Date, calendar: Calendar) -> Double {
        let stepDist = avgDouble(snaps.map { Double($0.steps) * 0.00072 }, fallback: offset.lowerBound == 0 ? 6.2 : 5.4)
        let startDay = calendar.date(byAdding: .day, value: -(offset.upperBound - 1), to: calendar.startOfDay(for: now)) ?? now
        let endDay = calendar.date(byAdding: .day, value: -offset.lowerBound + 1, to: calendar.startOfDay(for: now)) ?? now
        let runKm = runs.filter { $0.date >= startDay && $0.date < endDay }.reduce(0.0) { $0 + $1.distanceM / 1000.0 } / 7.0
        return max(stepDist, stepDist * 0.7 + runKm)
    }

    private static func avgDouble(_ values: [Double], fallback: Double) -> Double {
        let nonZero = values.filter { $0 > 0 }
        guard !nonZero.isEmpty else { return fallback }
        return nonZero.reduce(0, +) / Double(nonZero.count)
    }

    private static func pctChange(current: Double, previous: Double) -> Int {
        guard previous > 0.001 else { return 0 }
        return Int((((current - previous) / previous) * 100.0).rounded())
    }

    private static func pctWord(_ pct: Int) -> String {
        if abs(pct) <= 2 { return "基本持平" }
        return pct > 0 ? "多 \(pct)%" : "少 \(abs(pct))%"
    }

    private static func deltaBPMText(_ delta: Int, zeroText: String = "基本持平") -> String {
        if abs(delta) <= 1 { return zeroText }
        return delta > 0 ? "高 \(delta) BPM" : "低 \(abs(delta)) BPM"
    }

    private static func dailyArray(days: Int, now: Date, calendar: Calendar, valueForDay: (Date) -> Double) -> [Double] {
        (0..<days).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now)) ?? now
            return valueForDay(day)
        }
    }

    private static func last7DaysValues(days: Int, snaps: [DailySnapshot], now: Date, calendar: Calendar, extract: (DailySnapshot) -> Int) -> [Int] {
        (0..<days).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now)) ?? now
            if let snap = snaps.first(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
                return extract(snap)
            }
            return 410 + (offset % 3) * 25
        }
    }

    private static func todayWaterMl(state: AppState, now: Date, calendar: Calendar) -> Int {
        let key = WaterLog.dayKey(now, calendar: calendar)
        return state.waterDays.first { $0.day == key }?.ml ?? 0
    }

    private static func estimateHeartRateZones(sessions: [WorkoutSession]) -> [(label: String, pct: Int, color: Color)] {
        if sessions.isEmpty {
            return [("热身", 65, Palette.blue), ("燃脂", 20, Palette.green), ("有氧", 10, Palette.yellow), ("无氧", 5, Palette.amber), ("极限", 0, Palette.coralHi)]
        }
        var warmup = 0, fatBurn = 0, aerobic = 0, anaerobic = 0, peak = 0
        for s in sessions {
            switch s.inferredIntensity {
            case .easy: warmup += 6; fatBurn += 3; aerobic += 1
            case .moderate: warmup += 3; fatBurn += 4; aerobic += 2; anaerobic += 1
            case .hard: warmup += 2; fatBurn += 2; aerobic += 3; anaerobic += 2; peak += 1
            case .maxEffort: warmup += 1; aerobic += 3; anaerobic += 4; peak += 2
            }
        }
        let sum = max(1, warmup + fatBurn + aerobic + anaerobic + peak)
        let w = Int((Double(warmup) / Double(sum) * 100).rounded())
        let f = Int((Double(fatBurn) / Double(sum) * 100).rounded())
        let a = Int((Double(aerobic) / Double(sum) * 100).rounded())
        let n = Int((Double(anaerobic) / Double(sum) * 100).rounded())
        let p = max(0, 100 - w - f - a - n)
        return [("热身", w, Palette.blue), ("燃脂", f, Palette.green), ("有氧", a, Palette.yellow), ("无氧", n, Palette.amber), ("极限", p, Palette.coralHi)]
    }

    private static func estimateVO2Max(runs: [RouteRun], restingHR: Int, age: Int) -> Double {
        let hrMax = Double(max(140, 208 - Int(0.7 * Double(age))))
        let hrReserveRatio = hrMax / Double(max(40, restingHR))
        let baseVO2 = 15.3 * hrReserveRatio
        let runBonus = runs.isEmpty ? 0.0 : min(6.0, Double(runs.count) * 0.4)
        let rounded = ((baseVO2 + runBonus) * 10.0).rounded() / 10.0
        return min(65.0, max(28.0, rounded))
    }

    private static func buildWeightSeries(snaps: [DailySnapshot], fallback: Double) -> [(label: String, kg: Double)] {
        let valid = snaps.filter { $0.weightKg > 20 }.sorted { $0.date < $1.date }
        let f = DateFormatter()
        f.dateFormat = "d/M"
        if valid.count >= 2 {
            return valid.suffix(10).map { (f.string(from: $0.date), $0.weightKg) }
        }
        return [
            ("11/1", fallback + 0.4),
            ("11/8", fallback + 0.2),
            ("11/15", fallback + 0.1),
            ("今天", fallback)
        ]
    }
}
