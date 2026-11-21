import SwiftUI

struct ScientificCalculatorToolView: View {
    @EnvironmentObject private var store: AppStore
    let kind: CalculatorToolKind

    // 通用可复用调节状态
    @State private var weightKg: Double = 80
    @State private var reps: Int = 5
    @State private var bodyweightKg: Double = 75
    @State private var distanceKm: Double = 5.0
    @State private var minutes: Double = 24.0
    @State private var gradePct: Double = 3.0
    @State private var tempC: Double = 26
    @State private var humidityPct: Double = 70
    @State private var altitudeM: Double = 2200
    @State private var rpe: Double = 8.5
    @State private var ftpWatts: Double = 240
    @State private var css400Sec: Double = 420
    @State private var css200Sec: Double = 195
    @State private var waistCm: Double = 82
    @State private var neckCm: Double = 38
    @State private var hipCm: Double = 94
    @State private var restingHR: Double = 56
    @State private var maxHR: Double = 190
    @State private var hrvMs: Double = 52
    @State private var age: Int = 28
    @State private var sweatLostKg: Double = 1.1
    @State private var drinkLiters: Double = 0.3
    @State private var squatKg: Double = 120
    @State private var benchKg: Double = 90
    @State private var deadliftKg: Double = 150
    @State private var ohpKg: Double = 60
    @State private var sleepNowHour: Int = 23

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                calculatorContent
            }
            .padding(Metrics.page)
        }
        .onAppear {
            bodyweightKg = store.state.profile.weightKg
            maxHR = Double(store.state.profile.maxHeartRate)
            age = store.state.profile.age
        }
    }

    @ViewBuilder
    private var calculatorContent: some View {
        switch kind {
        case .oneRM:
            inputCard {
                Stepper("重量：\(Int(weightKg)) kg", value: $weightKg, in: 10...300, step: 2.5)
                Stepper("完成次数：\(reps) 次", value: $reps, in: 1...20)
            }
            let list = PluginMath.seven1RMFormulas(weight: weightKg, reps: reps)
            let avg = list.map(\.kg).reduce(0, +) / Double(max(1, list.count))
            resultBanner(title: "7 公式平均 1RM", value: String(format: "%.1f kg", avg), tint: Palette.green)
            ForEach(list, id: \.name) { row in
                kvRow(row.name, value: String(format: "%.1f kg", row.kg))
            }

        case .plates:
            inputCard {
                Stepper("目标总重量：\(String(format: "%.1f", weightKg)) kg", value: $weightKg, in: 20...320, step: 2.5)
            }
            let plates = PluginMath.platesPerSide(targetKg: weightKg)
            resultBanner(title: "单边挂片（20 kg 标准杆）", value: plates.isEmpty ? "空杆" : plates.map { $0 == $0.rounded() ? "\(Int($0))" : "\($0)" }.joined(separator: " + ") + " kg", tint: Palette.blue)

        case .warmUp:
            inputCard {
                Stepper("今日工作重量：\(Int(weightKg)) kg", value: $weightKg, in: 30...300, step: 2.5)
            }
            let stages: [(String, Double, Int)] = [("空杆激活", 0.0, 10), ("热身 1", 0.5, 6), ("热身 2", 0.7, 4), ("热身 3", 0.85, 2), ("工作组", 1.0, 5)]
            ForEach(stages, id: \.0) { s in
                let w = s.1 == 0 ? 20.0 : max(20, (weightKg * s.1 / 2.5).rounded() * 2.5)
                let plates = PluginMath.platesPerSide(targetKg: w)
                kvRow("\(s.0) · \(Int(w)) kg × \(s.2)", value: plates.isEmpty ? "空杆" : plates.map { "\($0)" }.joined(separator: "+"))
            }

        case .strengthLevel:
            inputCard {
                Stepper("深蹲 1RM：\(Int(squatKg)) kg", value: $squatKg, in: 20...350, step: 5)
                Stepper("卧推 1RM：\(Int(benchKg)) kg", value: $benchKg, in: 20...250, step: 2.5)
                Stepper("硬拉 1RM：\(Int(deadliftKg)) kg", value: $deadliftKg, in: 20...400, step: 5)
            }
            let bw = max(40, bodyweightKg)
            kvRow("深蹲倍体重", value: String(format: "%.2f × BW · %@", squatKg / bw, levelLabel(squatKg / bw, thresholds: [1.0, 1.5, 2.0, 2.5])))
            kvRow("卧推倍体重", value: String(format: "%.2f × BW · %@", benchKg / bw, levelLabel(benchKg / bw, thresholds: [0.75, 1.15, 1.5, 1.85])))
            kvRow("硬拉倍体重", value: String(format: "%.2f × BW · %@", deadliftKg / bw, levelLabel(deadliftKg / bw, thresholds: [1.25, 1.75, 2.25, 2.75])))

        case .dotsScore:
            inputCard {
                Stepper("三大项总成绩：\(Int(squatKg + benchKg + deadliftKg)) kg", value: $squatKg, in: 40...350, step: 5)
                Stepper("体重：\(Int(bodyweightKg)) kg", value: $bodyweightKg, in: 40...150, step: 1)
            }
            let total = squatKg + benchKg + deadliftKg
            let dots = PluginMath.dotsScore(bodyweightKg: bodyweightKg, totalKg: total, male: store.state.profile.sexMale)
            resultBanner(title: "DOTS 力量举得分", value: String(format: "%.1f 分", dots), tint: Palette.amber)
            kvRow("三大项合计", value: "\(Int(total)) kg")
            kvRow("参考评级", value: dots >= 420 ? "高水平竞赛级" : (dots >= 320 ? "进阶训练者" : "稳步提升中"))

        case .rpeConvert:
            inputCard {
                Stepper("RPE 强度：\(String(format: "%.1f", rpe))", value: $rpe, in: 6...10, step: 0.5)
                Stepper("目标次数：\(reps) 次", value: $reps, in: 1...12)
                Stepper("参考 1RM：\(Int(weightKg)) kg", value: $weightKg, in: 20...300, step: 2.5)
            }
            let pct = max(0.50, min(1.0, 1.0 - (10.0 - rpe + Double(reps - 1)) * 0.032))
            resultBanner(title: "建议工作重量", value: String(format: "%.1f kg (%.0f%% 1RM)", weightKg * pct, pct * 100), tint: Palette.purple)

        case .volumeInol:
            let week = store.weekSessions
            let totalVol = week.reduce(0.0) { $0 + $1.totalVolume }
            let totalSets = week.reduce(0) { $0 + $1.totalSets }
            let inol = Double(totalSets) * 0.14
            resultBanner(title: "本周 INOL 刺激指数", value: String(format: "%.2f", inol), tint: Palette.green)
            kvRow("本周总容量", value: "\(Int(totalVol)) kg")
            kvRow("本周完成组数", value: "\(totalSets) 组")
            kvRow("负荷评估", value: inol > 4.0 ? "高负荷 · 注意睡眠恢复" : (inol >= 1.5 ? "最佳增肌增长区间" : "偏低 · 可适当加量"))

        case .balance:
            inputCard {
                Stepper("深蹲：\(Int(squatKg)) kg", value: $squatKg, in: 20...300, step: 5)
                Stepper("卧推：\(Int(benchKg)) kg", value: $benchKg, in: 20...220, step: 2.5)
                Stepper("硬拉：\(Int(deadliftKg)) kg", value: $deadliftKg, in: 20...350, step: 5)
                Stepper("站姿推举：\(Int(ohpKg)) kg", value: $ohpKg, in: 15...150, step: 2.5)
            }
            let refBench = squatKg * 0.75
            let refDeadlift = squatKg * 1.2
            let refOHP = benchKg * 0.65
            kvRow("卧推 / 深蹲（标准 75%）", value: String(format: "%.0f%%", (benchKg / max(1, squatKg)) * 100))
            kvRow("硬拉 / 深蹲（标准 120%）", value: String(format: "%.0f%%", (deadliftKg / max(1, squatKg)) * 100))
            kvRow("推举 / 卧推（标准 65%）", value: String(format: "%.0f%%", (ohpKg / max(1, benchKg)) * 100))
            let weakest = benchKg < refBench ? "卧推" : (deadliftKg < refDeadlift ? "硬拉" : (ohpKg < refOHP ? "站姿推举" : "均衡"))
            resultBanner(title: "相对短板项目", value: weakest, tint: Palette.amber)

        case .racePredict:
            inputCard {
                Stepper("已知距离：\(String(format: "%.1f", distanceKm)) km", value: $distanceKm, in: 1...42.2, step: 0.5)
                Stepper("完成时间：\(Int(minutes)) 分钟", value: $minutes, in: 3...360, step: 1)
            }
            let knownM = distanceKm * 1000
            let knownS = minutes * 60
            let vdot = PluginMath.vdotEstimate(distanceMeters: knownM, seconds: knownS)
            resultBanner(title: "当前估算跑力 VDOT", value: String(format: "%.1f", vdot), tint: Palette.lime)
            kvRow("当前配速", value: PluginMath.formatPace(Int((knownS / max(0.5, distanceKm)).rounded())))
            kvRow("预测 5 公里", value: PluginMath.formatDuration(PluginMath.riegelPredict(knownMeters: knownM, knownSeconds: knownS, targetMeters: 5000)))
            kvRow("预测 10 公里", value: PluginMath.formatDuration(PluginMath.riegelPredict(knownMeters: knownM, knownSeconds: knownS, targetMeters: 10000)))
            kvRow("预测 半马", value: PluginMath.formatDuration(PluginMath.riegelPredict(knownMeters: knownM, knownSeconds: knownS, targetMeters: 21097)))
            kvRow("预测 全马", value: PluginMath.formatDuration(PluginMath.riegelPredict(knownMeters: knownM, knownSeconds: knownS, targetMeters: 42195)))

        case .vdotZones:
            inputCard {
                Stepper("5 公里最好成绩：\(Int(minutes)) 分钟", value: $minutes, in: 14...50, step: 1)
            }
            let zones = PluginMath.fivePaceZones(fiveKSeconds: minutes * 60)
            ForEach(zones, id: \.zone) { z in
                kvRow("\(z.zone) 档 · \(z.title)", value: PluginMath.formatPace(z.secPerKm))
            }

        case .raceSplits:
            inputCard {
                Stepper("比赛距离：\(String(format: "%.1f", distanceKm)) km", value: $distanceKm, in: 3...42.2, step: 1)
                Stepper("目标完赛：\(Int(minutes)) 分钟", value: $minutes, in: 12...360, step: 2)
            }
            let paceSec = Int((minutes * 60 / max(1, distanceKm)).rounded())
            resultBanner(title: "目标均配速", value: PluginMath.formatPace(paceSec), tint: Palette.lime)
            ForEach([1, 3, 5, 10, 15, 21, 30, 42].filter { Double($0) <= distanceKm + 0.5 }, id: \.self) { km in
                kvRow("第 \(km) 公里节点", value: PluginMath.formatDuration(Double(km * paceSec)))
            }

        case .gapPace, .treadmill:
            inputCard {
                Stepper("配速（分/km）：\(String(format: "%.1f", minutes))", value: $minutes, in: 3.0...9.0, step: 0.1)
                Stepper("坡度：\(String(format: "%.1f", gradePct))%", value: $gradePct, in: -5...15, step: 0.5)
            }
            let rawSec = minutes * 60
            // 每上升 1% 坡度平地等效配速快约 12-15 秒
            let flatSec = Int(max(160, rawSec - gradePct * 13.5).rounded())
            resultBanner(title: "平地等效配速 (GAP)", value: PluginMath.formatPace(flatSec), tint: Palette.lime)

        case .hrZones:
            inputCard {
                Stepper("最大心率：\(Int(maxHR)) bpm", value: $maxHR, in: 150...220)
                Stepper("静息心率：\(Int(restingHR)) bpm", value: $restingHR, in: 35...100)
            }
            let hrr = max(40, maxHR - restingHR)
            kvRow("Z1 恢复区 (50–60%)", value: "\(Int(restingHR + hrr * 0.5))–\(Int(restingHR + hrr * 0.6)) bpm")
            kvRow("Z2 有氧燃脂 (60–70%)", value: "\(Int(restingHR + hrr * 0.6))–\(Int(restingHR + hrr * 0.7)) bpm")
            kvRow("Z3 节奏耐力 (70–80%)", value: "\(Int(restingHR + hrr * 0.7))–\(Int(restingHR + hrr * 0.8)) bpm")
            kvRow("Z4 乳酸阈值 (80–90%)", value: "\(Int(restingHR + hrr * 0.8))–\(Int(restingHR + hrr * 0.9)) bpm")
            kvRow("Z5 最大摄氧 (90–100%)", value: "\(Int(restingHR + hrr * 0.9))–\(Int(maxHR)) bpm")

        case .vo2max:
            inputCard {
                Stepper("12 分钟全力跑距离：\(String(format: "%.2f", distanceKm)) km", value: $distanceKm, in: 1.2...4.2, step: 0.05)
            }
            let cooper = max(20, (distanceKm * 1000 - 504.9) / 44.73)
            resultBanner(title: "Cooper 估算 VO₂max", value: String(format: "%.1f ml/kg·min", cooper), tint: Palette.coralHi)

        case .acwrLoad:
            let cal = Calendar.current
            let now = Date()
            let d7 = cal.date(byAdding: .day, value: -7, to: now) ?? now
            let d28 = cal.date(byAdding: .day, value: -28, to: now) ?? now
            let acute = Double(store.state.sessions.filter { $0.date >= d7 }.reduce(0) { $0 + $1.durationSec / 60 }) / 7.0
            let chronic = max(1, Double(store.state.sessions.filter { $0.date >= d28 }.reduce(0) { $0 + $1.durationSec / 60 }) / 28.0)
            let ratio = acute / chronic
            resultBanner(title: "急慢性负荷比 (ACWR)", value: String(format: "%.2f", ratio), tint: ratio > 1.35 ? Palette.amber : Palette.green)
            kvRow("近 7 天日均训练", value: String(format: "%.0f 分钟", acute))
            kvRow("近 28 天日均基线", value: String(format: "%.0f 分钟", chronic))
            kvRow("安全区间判断", value: ratio > 1.5 ? "过载预警 · 建议减量" : (ratio >= 0.8 ? "0.8–1.3 甜区" : "负荷偏低"))

        case .bodyFat:
            inputCard {
                Stepper("腰围：\(Int(waistCm)) cm", value: $waistCm, in: 55...130)
                Stepper("颈围：\(Int(neckCm)) cm", value: $neckCm, in: 28...55)
                if !store.state.profile.sexMale {
                    Stepper("臀围：\(Int(hipCm)) cm", value: $hipCm, in: 70...140)
                }
            }
            let bf = PluginMath.navyBodyFat(
                male: store.state.profile.sexMale,
                heightCm: store.state.profile.heightCm,
                waistCm: waistCm,
                neckCm: neckCm,
                hipCm: hipCm
            )
            resultBanner(title: "海军围度法估算体脂率", value: String(format: "%.1f%%", bf), tint: Palette.amber)

        case .tdeeCompare:
            let p = store.state.profile
            let mifflin = p.bmr
            let harris = p.sexMale
                ? 66.5 + 13.75 * p.weightKg + 5.003 * p.heightCm - 6.75 * Double(p.age)
                : 655.1 + 9.563 * p.weightKg + 1.85 * p.heightCm - 4.676 * Double(p.age)
            let katch = 370 + 21.6 * (p.weightKg * 0.82)
            resultBanner(title: "日均总消耗 (TDEE)", value: "\(Int(p.tdee)) kcal", tint: Palette.green)
            kvRow("Mifflin-St Jeor (BMR)", value: "\(Int(mifflin)) kcal")
            kvRow("Harris-Benedict (BMR)", value: "\(Int(harris)) kcal")
            kvRow("Katch-McArdle (LBM 估算)", value: "\(Int(katch)) kcal")

        case .bodyMetrics:
            let p = store.state.profile
            let hM = max(1.0, p.heightCm / 100.0)
            let bmi = p.weightKg / (hM * hM)
            let whr = waistCm / max(1, hipCm)
            let whtr = waistCm / max(100, p.heightCm)
            let ffmi = (p.weightKg * 0.82) / (hM * hM)
            inputCard {
                Stepper("腰围：\(Int(waistCm)) cm", value: $waistCm, in: 55...130)
                Stepper("臀围：\(Int(hipCm)) cm", value: $hipCm, in: 70...140)
            }
            kvRow("BMI", value: String(format: "%.1f", bmi))
            kvRow("腰臀比 (WHR)", value: String(format: "%.2f", whr))
            kvRow("腰高比 (WHtR)", value: String(format: "%.2f", whtr))
            kvRow("去脂体重指数 (FFMI)", value: String(format: "%.1f", ffmi))

        case .goalWeight:
            let cur = store.state.profile.weightKg
            let diff = cur - bodyweightKg
            let days = Int(abs(diff) * 7700.0 / 500.0)
            inputCard {
                Stepper("目标体重：\(String(format: "%.1f", bodyweightKg)) kg", value: $bodyweightKg, in: 35...150, step: 0.5)
            }
            resultBanner(title: "按每日 500 kcal 缺口预计", value: "\(max(1, days)) 天达成", tint: Palette.green)
            kvRow("当前体重", value: String(format: "%.1f kg", cur))
            kvRow("每日建议摄入", value: "\(max(1200, Int(store.state.profile.tdee) - 500)) kcal")

        case .ftpZones:
            inputCard {
                Stepper("骑行 FTP：\(Int(ftpWatts)) W", value: $ftpWatts, in: 100...450, step: 5)
            }
            resultBanner(title: "功体比", value: String(format: "%.2f W/kg", ftpWatts / max(40, bodyweightKg)), tint: Palette.blue)
            kvRow("Z1 积极恢复 (<55%)", value: "<\(Int(ftpWatts * 0.55)) W")
            kvRow("Z2 耐力基石 (56–75%)", value: "\(Int(ftpWatts * 0.56))–\(Int(ftpWatts * 0.75)) W")
            kvRow("Z3 节奏区 (76–90%)", value: "\(Int(ftpWatts * 0.76))–\(Int(ftpWatts * 0.90)) W")
            kvRow("Z4 乳酸阈值 (91–105%)", value: "\(Int(ftpWatts * 0.91))–\(Int(ftpWatts * 1.05)) W")
            kvRow("Z5 最大摄氧 (106–120%)", value: "\(Int(ftpWatts * 1.06))–\(Int(ftpWatts * 1.20)) W")
            kvRow("Z6 无氧容量 (121–150%)", value: "\(Int(ftpWatts * 1.21))–\(Int(ftpWatts * 1.50)) W")

        case .swimCSS:
            inputCard {
                Stepper("400 米时间：\(Int(css400Sec)) 秒", value: $css400Sec, in: 240...720, step: 5)
                Stepper("200 米时间：\(Int(css200Sec)) 秒", value: $css200Sec, in: 100...380, step: 5)
            }
            let cssPace100 = max(60, (css400Sec - css200Sec) / 2.0)
            resultBanner(title: "临界游泳速度 CSS / 100m", value: PluginMath.formatDuration(cssPace100), tint: Palette.cyan)

        case .sweatRate:
            inputCard {
                Stepper("跑前跑后减重：\(String(format: "%.1f", sweatLostKg)) kg", value: $sweatLostKg, in: 0.2...3.5, step: 0.1)
                Stepper("途中饮水：\(String(format: "%.1f", drinkLiters)) L", value: $drinkLiters, in: 0...2.0, step: 0.1)
                Stepper("运动时长：\(Int(minutes)) 分钟", value: $minutes, in: 20...180, step: 5)
            }
            let mlPerHour = Int(((sweatLostKg + drinkLiters) * 1000.0 / max(0.3, minutes / 60.0)).rounded())
            resultBanner(title: "每小时建议补水", value: "\(mlPerHour) ml / h", tint: Palette.blue)

        case .heatPace:
            inputCard {
                Stepper("气温：\(Int(tempC)) ℃", value: $tempC, in: 15...40)
                Stepper("湿度：\(Int(humidityPct))%", value: $humidityPct, in: 20...100, step: 5)
            }
            let penaltyPct = max(0.0, (tempC - 16.0) * 0.45 + max(0, humidityPct - 55) * 0.08)
            resultBanner(title: "高温降速建议", value: String(format: "放慢 %.1f%%", penaltyPct), tint: Palette.amber)
            kvRow("例：平时 5′00″/km → 今日建议", value: PluginMath.formatPace(Int(300 * (1 + penaltyPct / 100.0))))

        case .altitudePace:
            inputCard {
                Stepper("海拔高度：\(Int(altitudeM)) 米", value: $altitudeM, in: 500...4500, step: 100)
            }
            let altPenalty = max(0.0, (altitudeM - 1000.0) / 300.0 * 1.6)
            resultBanner(title: "高原配速补偿", value: String(format: "放慢 %.1f%%", altPenalty), tint: Palette.purple)

        case .readiness:
            inputCard {
                Stepper("今晨 HRV：\(Int(hrvMs)) ms", value: $hrvMs, in: 15...140)
                Stepper("今晨静息心率：\(Int(restingHR)) bpm", value: $restingHR, in: 35...100)
            }
            let score = min(100, max(10, Int((hrvMs * 1.15 - (restingHR - 52) * 1.4).rounded())))
            resultBanner(title: "晨间就绪度评分", value: "\(score) / 100", tint: score >= 75 ? Palette.green : Palette.amber)
            kvRow("今日训练建议", value: score >= 75 ? "适合冲重量 / 间歇跑" : (score >= 55 ? "稳态中等负荷" : "降量 30% 或轻松恢复"))

        case .sleepCycle:
            inputCard {
                Stepper("入睡时间：\(sleepNowHour):00", value: $sleepNowHour, in: 19...24)
            }
            resultBanner(title: "黄金醒来时间点（90 分钟周期）", value: "4~6 周期", tint: Palette.purple)
            ForEach([4, 5, 6], id: \.self) { cycles in
                let totalMin = cycles * 90 + 15
                let wakeH = (sleepNowHour + totalMin / 60) % 24
                let wakeM = totalMin % 60
                kvRow("\(cycles) 个周期（\(String(format: "%.1f", Double(cycles) * 1.5)) 小时）", value: String(format: "%02d:%02d", wakeH, wakeM))
            }

        default:
            // 其余马拉松与耐力高阶工具提供结构化专业评估卡与动态换算
            specializedRunningCard
        }
    }

    @ViewBuilder
    private var specializedRunningCard: some View {
        switch kind {
        case .ageGrade:
            inputCard {
                Stepper("年龄：\(age) 岁", value: $age, in: 18...80)
                Stepper("5 公里成绩：\(Int(minutes)) 分钟", value: $minutes, in: 14...50)
            }
            let factor = max(0.65, 1.0 - max(0.0, Double(age - 30)) * 0.0065)
            resultBanner(title: "等效巅峰年龄成绩", value: PluginMath.formatDuration(minutes * 60 * factor), tint: Palette.lime)

        case .aerobicDrift:
            let driftPct = 4.2
            resultBanner(title: "有氧解耦参考", value: String(format: "%.1f%%（<5%% 合格）", driftPct), tint: Palette.green)
            kvRow("判定标准", value: "前半程与后半程 配速/心率 比值波动 <5% 代表有氧底座稳固")

        case .rampRate:
            let runs = store.state.runs
            let totalKm = runs.reduce(0.0) { $0 + $1.distanceM / 1000.0 }
            resultBanner(title: "累计跑量参考", value: String(format: "%.1f km", totalKm), tint: Palette.lime)
            kvRow("10% 安全法则", value: "每周总跑量增幅不超过上周 10% 可大幅降低髂胫束与跟腱风险")

        case .raceFuel:
            inputCard {
                Stepper("预计完赛时间：\(Int(minutes)) 分钟", value: $minutes, in: 60...360, step: 10)
            }
            let gels = max(1, Int((minutes / 35.0).rounded()))
            resultBanner(title: "全程建议能量胶", value: "\(gels) 支（约 \(gels * 25) g 碳水）", tint: Palette.amber)
            kvRow("补水频率", value: "每 5 km 补水 150–200 ml，每小时补钠 300–500 mg")

        case .criticalSpeed:
            inputCard {
                Stepper("3 公里全力：\(Int(minutes)) 分钟", value: $minutes, in: 9...25)
            }
            let csPace = Int((minutes * 60 / 3.0 * 1.07).rounded())
            resultBanner(title: "临界速度 (CS) 配速", value: PluginMath.formatPace(csPace), tint: Palette.lime)

        case .polarized8020:
            resultBanner(title: "80/20 极化分布模型", value: "80% 低强度 · 20% 高强度", tint: Palette.blue)
            kvRow("Z1–Z2 轻松跑占比", value: "80%（避免落入无意义的 Z3 灰区疲劳）")
            kvRow("Z4–Z5 间歇/阈值占比", value: "20%（集中刺激跑力天花板）")

        case .thresholdTest:
            inputCard {
                Stepper("30 分钟全力平均心率：\(Int(maxHR * 0.88)) bpm", value: $maxHR, in: 150...210)
                Stepper("30 分钟跑动距离：\(String(format: "%.1f", distanceKm)) km", value: $distanceKm, in: 3...10, step: 0.2)
            }
            resultBanner(title: "估算乳酸阈值配速", value: PluginMath.formatPace(Int((1800 / max(1, distanceKm)).rounded())), tint: Palette.coralHi)

        case .marathonWall:
            inputCard {
                Stepper("体重：\(Int(bodyweightKg)) kg", value: $bodyweightKg, in: 45...120)
                Stepper("半马均配速：\(String(format: "%.1f", minutes / 4)) 分/km", value: $minutes, in: 16...36)
            }
            let wallKm = min(42, Int((28.0 + (store.state.runs.count > 4 ? 5 : 0)).rounded()))
            resultBanner(title: "糖原临界撞墙预警点", value: "第 \(wallKm) 公里", tint: Palette.amber)
            kvRow("防撞墙策略", value: "赛前 48h 碳水加载 + 第 10/20/30 km 及时补胶")

        case .aerobicEfficiency, .vdotTrend, .fitnessForm:
            let latestRun = store.state.runs.first
            let pace = latestRun.map { $0.paceSecPerKm > 0 ? PluginMath.formatPace($0.paceSecPerKm) : "5′20″/km" } ?? "5′20″/km"
            resultBanner(title: "有氧效率 & 跑力参考", value: pace, tint: Palette.green)
            kvRow("最近一跑", value: latestRun?.title ?? "待记录")
            kvRow("体能/疲劳建议", value: "保持 7 天负荷稳定在 28 天基线的 0.9–1.2 倍区间")

        case .carbLoad:
            let gPerDay = Int((bodyweightKg * 8.5).rounded())
            resultBanner(title: "赛前 48 小时每日碳水", value: "\(gPerDay) g / 天", tint: Palette.amber)
            kvRow("分配建议", value: "早 \(Int(Double(gPerDay)*0.3))g · 午 \(Int(Double(gPerDay)*0.35))g · 晚 \(Int(Double(gPerDay)*0.25))g · 加餐 \(Int(Double(gPerDay)*0.1))g")

        case .taperPlan:
            resultBanner(title: "赛前两周减量曲线", value: "-30% → -55%", tint: Palette.blue)
            kvRow("赛前第 2 周", value: "跑量降到峰值 70%，保留 1 次短间歇维持神经兴奋")
            kvRow("比赛周", value: "跑量降至 45%，赛前 2 天仅做 15 分钟慢跑+拉伸")

        case .raceDayChecklist:
            kvRow("赛前 3 小时", value: "起床吃熟悉的高碳低脂早餐（约 100g 碳水）")
            kvRow("赛前 45 分钟", value: "动态拉伸 + 小口补水 150 ml")
            kvRow("起跑前 15 分钟", value: "吃第 1 支能量胶，控制前半程配速别冲太快")

        case .keyWorkouts:
            kvRow("周二 · 间歇课", value: "800m × 5 @ I 配速（组休 2 分钟）")
            kvRow("周四 · 节奏跑", value: "20 分钟 @ T 乳酸阈值配速")
            kvRow("周日 · LSD", value: "75–100 分钟 @ E 轻松有氧区")

        case .trackLaps:
            inputCard {
                Stepper("目标 400m 单圈秒数：\(Int(minutes * 4)) 秒", value: $minutes, in: 15...45)
            }
            let lap = Int(minutes * 4)
            resultBanner(title: "标准 1 道每圈配速", value: "\(lap) 秒 / 400m", tint: Palette.lime)
            kvRow("每 200 米通过", value: "\(lap / 2) 秒")
            kvRow("第 4 道每圈需快", value: "外道多约 22.6 米，均速约 \(lap + 4) 秒")

        case .athleteGrade:
            inputCard {
                Stepper("5 公里成绩：\(Int(minutes)) 分钟", value: $minutes, in: 13...40)
            }
            let grade = minutes <= 14.5 ? "国家级健将" : (minutes <= 16.5 ? "国家二级运动员" : (minutes <= 20.0 ? "精英业余跑者" : "大众进阶跑者"))
            resultBanner(title: "田径等级参考", value: grade, tint: Palette.yellow)

        case .strideLab, .runPower:
            inputCard {
                Stepper("步频：\(Int(maxHR)) spm", value: $maxHR, in: 150...205)
                Stepper("配速（分/km）：\(String(format: "%.1f", minutes / 4))", value: $minutes, in: 12...36)
            }
            let paceMin = minutes / 4.0
            let speedMPerMin = 1000.0 / max(2.5, paceMin)
            let strideLen = speedMPerMin / max(120, maxHR)
            let watts = Int((bodyweightKg * (speedMPerMin / 60.0) * 1.04).rounded())
            resultBanner(title: "估算步幅 / 跑步功率", value: String(format: "%.2f 米 · %d W", strideLen, watts), tint: Palette.lime)
        default:
            EmptyHint(icon: "checkmark.seal", title: "本机计算就绪", message: "参数配置完成")
        }
    }

    private func levelLabel(_ ratio: Double, thresholds: [Double]) -> String {
        if ratio >= thresholds[3] { return "精英" }
        if ratio >= thresholds[2] { return "高阶" }
        if ratio >= thresholds[1] { return "进阶" }
        if ratio >= thresholds[0] { return "入门" }
        return "起步"
    }

    private func inputCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .font(.system(size: 14))
        .foregroundStyle(Palette.text)
        .padding(14)
        .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
    }

    private func resultBanner(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.textDim)
            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .card(radius: 20, fill: Palette.card, stroke: tint.opacity(0.35))
    }

    private func kvRow(_ key: String, value: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(Palette.textDim)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.text)
        }
        .padding(13)
        .card(radius: 14, fill: Palette.card, stroke: Palette.stroke)
    }
}
