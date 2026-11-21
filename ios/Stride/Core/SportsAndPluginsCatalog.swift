import Foundation

// MARK: - 45 项全品类运动目录（对应「主页 -> 跑步 -> 主页」图 7–15）

enum SportCategory: String, CaseIterable, Identifiable {
    case featuredRun = "核心跑步"
    case outdoor = "户外"
    case indoorCardio = "室内有氧"
    case ballSports = "球类"
    case combat = "格斗"
    case mindBody = "身心"

    var id: String { rawValue }

    var headerIcon: String {
        switch self {
        case .featuredRun: return "figure.run"
        case .outdoor: return "mountain.2.fill"
        case .indoorCardio: return "figure.indoor.cycle"
        case .ballSports: return "sportscourt.fill"
        case .combat: return "figure.boxing"
        case .mindBody: return "figure.mind.and.body"
        }
    }
}

struct SportPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let category: SportCategory
    let icon: String
    let met: Double
    let usesGPS: Bool
    let defaultMinutes: Int
}

enum SportsCatalog {

    static let all: [SportPreset] = [
        // 核心跑步 5
        SportPreset(id: "run.target", name: "目标跑", category: .featuredRun, icon: "figure.run", met: 9.8, usesGPS: true, defaultMinutes: 35),
        SportPreset(id: "run.free", name: "随心跑", category: .featuredRun, icon: "figure.run.circle", met: 9.5, usesGPS: true, defaultMinutes: 30),
        SportPreset(id: "run.interval", name: "间歇跑", category: .featuredRun, icon: "figure.run.square.stack", met: 11.2, usesGPS: true, defaultMinutes: 28),
        SportPreset(id: "run.treadmill", name: "跑步机", category: .featuredRun, icon: "figure.walk.treadmill", met: 9.0, usesGPS: false, defaultMinutes: 30),
        SportPreset(id: "run.incline", name: "爬坡机", category: .featuredRun, icon: "figure.step.training", met: 8.5, usesGPS: false, defaultMinutes: 25),

        // 户外 11
        SportPreset(id: "out.walk", name: "健走", category: .outdoor, icon: "figure.walk", met: 4.3, usesGPS: true, defaultMinutes: 40),
        SportPreset(id: "out.cycle", name: "骑行", category: .outdoor, icon: "figure.outdoor.cycle", met: 8.0, usesGPS: true, defaultMinutes: 45),
        SportPreset(id: "out.hike", name: "徒步", category: .outdoor, icon: "figure.hiking", met: 6.5, usesGPS: true, defaultMinutes: 90),
        SportPreset(id: "out.swim", name: "游泳", category: .outdoor, icon: "figure.pool.swim", met: 8.3, usesGPS: false, defaultMinutes: 40),
        SportPreset(id: "out.climb", name: "攀岩", category: .outdoor, icon: "figure.climbing", met: 7.5, usesGPS: false, defaultMinutes: 60),
        SportPreset(id: "out.skate", name: "滑冰", category: .outdoor, icon: "figure.skating", met: 7.0, usesGPS: true, defaultMinutes: 45),
        SportPreset(id: "out.ski", name: "双板滑雪", category: .outdoor, icon: "figure.skiing.downhill", met: 6.8, usesGPS: true, defaultMinutes: 60),
        SportPreset(id: "out.snowboard", name: "单板滑雪", category: .outdoor, icon: "figure.snowboarding", met: 6.8, usesGPS: true, defaultMinutes: 60),
        SportPreset(id: "out.xcski", name: "越野滑雪", category: .outdoor, icon: "figure.skiing.crosscountry", met: 9.0, usesGPS: true, defaultMinutes: 50),
        SportPreset(id: "out.paddle", name: "桨板 / 皮划艇", category: .outdoor, icon: "figure.rowing", met: 5.8, usesGPS: true, defaultMinutes: 45),
        SportPreset(id: "out.surf", name: "冲浪", category: .outdoor, icon: "figure.surfing", met: 5.5, usesGPS: false, defaultMinutes: 50),

        // 室内有氧 10
        SportPreset(id: "in.cycle", name: "室内单车", category: .indoorCardio, icon: "figure.indoor.cycle", met: 8.5, usesGPS: false, defaultMinutes: 40),
        SportPreset(id: "in.elliptical", name: "椭圆机", category: .indoorCardio, icon: "figure.elliptical", met: 6.5, usesGPS: false, defaultMinutes: 35),
        SportPreset(id: "in.rower", name: "划船机", category: .indoorCardio, icon: "figure.rower", met: 8.5, usesGPS: false, defaultMinutes: 30),
        SportPreset(id: "in.stairStepper", name: "爬楼机", category: .indoorCardio, icon: "figure.stair.stepper", met: 8.8, usesGPS: false, defaultMinutes: 25),
        SportPreset(id: "in.stairs", name: "爬楼梯", category: .indoorCardio, icon: "figure.stairs", met: 8.0, usesGPS: false, defaultMinutes: 20),
        SportPreset(id: "in.hiit", name: "HIIT", category: .indoorCardio, icon: "figure.highintensity.intervaltraining", met: 10.0, usesGPS: false, defaultMinutes: 22),
        SportPreset(id: "in.mixed", name: "混合有氧", category: .indoorCardio, icon: "figure.mixed.cardio", met: 7.5, usesGPS: false, defaultMinutes: 35),
        SportPreset(id: "in.cross", name: "交叉训练", category: .indoorCardio, icon: "figure.cross.training", met: 8.0, usesGPS: false, defaultMinutes: 40),
        SportPreset(id: "in.aerobics", name: "健身操", category: .indoorCardio, icon: "figure.cooldown", met: 6.5, usesGPS: false, defaultMinutes: 30),
        SportPreset(id: "in.dance", name: "舞蹈", category: .indoorCardio, icon: "figure.dance", met: 6.0, usesGPS: false, defaultMinutes: 40),

        // 球类 13
        SportPreset(id: "ball.basketball", name: "篮球", category: .ballSports, icon: "figure.basketball", met: 8.0, usesGPS: false, defaultMinutes: 60),
        SportPreset(id: "ball.soccer", name: "足球", category: .ballSports, icon: "figure.soccer", met: 9.0, usesGPS: true, defaultMinutes: 60),
        SportPreset(id: "ball.badminton", name: "羽毛球", category: .ballSports, icon: "figure.badminton", met: 7.0, usesGPS: false, defaultMinutes: 60),
        SportPreset(id: "ball.tennis", name: "网球", category: .ballSports, icon: "figure.tennis", met: 7.3, usesGPS: false, defaultMinutes: 60),
        SportPreset(id: "ball.tabletennis", name: "乒乓球", category: .ballSports, icon: "figure.table.tennis", met: 4.8, usesGPS: false, defaultMinutes: 45),
        SportPreset(id: "ball.volleyball", name: "排球", category: .ballSports, icon: "figure.volleyball", met: 6.0, usesGPS: false, defaultMinutes: 50),
        SportPreset(id: "ball.baseball", name: "棒球 / 垒球", category: .ballSports, icon: "figure.baseball", met: 5.0, usesGPS: false, defaultMinutes: 60),
        SportPreset(id: "ball.rugby", name: "橄榄球", category: .ballSports, icon: "figure.american.football", met: 8.5, usesGPS: true, defaultMinutes: 60),
        SportPreset(id: "ball.golf", name: "高尔夫", category: .ballSports, icon: "figure.golf", met: 4.3, usesGPS: true, defaultMinutes: 120),
        SportPreset(id: "ball.pickleball", name: "匹克球", category: .ballSports, icon: "figure.pickleball", met: 6.5, usesGPS: false, defaultMinutes: 45),
        SportPreset(id: "ball.squash", name: "壁球", category: .ballSports, icon: "figure.squash", met: 9.5, usesGPS: false, defaultMinutes: 45),
        SportPreset(id: "ball.handball", name: "手球", category: .ballSports, icon: "figure.handball", met: 8.0, usesGPS: false, defaultMinutes: 50),
        SportPreset(id: "ball.hockey", name: "曲棍球", category: .ballSports, icon: "figure.hockey", met: 8.0, usesGPS: false, defaultMinutes: 50),

        // 格斗 3
        SportPreset(id: "combat.boxing", name: "拳击", category: .combat, icon: "figure.boxing", met: 9.2, usesGPS: false, defaultMinutes: 45),
        SportPreset(id: "combat.martial", name: "跆拳道 / 武术", category: .combat, icon: "figure.martial.arts", met: 8.5, usesGPS: false, defaultMinutes: 50),
        SportPreset(id: "combat.kickbox", name: "搏击操", category: .combat, icon: "figure.kickboxing", met: 8.2, usesGPS: false, defaultMinutes: 40),

        // 身心 3
        SportPreset(id: "mind.pilates", name: "普拉提", category: .mindBody, icon: "figure.pilates", met: 3.8, usesGPS: false, defaultMinutes: 45),
        SportPreset(id: "mind.taichi", name: "太极", category: .mindBody, icon: "figure.taichi", met: 3.5, usesGPS: false, defaultMinutes: 40),
        SportPreset(id: "mind.stretch", name: "拉伸", category: .mindBody, icon: "figure.flexibility", met: 2.5, usesGPS: false, defaultMinutes: 20)
    ]

    static func items(in category: SportCategory) -> [SportPreset] {
        all.filter { $0.category == category }
    }
}

// MARK: - 62 款本机计算插件目录与工具引擎（对应图 20–33）

enum PluginBadgeKind: String {
    case magic
    case media
    case none
}

enum PluginCollectionKind: String {
    case runningPack
    case strengthPack
    case lifestyle
}

enum PluginInteractionKind {
    case runWatermark
    case glassWatermark
    case deviceFrame
    case musicShortcut
    case podcastPlayer
    case sleepAudio
    case stretchTimer
    case breatheGuide
    case hrrTest
    case intervalTimer
    case cadenceMetronome
    case shoeMileage
    case posturePolaroid
    case linearProgression
    case macrosPlanner
    case calculator(CalculatorToolKind)
}

enum CalculatorToolKind: String {
    case goalWeight, ftpZones, swimCSS, plates, oneRM, strengthLevel, dotsScore, warmUp
    case rpeConvert, volumeInol, balance, racePredict, vdotZones, raceSplits, gapPace
    case hrZones, vo2max, acwrLoad, ageGrade, bodyFat, tdeeCompare, bodyMetrics
    case sweatRate, treadmill, aerobicDrift, rampRate, raceFuel, heatPace
    case criticalSpeed, polarized8020, thresholdTest, marathonWall, aerobicEfficiency
    case vdotTrend, fitnessForm, carbLoad, taperPlan, raceDayChecklist, keyWorkouts
    case altitudePace, trackLaps, athleteGrade, strideLab, runPower, readiness, sleepCycle
}

struct StridePluginItem: Identifiable {
    let id: String
    let posterWords: [String]
    let title: String
    let summary: String
    let badge: PluginBadgeKind
    let collection: PluginCollectionKind
    let interaction: PluginInteractionKind
}

enum PluginsCatalog {

    static let all: [StridePluginItem] = [
        // 图 20
        StridePluginItem(id: "run_mark", posterWords: ["RUN MARK"], title: "跑步水印", summary: "给自己的照片压上距离、配速、时间和路线", badge: .magic, collection: .lifestyle, interaction: .runWatermark),
        StridePluginItem(id: "glass", posterWords: ["GLASS"], title: "玻璃水印", summary: "照片或海报，压一块液态玻璃 + 训练数据", badge: .magic, collection: .lifestyle, interaction: .glassWatermark),
        StridePluginItem(id: "frame", posterWords: ["FRAME"], title: "带壳截图", summary: "截图套上 iPhone 外壳，出一张干净的样机图", badge: .none, collection: .lifestyle, interaction: .deviceFrame),
        StridePluginItem(id: "music", posterWords: ["MUSIC"], title: "运动音乐", summary: "歌单导入 · LRC 歌词同步 · 本地节奏", badge: .media, collection: .lifestyle, interaction: .musicShortcut),
        // 图 22
        StridePluginItem(id: "podcast", posterWords: ["PODCAST"], title: "播客", summary: "跑步与力量科普音频，练的时候听点干货", badge: .media, collection: .lifestyle, interaction: .podcastPlayer),
        StridePluginItem(id: "night", posterWords: ["NIGHT"], title: "辅助睡眠", summary: "白噪音 · 雨声 · 冥想，定时自动停", badge: .none, collection: .lifestyle, interaction: .sleepAudio),
        StridePluginItem(id: "pace", posterWords: ["PACE"], title: "配速计算器", summary: "距离、时间、配速，知道两个算第三个", badge: .magic, collection: .runningPack, interaction: .calculator(.racePredict)),
        StridePluginItem(id: "stretch", posterWords: ["STRETCH"], title: "拉伸跟练", summary: "跑后、练后、久坐，三套定时拉伸自动换动作", badge: .none, collection: .lifestyle, interaction: .stretchTimer),
        StridePluginItem(id: "breathe", posterWords: ["BREATHE"], title: "呼吸训练", summary: "方块呼吸 · 4-7-8 · 共振呼吸，跟着呼吸球练", badge: .none, collection: .lifestyle, interaction: .breatheGuide),
        StridePluginItem(id: "hrr", posterWords: ["HRR"], title: "心率恢复测试", summary: "停下后 1 分钟心率掉多少，看心肺恢复能力", badge: .none, collection: .runningPack, interaction: .hrrTest),
        // 图 23
        StridePluginItem(id: "goal", posterWords: ["GOAL"], title: "减脂目标", summary: "目标体重哪天到，每天该吃多少", badge: .magic, collection: .lifestyle, interaction: .calculator(.goalWeight)),
        StridePluginItem(id: "ftp", posterWords: ["FTP"], title: "骑行功率区间", summary: "测出 FTP，七个功率区间和 W/kg 一次给全", badge: .magic, collection: .lifestyle, interaction: .calculator(.ftpZones)),
        StridePluginItem(id: "swim_css", posterWords: ["SWIM", "CSS"], title: "游泳 CSS 配速", summary: "400 米和 200 米测一次，算出每档训练配速", badge: .none, collection: .lifestyle, interaction: .calculator(.swimCSS)),
        StridePluginItem(id: "plates", posterWords: ["PLATES"], title: "杠铃配片器", summary: "目标重量每边挂哪几片，一眼就知道", badge: .magic, collection: .strengthPack, interaction: .calculator(.plates)),
        // 图 24
        StridePluginItem(id: "1rm", posterWords: ["1RM"], title: "1RM 计算器", summary: "七种公式一起算，附各百分比配重表", badge: .magic, collection: .strengthPack, interaction: .calculator(.oneRM)),
        StridePluginItem(id: "level", posterWords: ["LEVEL"], title: "力量水平", summary: "按体重换算，看你在训练人群里的位置", badge: .magic, collection: .strengthPack, interaction: .calculator(.strengthLevel)),
        StridePluginItem(id: "dots", posterWords: ["DOTS"], title: "举重分数", summary: "Wilks / DOTS / IPF GL，跨体重级比高低", badge: .magic, collection: .strengthPack, interaction: .calculator(.dotsScore)),
        StridePluginItem(id: "warm_up", posterWords: ["WARM UP"], title: "热身梯度", summary: "从空杆到工作重量，每组配片都算好", badge: .magic, collection: .strengthPack, interaction: .calculator(.warmUp)),
        // 图 25
        StridePluginItem(id: "rpe", posterWords: ["RPE"], title: "RPE 换算", summary: "RPE 与 %1RM 互查，比纯次数公式准", badge: .magic, collection: .strengthPack, interaction: .calculator(.rpeConvert)),
        StridePluginItem(id: "volume", posterWords: ["VOLUME"], title: "容量强度", summary: "容量 / 相对强度 / INOL / 单调性，全自动", badge: .magic, collection: .strengthPack, interaction: .calculator(.volumeInol)),
        StridePluginItem(id: "balance", posterWords: ["BALANCE"], title: "力量平衡", summary: "四大项比例对照，找出拖后腿的那项", badge: .magic, collection: .strengthPack, interaction: .calculator(.balance)),
        StridePluginItem(id: "race", posterWords: ["RACE"], title: "成绩换算", summary: "一个成绩推全距离，Riegel 与 VDOT 并排", badge: .magic, collection: .runningPack, interaction: .calculator(.racePredict)),
        StridePluginItem(id: "vdot", posterWords: ["VDOT"], title: "训练配速", summary: "E / M / T / I / R 五档配速，按你的成绩定", badge: .magic, collection: .runningPack, interaction: .calculator(.vdotZones)),
        StridePluginItem(id: "splits", posterWords: ["SPLITS"], title: "分段配速表", summary: "目标完赛时间 → 逐公里该跑多快", badge: .magic, collection: .runningPack, interaction: .calculator(.raceSplits)),
        // 图 26
        StridePluginItem(id: "gap", posterWords: ["GAP"], title: "坡度校正配速", summary: "把爬坡跑换算成平地等效配速", badge: .magic, collection: .runningPack, interaction: .calculator(.gapPace)),
        StridePluginItem(id: "zones", posterWords: ["ZONES"], title: "心率区间", summary: "四种最大心率公式 + 储备心率法", badge: .magic, collection: .runningPack, interaction: .calculator(.hrZones)),
        StridePluginItem(id: "vo2max", posterWords: ["VO2MAX"], title: "VO₂max 估算", summary: "Cooper 12 分钟测试，或从跑步记录反推", badge: .magic, collection: .runningPack, interaction: .calculator(.vo2max)),
        StridePluginItem(id: "load", posterWords: ["LOAD"], title: "训练负荷", summary: "急慢性负荷比 ACWR，标出伤病风险区", badge: .magic, collection: .strengthPack, interaction: .calculator(.acwrLoad)),
        // 图 27
        StridePluginItem(id: "age", posterWords: ["AGE"], title: "年龄成绩换算", summary: "你的成绩相当于巅峰年龄跑出多少", badge: .magic, collection: .runningPack, interaction: .calculator(.ageGrade)),
        StridePluginItem(id: "posture", posterWords: ["POSTURE"], title: "体态拍立得", summary: "每周一张体态照叠成拍立得，前后对比看变化", badge: .magic, collection: .lifestyle, interaction: .posturePolaroid),
        StridePluginItem(id: "body_fat", posterWords: ["BODY", "FAT"], title: "体脂率估算", summary: "海军围度法，量几处围度即可估算", badge: .magic, collection: .lifestyle, interaction: .calculator(.bodyFat)),
        StridePluginItem(id: "tdee", posterWords: ["TDEE"], title: "TDEE 计算", summary: "五种 BMR 公式对比，算出每日消耗", badge: .magic, collection: .lifestyle, interaction: .calculator(.tdeeCompare)),
        // 图 28–29
        StridePluginItem(id: "bmi", posterWords: ["BMI"], title: "身体指标", summary: "BMI / 腰臀比 / 腰高比 / FFMI 一次算全", badge: .magic, collection: .lifestyle, interaction: .calculator(.bodyMetrics)),
        StridePluginItem(id: "sweat", posterWords: ["SWEAT"], title: "出汗率测试", summary: "测一次，知道每小时该补多少水", badge: .magic, collection: .runningPack, interaction: .calculator(.sweatRate)),
        StridePluginItem(id: "macros", posterWords: ["MACROS"], title: "宏量分配", summary: "按目标算三大宏量，一键设为每日目标", badge: .magic, collection: .lifestyle, interaction: .macrosPlanner),
        StridePluginItem(id: "interval", posterWords: ["INTERVAL"], title: "间歇计时器", summary: "Tabata / EMOM / 自定义，带提示音与震动", badge: .none, collection: .strengthPack, interaction: .intervalTimer),
        StridePluginItem(id: "cadence", posterWords: ["CADENCE"], title: "步频节拍器", summary: "按目标步频打拍，跑步时跟着踩", badge: .magic, collection: .runningPack, interaction: .cadenceMetronome),
        StridePluginItem(id: "shoes", posterWords: ["SHOES"], title: "跑鞋里程", summary: "添加你的跑鞋，之后每次跑步自动累计里程", badge: .magic, collection: .runningPack, interaction: .shoeMileage),
        StridePluginItem(id: "tread", posterWords: ["TREAD"], title: "跑步机换算", summary: "跑步机配速加坡度，等于户外多快", badge: .none, collection: .runningPack, interaction: .calculator(.treadmill)),
        StridePluginItem(id: "drift", posterWords: ["DRIFT"], title: "有氧解耦", summary: "后半程心率漂了多少，看有氧底子够不够", badge: .magic, collection: .runningPack, interaction: .calculator(.aerobicDrift)),
        StridePluginItem(id: "ramp", posterWords: ["RAMP"], title: "跑量增幅", summary: "这周加得太猛了吗？12 周跑量一目了然", badge: .magic, collection: .runningPack, interaction: .calculator(.rampRate)),
        StridePluginItem(id: "fuel", posterWords: ["FUEL"], title: "补给计划", summary: "第几公里吃什么喝多少，排成时间表", badge: .magic, collection: .runningPack, interaction: .calculator(.raceFuel)),
        // 图 30
        StridePluginItem(id: "heat", posterWords: ["HEAT"], title: "温湿度配速", summary: "今天这个天，配速该放慢多少", badge: .magic, collection: .runningPack, interaction: .calculator(.heatPace)),
        StridePluginItem(id: "critical_speed", posterWords: ["CRITICAL", "SPEED"], title: "临界速度", summary: "两次全力跑，算出你能一直维持的速度上限", badge: .magic, collection: .runningPack, interaction: .calculator(.criticalSpeed)),
        StridePluginItem(id: "polarized", posterWords: ["POLARIZED"], title: "强度分布 80/20", summary: "低强度够不够多，灰区有没有超标", badge: .magic, collection: .runningPack, interaction: .calculator(.polarized8020)),
        StridePluginItem(id: "threshold_test", posterWords: ["THRESHOLD", "TEST"], title: "乳酸阈值测试", summary: "30 分钟测出阈值心率和阈值配速", badge: .magic, collection: .runningPack, interaction: .calculator(.thresholdTest)),
        // 图 31
        StridePluginItem(id: "marathon_wall", posterWords: ["MARATHON", "WALL"], title: "撞墙预测", summary: "按糖原储备算你会在第几公里撞墙", badge: .magic, collection: .runningPack, interaction: .calculator(.marathonWall)),
        StridePluginItem(id: "efficiency", posterWords: ["EFFICIENCY"], title: "有氧效率", summary: "同样的心率，跑得更快了吗", badge: .magic, collection: .runningPack, interaction: .calculator(.aerobicEfficiency)),
        StridePluginItem(id: "vdot_trend", posterWords: ["VDOT", "TREND"], title: "跑力趋势", summary: "每一跑都估一次跑力，看它涨没涨", badge: .magic, collection: .runningPack, interaction: .calculator(.vdotTrend)),
        StridePluginItem(id: "fitness_form", posterWords: ["FITNESS", "FORM"], title: "状态曲线", summary: "体能、疲劳、状态：比赛那天在不在巅峰", badge: .magic, collection: .runningPack, interaction: .calculator(.fitnessForm)),
        StridePluginItem(id: "carb_load", posterWords: ["CARB", "LOAD"], title: "碳水加载", summary: "赛前 48 小时，每天每餐吃多少碳水", badge: .magic, collection: .runningPack, interaction: .calculator(.carbLoad)),
        StridePluginItem(id: "taper", posterWords: ["TAPER"], title: "赛前减量", summary: "赛前两周怎么减量，逐日排好", badge: .magic, collection: .runningPack, interaction: .calculator(.taperPlan)),
        // 图 32
        StridePluginItem(id: "race_day", posterWords: ["RACE", "DAY"], title: "比赛日流程", summary: "从赛前一周到冲线，每一步做什么", badge: .magic, collection: .runningPack, interaction: .calculator(.raceDayChecklist)),
        StridePluginItem(id: "key_workouts", posterWords: ["KEY", "WORKOUTS"], title: "专项课表", summary: "按跑力和目标排出每周的关键课", badge: .magic, collection: .runningPack, interaction: .calculator(.keyWorkouts)),
        StridePluginItem(id: "altitude", posterWords: ["ALTITUDE"], title: "高原配速", summary: "高原驻训，配速该放慢多少", badge: .magic, collection: .runningPack, interaction: .calculator(.altitudePace)),
        StridePluginItem(id: "track_laps", posterWords: ["TRACK", "LAPS"], title: "跑道圈速", summary: "目标成绩拆成每圈每 200 米，按道次修正", badge: .magic, collection: .runningPack, interaction: .calculator(.trackLaps)),
        StridePluginItem(id: "athlete_grade", posterWords: ["ATHLETE", "GRADE"], title: "运动员等级", summary: "对照国家田径等级标准，你在哪一档", badge: .magic, collection: .runningPack, interaction: .calculator(.athleteGrade)),
        StridePluginItem(id: "stride_lab", posterWords: ["STRIDE", "LAB"], title: "步频步幅", summary: "步频、步幅、垂直比，看清跑姿效率", badge: .magic, collection: .runningPack, interaction: .calculator(.strideLab)),
        // 图 33
        StridePluginItem(id: "run_power", posterWords: ["RUN", "POWER"], title: "跑步功率", summary: "没有功率计，也能估出每公里多少瓦", badge: .magic, collection: .runningPack, interaction: .calculator(.runPower)),
        StridePluginItem(id: "readiness", posterWords: ["READINESS"], title: "晨间就绪度", summary: "按 HRV 和静息心率，今天适合练多狠", badge: .magic, collection: .strengthPack, interaction: .calculator(.readiness)),
        StridePluginItem(id: "sleep", posterWords: ["SLEEP"], title: "睡眠周期", summary: "现在睡该几点醒，几点起该几点睡", badge: .magic, collection: .lifestyle, interaction: .calculator(.sleepCycle)),
        StridePluginItem(id: "linear_25", posterWords: ["+2.5"], title: "线性加重", summary: "每周加多少，排出整个周期，能存进课表", badge: .magic, collection: .strengthPack, interaction: .linearProgression)
    ]

    static func count(in collection: PluginCollectionKind) -> Int {
        all.filter { $0.collection == collection }.count
    }

    static func installedCount(in collection: PluginCollectionKind, installedIDs: [String]) -> Int {
        let set = Set(installedIDs)
        return all.filter { $0.collection == collection && set.contains($0.id) }.count
    }
}

// MARK: - 插件科学计算公式引擎

enum PluginMath {

    /// 七公式 1RM 估算（返回公式名与 kg）
    static func seven1RMFormulas(weight: Double, reps: Int) -> [(name: String, kg: Double)] {
        guard weight > 0, reps > 0 else { return [] }
        if reps == 1 {
            return [("实测", weight)]
        }
        let r = Double(reps)
        return [
            ("Epley", weight * (1 + r / 30.0)),
            ("Brzycki", weight * (36.0 / max(1.0, 37.0 - r))),
            ("Lombardi", weight * pow(r, 0.10)),
            ("O'Conner", weight * (1 + 0.025 * r)),
            ("Wathan", (100 * weight) / (48.8 + 53.8 * exp(-0.075 * r))),
            ("Mayhew", (100 * weight) / (52.2 + 41.9 * exp(-0.055 * r))),
            ("Lander", (100 * weight) / max(1.0, 101.3 - 2.67123 * r))
        ]
    }

    /// 杠铃单边配片（标准 20kg 空杆）
    static func platesPerSide(targetKg: Double, barKg: Double = 20) -> [Double] {
        let perSide = max(0, (targetKg - barKg) / 2.0)
        var remain = (perSide * 4).rounded() / 4
        let available: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]
        var result: [Double] = []
        for plate in available {
            while remain + 0.001 >= plate {
                result.append(plate)
                remain -= plate
            }
        }
        return result
    }

    /// DOTS 力量举系数得分
    static func dotsScore(bodyweightKg: Double, totalKg: Double, male: Bool) -> Double {
        let bw = min(210, max(40, bodyweightKg))
        let coeffs: [Double] = male
            ? [-307.75076, 24.0900756, -0.1918759221, 0.0007391293, -0.000001093]
            : [-57.96288, 13.6175032, -0.1126655495, 0.0005158568, -0.0000010706]
        let denom = coeffs[0]
            + coeffs[1] * bw
            + coeffs[2] * pow(bw, 2)
            + coeffs[3] * pow(bw, 3)
            + coeffs[4] * pow(bw, 4)
        guard denom > 0 else { return 0 }
        return totalKg * (500.0 / denom)
    }

    /// 美国海军围度法体脂率估算（%）
    static func navyBodyFat(male: Bool, heightCm: Double, waistCm: Double, neckCm: Double, hipCm: Double = 95) -> Double {
        guard heightCm > 80, waistCm > neckCm else { return 18 }
        if male {
            let v = 495.0 / (1.0324 - 0.19077 * log10(max(1, waistCm - neckCm)) + 0.15456 * log10(heightCm)) - 450.0
            return min(55, max(3, v))
        } else {
            let v = 495.0 / (1.29579 - 0.35004 * log10(max(1, waistCm + hipCm - neckCm)) + 0.22100 * log10(heightCm)) - 450.0
            return min(60, max(8, v))
        }
    }

    /// Riegel 跑步成绩预测
    static func riegelPredict(knownMeters: Double, knownSeconds: Double, targetMeters: Double) -> Double {
        guard knownMeters > 0, knownSeconds > 0 else { return 0 }
        return knownSeconds * pow(targetMeters / knownMeters, 1.06)
    }

    /// 简化 VDOT 估算与 E/M/T/I/R 五档配速（秒/公里）
    static func vdotEstimate(distanceMeters: Double, seconds: Double) -> Double {
        guard distanceMeters > 400, seconds > 60 else { return 40 }
        let tMin = seconds / 60.0
        let v = distanceMeters / tMin // m/min
        let vo2 = -4.60 + 0.182258 * v + 0.000104 * v * v
        let pctMax = 0.8 + 0.1894393 * exp(-0.012778 * tMin) + 0.2989558 * exp(-0.1932605 * tMin)
        return max(20, min(85, vo2 / max(0.3, pctMax)))
    }

    static func fivePaceZones(fiveKSeconds: Double) -> [(zone: String, title: String, secPerKm: Int)] {
        let basePace = fiveKSeconds / 5.0 // sec/km at ~I/T border
        return [
            ("E", "轻松有氧", Int((basePace * 1.26).rounded())),
            ("M", "马拉松配速", Int((basePace * 1.12).rounded())),
            ("T", "乳酸阈值", Int((basePace * 1.05).rounded())),
            ("I", "最大摄氧间歇", Int((basePace * 0.97).rounded())),
            ("R", "速度重复", Int((basePace * 0.90).rounded()))
        ]
    }

    static func formatPace(_ secPerKm: Int) -> String {
        guard secPerKm > 0 else { return "—" }
        return String(format: "%d′%02d″/km", secPerKm / 60, secPerKm % 60)
    }

    static func formatDuration(_ sec: Double) -> String {
        let total = max(0, Int(sec.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
