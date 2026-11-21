import Foundation

// MARK: - 肌肉恢复评估

struct MuscleRecoveryItem: Identifiable, Equatable {
    let group: MuscleGroup
    let percent: Int
    let isRecommended: Bool

    var id: MuscleGroup { group }
}

enum MuscleRecoveryCalculator {

    /// 首页四主肌群（顺序与视觉柱图对应：胸、肩、背、腿）
    static let primaryGroups: [MuscleGroup] = [.chest, .shoulders, .back, .legs]

    /// 根据过去 72 小时的训练组数与时间衰减估算恢复百分比（0...100），
    /// 并在恢复充分的肌群中选出今日最推荐训练的部位。
    static func assess(
        sessions: [WorkoutSession],
        weeklySets: [MuscleGroup: Int] = [:],
        plannedFocus: MuscleGroup? = nil,
        now: Date = Date()
    ) -> [MuscleRecoveryItem] {
        let windowSec: TimeInterval = 72 * 3600
        var fatigueByGroup: [MuscleGroup: Double] = [:]

        for session in sessions {
            let age = now.timeIntervalSince(session.date)
            guard age >= 0, age < windowSec else { continue }
            let decay = 1.0 - (age / windowSec)
            for ex in session.exercises {
                let sets = ex.doneSets.count
                guard sets > 0 else { continue }
                let mappedGroup = mapToPrimary(ex.group)
                // 每完成一组带来约 10% 基础疲劳，随 72 小时线性恢复
                let load = Double(sets) * 10.0 * decay
                fatigueByGroup[mappedGroup, default: 0] += load
            }
        }

        var scores: [MuscleGroup: Int] = [:]
        for group in primaryGroups {
            let fatigue = min(95.0, fatigueByGroup[group] ?? 0)
            scores[group] = max(5, min(100, Int((100.0 - fatigue).rounded())))
        }

        let recommended = pickRecommended(
            scores: scores,
            weeklySets: weeklySets,
            plannedFocus: plannedFocus
        )

        return primaryGroups.map { group in
            MuscleRecoveryItem(
                group: group,
                percent: scores[group] ?? 100,
                isRecommended: group == recommended
            )
        }
    }

    private static func mapToPrimary(_ group: MuscleGroup) -> MuscleGroup {
        switch group {
        case .chest, .shoulders, .back, .legs:
            return group
        case .arms:
            return .back
        case .core, .cardio:
            return .legs
        }
    }

    private static func pickRecommended(
        scores: [MuscleGroup: Int],
        weeklySets: [MuscleGroup: Int],
        plannedFocus: MuscleGroup?
    ) -> MuscleGroup {
        if let plannedFocus,
           primaryGroups.contains(plannedFocus),
           (scores[plannedFocus] ?? 100) >= 75 {
            return plannedFocus
        }

        // 先按恢复度高优先，恢复相近时优先本周练得最少的肌群，其次按经典顺序（肩 -> 胸 -> 背 -> 腿）
        let tieOrder: [MuscleGroup] = [.shoulders, .chest, .back, .legs]
        return primaryGroups.max { lhs, rhs in
            let lScore = scores[lhs] ?? 100
            let rScore = scores[rhs] ?? 100
            if lScore != rScore { return lScore < rScore }

            let lSets = weeklySets[lhs] ?? 0
            let rSets = weeklySets[rhs] ?? 0
            if lSets != rSets { return lSets > rSets }

            let lIdx = tieOrder.firstIndex(of: lhs) ?? 99
            let rIdx = tieOrder.firstIndex(of: rhs) ?? 99
            return lIdx > rIdx
        } ?? .shoulders
    }
}

// MARK: - 咖啡因代谢与最佳饮用窗口

struct CaffeinePreset: Identifiable, Hashable {
    var id: String { title }
    let title: String
    let mg: Int
    let subtitle: String
}

enum CaffeineCalculator {

    static let halfLifeHours: Double = 5.0

    static let presets: [CaffeinePreset] = [
        CaffeinePreset(title: "浓缩咖啡", mg: 75, subtitle: "Single Espresso"),
        CaffeinePreset(title: "美式咖啡", mg: 150, subtitle: "中杯约 350 ml"),
        CaffeinePreset(title: "拿铁咖啡", mg: 80, subtitle: "单份浓缩 + 奶"),
        CaffeinePreset(title: "冰冷萃", mg: 200, subtitle: "高浓度冷萃"),
        CaffeinePreset(title: "绿茶 / 乌龙", mg: 40, subtitle: "现泡茶饮"),
        CaffeinePreset(title: "氮泵 / 功能饮", mg: 120, subtitle: "训前补剂")
    ]

    /// 计算当前时刻体内剩余咖啡因（mg），按 5 小时半衰期衰减
    static func activeMg(entries: [CaffeineEntry], at now: Date = Date()) -> Int {
        let total = entries.reduce(0.0) { sum, entry in
            let elapsedHours = now.timeIntervalSince(entry.date) / 3600.0
            guard elapsedHours >= 0, elapsedHours < 36 else { return sum }
            return sum + Double(entry.mg) * pow(0.5, elapsedHours / halfLifeHours)
        }
        return Int(total.rounded())
    }

    /// 依据预计入睡时间推算最佳饮用窗口（例如入睡 23:05 -> 窗口 13时–16时，起床参考 11时前提示）
    static func optimalWindowText(sleepHour: Int, sleepMinute: Int) -> (morningLabel: String, windowLabel: String) {
        let endHour = ((sleepHour - 7) % 24 + 24) % 24
        let startHour = ((endHour - 3) % 24 + 24) % 24
        let morningHour = ((startHour - 2) % 24 + 24) % 24
        return ("\(morningHour)时", "\(startHour)时–\(endHour)时")
    }

    static func formattedSleepTime(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", max(0, min(23, hour)), max(0, min(59, minute)))
    }
}

// MARK: - 本月训练时长

enum MonthlyTrainingCalculator {

    /// 统计指定日期所在自然月内的训练总小时数与总次数
    static func stats(
        sessions: [WorkoutSession],
        runs: [RouteRun],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> (hours: Double, count: Int) {
        guard let monthInterval = calendar.dateInterval(of: .month, for: now) else {
            return (0, 0)
        }
        let monthSessions = sessions.filter { monthInterval.contains($0.date) }
        let monthRuns = runs.filter { monthInterval.contains($0.date) }

        let sessionSec = monthSessions.reduce(0) { $0 + max(0, $1.durationSec) }
        // 若 sessions 里没有同一天完全同秒数的跑步记录，则叠加独立 RouteRun 时长
        let runSec = monthRuns.reduce(0) { total, run in
            let duplicated = monthSessions.contains {
                $0.kind == .run && abs($0.date.timeIntervalSince(run.date)) < 120
            }
            return duplicated ? total : total + max(0, run.durationSec)
        }

        let hours = Double(sessionSec + runSec) / 3600.0
        let rounded = (hours * 10).rounded() / 10
        return (rounded, monthSessions.count)
    }
}

// MARK: - AI 训练习惯洞察

struct TrainingHabitSummary: Equatable {
    let headline: String
    let subtitle: String
    let totalSessions: Int
    let favoriteGroup: String
    let avgMinutes: Int
    let totalTonnageText: String
}

enum HabitAnalyzer {

    static func summarize(sessions: [WorkoutSession], watchConnected: Bool) -> TrainingHabitSummary {
        let sourceTag = watchConnected ? "Apple Watch · AI 学习" : "本机统计 · AI 学习"
        guard !sessions.isEmpty else {
            return TrainingHabitSummary(
                headline: "正在等待你的第一练",
                subtitle: sourceTag,
                totalSessions: 0,
                favoriteGroup: "待记录",
                avgMinutes: 0,
                totalTonnageText: "0 t"
            )
        }

        var groupCounts: [MuscleGroup: Int] = [:]
        var totalSec = 0
        var totalVol = 0.0

        for s in sessions {
            totalSec += s.durationSec
            totalVol += s.totalVolume
            for ex in s.exercises where !ex.doneSets.isEmpty {
                groupCounts[ex.group, default: 0] += ex.doneSets.count
            }
        }

        let topGroup = groupCounts.max { $0.value < $1.value }?.key.rawValue ?? "综合"
        let avgMin = max(1, (totalSec / max(1, sessions.count)) / 60)
        let tonnage = totalVol / 1000.0
        let tonnageStr = tonnage >= 1 ? String(format: "%.1f t", tonnage) : "\(Int(totalVol)) kg"

        let headline = sessions.count >= 3 ? "已学习你的训练习惯" : "初步建立训练画像"
        return TrainingHabitSummary(
            headline: headline,
            subtitle: sourceTag,
            totalSessions: sessions.count,
            favoriteGroup: topGroup,
            avgMinutes: avgMin,
            totalTonnageText: tonnageStr
        )
    }
}

// MARK: - 补剂预设库与教练语录库

enum SupplementCatalog {
    static let presets: [SupplementItem] = [
        SupplementItem(name: "肌酸", dosage: "5 g", timingHint: "每天任意时段"),
        SupplementItem(name: "乳清蛋白粉", dosage: "30 g", timingHint: "练后或加餐"),
        SupplementItem(name: "深海鱼油", dosage: "2 粒", timingHint: "随餐服用"),
        SupplementItem(name: "维生素 D3", dosage: "2000 IU", timingHint: "随早餐"),
        SupplementItem(name: "甘氨酸镁", dosage: "200 mg", timingHint: "睡前 1 小时"),
        SupplementItem(name: "复合维生素", dosage: "1 片", timingHint: "随餐服用")
    ]
}

enum CoachQuoteBook {
    static let all: [String] = [
        "每周至少练一次背，体态会感谢你。",
        "最后 2 次接近力竭的动作质量，决定这组有没有效。",
        "体重波动很正常，看 7 天移动均值，别被一天数字带偏。",
        "训练日碳水留给练前和练后，恢复速度会快一个档次。",
        "觉得没劲时先减组数不减重量，保留神经募集。",
        "动作幅度做满，比盲目加 5 公斤更能刺激肌肥大。",
        "深蹲和硬拉之前，把核心腹压先吸稳再起杠。",
        "睡不够 6 小时，今天就把主项重量下调 15%，保质量不硬顶。",
        "喝够水不只是解渴，脱水 2% 力量输出就会明显掉线。",
        "蛋白吃够每公斤体重 1.8 克，比补剂堆叠实在得多。",
        "肩推前先激活下斜方和前锯肌，肩峰会舒服很多。",
        "渐进超负荷不止加重量，多做 1 次、放慢离心也是进步。"
    ]

    static func nextIndex(after current: Int) -> Int {
        guard !all.isEmpty else { return 0 }
        return (current + 1) % all.count
    }
}
