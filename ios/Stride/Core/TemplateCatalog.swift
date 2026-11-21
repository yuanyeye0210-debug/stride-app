import Foundation

// MARK: - 内置官方训练模板库（对应「计划 -> 模板」全部 16 分类，纯本地立即可练）

enum TemplateCatalog {

    static let categories: [String] = [
        "全部", "周计划", "跑步计划", "新手入门", "全身", "三分化",
        "分化训练", "单动作专项", "专项训练", "有氧燃脂", "居家",
        "女性塑形", "体态改善", "拉伸恢复", "特定人群", "我的收藏"
    ]

    // MARK: - 辅助构造一周 7 天

    private static func makeWeek(
        trainDaysMonFirst: [Int: (title: String, focus: MuscleGroup?, exercises: [(String, Int, String)])]
    ) -> [PlannedDay] {
        // Calendar weekday: 1=日, 2=一, 3=二, 4=三, 5=四, 6=五, 7=六
        let monFirstToWeekday = [1: 2, 2: 3, 3: 4, 4: 5, 5: 6, 6: 7, 7: 1]
        return (1...7).map { monIdx in
            let calWeekday = monFirstToWeekday[monIdx] ?? 2
            if let spec = trainDaysMonFirst[monIdx] {
                return PlannedDay(
                    weekday: calWeekday,
                    title: spec.title,
                    focus: spec.focus,
                    exercises: spec.exercises.map { PlannedExercise(name: $0.0, sets: $0.1, reps: $0.2) },
                    rest: false
                )
            } else {
                return PlannedDay(
                    weekday: calWeekday,
                    title: "恢复",
                    focus: nil,
                    exercises: [
                        PlannedExercise(name: "快走 20 分钟", sets: 1, reps: "20 min"),
                        PlannedExercise(name: "全身拉伸", sets: 1, reps: "10 min")
                    ],
                    rest: true
                )
            }
        }
    }

    // MARK: - 周计划模板

    static let weekPlans: [WeekPlanTemplate] = [
        WeekPlanTemplate(
            id: "week.ppl3",
            title: "经典三分化",
            subtitle: "胸三头 / 背二头 / 腿",
            activeWeekdaysMonFirst: [1, 3, 5],
            level: "入门",
            minutesPerSession: 61,
            isCardioTheme: false,
            categories: ["周计划", "新手入门", "三分化"],
            days: makeWeek(trainDaysMonFirst: [
                1: ("胸三头", .chest, [("杠铃卧推", 4, "8–10"), ("上斜哑铃卧推", 3, "10–12"), ("绳索夹胸", 3, "12–15"), ("绳索下压", 3, "12–15")]),
                3: ("背二头", .back, [("引体向上", 4, "8–10"), ("杠铃划船", 4, "8–10"), ("高位下拉", 3, "10–12"), ("杠铃弯举", 3, "10–12")]),
                5: ("下肢腿", .legs, [("深蹲", 4, "6–8"), ("罗马尼亚硬拉", 3, "8–10"), ("腿举", 3, "12"), ("站姿提踵", 3, "15")])
            ])
        ),
        WeekPlanTemplate(
            id: "week.ppl6",
            title: "三分化 × 2",
            subtitle: "一周六练",
            activeWeekdaysMonFirst: [1, 2, 3, 5, 6, 7],
            level: "进阶",
            minutesPerSession: 64,
            isCardioTheme: false,
            categories: ["周计划", "三分化"],
            days: makeWeek(trainDaysMonFirst: [
                1: ("推 A", .chest, [("杠铃卧推", 4, "6–8"), ("站姿推举", 3, "8–10"), ("哑铃侧平举", 4, "12–15"), ("绳索下压", 3, "12")]),
                2: ("拉 A", .back, [("引体向上", 4, "8"), ("杠铃划船", 4, "8–10"), ("面拉", 3, "15"), ("杠铃弯举", 3, "10")]),
                3: ("腿 A", .legs, [("深蹲", 4, "6–8"), ("罗马尼亚硬拉", 3, "8–10"), ("腿举", 3, "12"), ("站姿提踵", 3, "15")]),
                5: ("推 B", .chest, [("上斜哑铃卧推", 4, "8–10"), ("双杠臂屈伸", 3, "10"), ("绳索夹胸", 3, "12"), ("哑铃侧平举", 4, "15")]),
                6: ("拉 B", .back, [("高位下拉", 4, "10–12"), ("坐姿绳索划船", 4, "10–12"), ("面拉", 3, "15"), ("锤式弯举", 3, "12")]),
                7: ("腿 B", .legs, [("保加利亚分腿蹲", 4, "10/侧"), ("罗马尼亚硬拉", 4, "8–10"), ("悬垂举腿", 3, "12"), ("平板支撑", 3, "45 秒")])
            ])
        ),
        WeekPlanTemplate(
            id: "week.split4",
            title: "四分化",
            subtitle: "胸三头 / 背二头 / 腿 / 肩",
            activeWeekdaysMonFirst: [1, 2, 4, 6],
            level: "进阶",
            minutesPerSession: 63,
            isCardioTheme: false,
            categories: ["周计划", "分化训练"],
            days: makeWeek(trainDaysMonFirst: [
                1: ("胸三头", .chest, [("杠铃卧推", 4, "8"), ("上斜哑铃卧推", 4, "10"), ("绳索夹胸", 3, "12"), ("绳索下压", 3, "12")]),
                2: ("背二头", .back, [("引体向上", 4, "8"), ("杠铃划船", 4, "10"), ("坐姿绳索划船", 3, "12"), ("锤式弯举", 3, "12")]),
                4: ("腿部日", .legs, [("深蹲", 4, "8"), ("罗马尼亚硬拉", 4, "10"), ("腿举", 3, "12"), ("站姿提踵", 4, "15")]),
                6: ("肩臂塑形", .shoulders, [("站姿推举", 4, "8"), ("哑铃侧平举", 4, "15"), ("面拉", 3, "15"), ("杠铃弯举", 3, "10")])
            ])
        ),
        WeekPlanTemplate(
            id: "week.split5",
            title: "五分化",
            subtitle: "胸 / 背 / 腿 / 肩 / 臀腿后侧",
            activeWeekdaysMonFirst: [1, 2, 3, 5, 6],
            level: "进阶",
            minutesPerSession: 64,
            isCardioTheme: false,
            categories: ["周计划", "分化训练"],
            days: makeWeek(trainDaysMonFirst: [
                1: ("胸", .chest, [("杠铃卧推", 4, "8"), ("上斜哑铃卧推", 4, "10"), ("双杠臂屈伸", 3, "10"), ("绳索夹胸", 3, "15")]),
                2: ("背", .back, [("引体向上", 4, "8"), ("杠铃划船", 4, "8–10"), ("高位下拉", 3, "12"), ("坐姿绳索划船", 3, "12")]),
                3: ("腿前侧", .legs, [("深蹲", 4, "6–8"), ("腿举", 4, "12"), ("保加利亚分腿蹲", 3, "10"), ("站姿提踵", 4, "15")]),
                5: ("肩", .shoulders, [("站姿推举", 4, "8"), ("哑铃侧平举", 5, "15"), ("面拉", 4, "15")]),
                6: ("臀腿后侧", .legs, [("罗马尼亚硬拉", 4, "8"), ("保加利亚分腿蹲", 3, "10"), ("悬垂举腿", 3, "12")])
            ])
        ),
        WeekPlanTemplate(
            id: "week.women3",
            title: "女生三分化",
            subtitle: "臀腿前侧 / 背二头 / 臀腘绳",
            activeWeekdaysMonFirst: [1, 3, 5],
            level: "入门",
            minutesPerSession: 55,
            isCardioTheme: false,
            categories: ["周计划", "新手入门", "三分化", "女性塑形"],
            days: makeWeek(trainDaysMonFirst: [
                1: ("臀腿前侧", .legs, [("深蹲", 4, "10"), ("保加利亚分腿蹲", 3, "12/侧"), ("腿举", 3, "12"), ("平板支撑", 3, "45 秒")]),
                3: ("背二头塑形", .back, [("高位下拉", 4, "12"), ("坐姿绳索划船", 4, "12"), ("面拉", 3, "15"), ("哑铃侧平举", 3, "15")]),
                5: ("臀腘绳后链", .legs, [("罗马尼亚硬拉", 4, "10"), ("保加利亚分腿蹲", 3, "12"), ("悬垂举腿", 3, "12")])
            ])
        ),
        WeekPlanTemplate(
            id: "week.runStart",
            title: "跑步入门",
            subtitle: "从 3 公里到 5 公里",
            activeWeekdaysMonFirst: [2, 4, 6, 7],
            level: "入门",
            minutesPerSession: 40,
            isCardioTheme: true,
            categories: ["周计划", "新手入门", "有氧燃脂"],
            days: makeWeek(trainDaysMonFirst: [
                2: ("轻松跑 3 km", .cardio, [("跑步", 1, "25 min"), ("平板支撑", 3, "40 秒")]),
                4: ("跑走交替", .cardio, [("跑步", 1, "30 min"), ("快走 10 分钟", 1, "10 min")]),
                6: ("稳态耐力跑", .cardio, [("跑步", 1, "35 min")]),
                7: ("长距离慢跑", .cardio, [("跑步", 1, "40 min")])
            ])
        ),
        WeekPlanTemplate(
            id: "week.hybridOffice",
            title: "混合训练",
            subtitle: "上班族 4 练",
            activeWeekdaysMonFirst: [1, 2, 4, 6],
            level: "入门",
            minutesPerSession: 46,
            isCardioTheme: true,
            categories: ["周计划", "分化训练", "有氧燃脂", "特定人群"],
            days: makeWeek(trainDaysMonFirst: [
                1: ("上肢推拉", .chest, [("杠铃卧推", 3, "8–10"), ("高位下拉", 3, "10–12"), ("哑铃侧平举", 3, "15")]),
                2: ("轻松慢跑", .cardio, [("跑步", 1, "30 min"), ("平板支撑", 3, "45 秒")]),
                4: ("下肢核心", .legs, [("深蹲", 3, "8–10"), ("罗马尼亚硬拉", 3, "10"), ("健腹轮", 3, "10")]),
                6: ("间歇燃脂", .cardio, [("划船机", 4, "3 min"), ("跑步", 1, "20 min")])
            ])
        ),
        WeekPlanTemplate(
            id: "week.bench3",
            title: "卧推三阶段",
            subtitle: "主项不力竭三分化",
            activeWeekdaysMonFirst: [1, 2, 3, 5, 6],
            level: "进阶",
            minutesPerSession: 62,
            isCardioTheme: false,
            categories: ["周计划", "单动作专项"],
            days: makeWeek(trainDaysMonFirst: [
                1: ("卧推重日", .chest, [("杠铃卧推", 5, "5"), ("上斜哑铃卧推", 3, "8"), ("绳索下压", 3, "12")]),
                2: ("背部平衡", .back, [("引体向上", 4, "8"), ("杠铃划船", 4, "8"), ("面拉", 3, "15")]),
                3: ("腿部基础", .legs, [("深蹲", 4, "6"), ("腿举", 3, "10"), ("站姿提踵", 3, "15")]),
                5: ("卧推速度容量", .chest, [("杠铃卧推", 4, "8"), ("双杠臂屈伸", 3, "10"), ("哑铃侧平举", 4, "12")]),
                6: ("后链与划船", .back, [("罗马尼亚硬拉", 4, "8"), ("坐姿绳索划船", 4, "10"), ("杠铃弯举", 3, "10")])
            ])
        ),
        WeekPlanTemplate(
            id: "week.powerlift",
            title: "力量举周",
            subtitle: "三大项波动周期",
            activeWeekdaysMonFirst: [1, 2, 4, 5, 6],
            level: "高级",
            minutesPerSession: 78,
            isCardioTheme: false,
            categories: ["周计划", "单动作专项", "专项训练"],
            days: makeWeek(trainDaysMonFirst: [
                1: ("深蹲主日", .legs, [("深蹲", 5, "5"), ("腿举", 3, "10"), ("平板支撑", 3, "60 秒")]),
                2: ("卧推主日", .chest, [("杠铃卧推", 5, "5"), ("上斜哑铃卧推", 3, "8"), ("面拉", 4, "15")]),
                4: ("硬拉主日", .legs, [("罗马尼亚硬拉", 5, "5"), ("引体向上", 4, "8"), ("悬垂举腿", 3, "12")]),
                5: ("卧推辅助", .shoulders, [("站姿推举", 4, "6"), ("双杠臂屈伸", 3, "10"), ("绳索下压", 3, "12")]),
                6: ("下肢容量", .legs, [("深蹲", 4, "8"), ("杠铃划船", 4, "8"), ("锤式弯举", 3, "12")])
            ])
        ),
        WeekPlanTemplate(
            id: "week.cardioBurn",
            title: "有氧燃脂周",
            subtitle: "不跑步也能练",
            activeWeekdaysMonFirst: [1, 2, 3, 5, 6],
            level: "入门",
            minutesPerSession: 40,
            isCardioTheme: true,
            categories: ["周计划", "有氧燃脂"],
            days: makeWeek(trainDaysMonFirst: [
                1: ("划船间歇", .cardio, [("划船机", 5, "4 min"), ("平板支撑", 3, "45 秒")]),
                2: ("上肢代谢", .chest, [("上斜哑铃卧推", 3, "12"), ("高位下拉", 3, "12"), ("哑铃侧平举", 3, "15")]),
                3: ("划船耐力", .cardio, [("划船机", 1, "30 min")]),
                5: ("下肢燃脂", .legs, [("保加利亚分腿蹲", 3, "12"), ("深蹲", 3, "12"), ("悬垂举腿", 3, "12")]),
                6: ("全身循环", .cardio, [("划船机", 3, "5 min"), ("健腹轮", 3, "12")])
            ])
        ),
        WeekPlanTemplate(
            id: "week.glute5",
            title: "蜜桃臀塑形周",
            subtitle: "臀中肌与后链精雕",
            activeWeekdaysMonFirst: [1, 2, 3, 5, 6],
            level: "入门",
            minutesPerSession: 50,
            isCardioTheme: false,
            categories: ["周计划", "专项训练", "女性塑形"],
            days: makeWeek(trainDaysMonFirst: [
                1: ("臀推主日", .legs, [("深蹲", 4, "10"), ("罗马尼亚硬拉", 4, "10"), ("保加利亚分腿蹲", 3, "12")]),
                2: ("美背直角肩", .back, [("高位下拉", 4, "12"), ("哑铃侧平举", 4, "15"), ("面拉", 3, "15")]),
                3: ("单侧臀腿", .legs, [("保加利亚分腿蹲", 4, "12"), ("腿举", 3, "12"), ("平板支撑", 3, "45 秒")]),
                5: ("核心马甲线", .core, [("悬垂举腿", 4, "12"), ("健腹轮", 3, "10"), ("平板支撑", 3, "60 秒")]),
                6: ("后链强化", .legs, [("罗马尼亚硬拉", 4, "10"), ("深蹲", 3, "12"), ("站姿提踵", 3, "15")])
            ])
        ),
        WeekPlanTemplate(
            id: "week.homeDumbbell",
            title: "居家哑铃周",
            subtitle: "一对哑铃练全身",
            activeWeekdaysMonFirst: [1, 2, 4, 5, 6],
            level: "入门",
            minutesPerSession: 45,
            isCardioTheme: false,
            categories: ["周计划", "居家", "新手入门"],
            days: makeWeek(trainDaysMonFirst: [
                1: ("上肢推", .chest, [("上斜哑铃卧推", 4, "10–12"), ("哑铃侧平举", 4, "15"), ("平板支撑", 3, "45 秒")]),
                2: ("下肢蹲", .legs, [("保加利亚分腿蹲", 4, "10/侧"), ("罗马尼亚硬拉", 4, "12"), ("站姿提踵", 3, "15")]),
                4: ("背部手臂", .back, [("引体向上", 4, "8"), ("锤式弯举", 3, "12"), ("悬垂举腿", 3, "12")]),
                5: ("肩臂核心", .shoulders, [("哑铃侧平举", 4, "15"), ("锤式弯举", 3, "12"), ("健腹轮", 3, "10")]),
                6: ("全身巩固", .legs, [("保加利亚分腿蹲", 3, "12"), ("上斜哑铃卧推", 3, "12"), ("平板支撑", 3, "60 秒")])
            ])
        ),
        WeekPlanTemplate(
            id: "week.posture",
            title: "体态改善 + 力量周",
            subtitle: "纠正圆肩驼背与核心稳固",
            activeWeekdaysMonFirst: [1, 2, 4, 5, 6],
            level: "入门",
            minutesPerSession: 45,
            isCardioTheme: false,
            categories: ["周计划", "新手入门", "体态改善", "特定人群"],
            days: makeWeek(trainDaysMonFirst: [
                1: ("上背激活", .back, [("面拉", 4, "15"), ("坐姿绳索划船", 4, "12"), ("高位下拉", 3, "12")]),
                2: ("髋与核心", .core, [("平板支撑", 4, "45 秒"), ("悬垂举腿", 3, "10"), ("罗马尼亚硬拉", 3, "10")]),
                4: ("肩袖与推", .shoulders, [("哑铃侧平举", 4, "15"), ("上斜哑铃卧推", 3, "10"), ("面拉", 3, "15")]),
                5: ("下肢稳定", .legs, [("保加利亚分腿蹲", 3, "10"), ("深蹲", 3, "10"), ("站姿提踵", 3, "15")]),
                6: ("全身拉伸", .back, [("引体向上", 3, "8"), ("坐姿绳索划船", 3, "12"), ("平板支撑", 3, "60 秒")])
            ])
        ),
        WeekPlanTemplate(
            id: "week.runnerStrength",
            title: "跑者力量周",
            subtitle: "提升跑步经济性与抗伤病",
            activeWeekdaysMonFirst: [1, 2, 4, 5, 6],
            level: "进阶",
            minutesPerSession: 54,
            isCardioTheme: true,
            categories: ["周计划", "特定人群", "有氧燃脂"],
            days: makeWeek(trainDaysMonFirst: [
                1: ("单侧下肢力量", .legs, [("保加利亚分腿蹲", 4, "10"), ("站姿提踵", 4, "15"), ("平板支撑", 3, "60 秒")]),
                2: ("轻松跑", .cardio, [("跑步", 1, "40 min")]),
                4: ("后链爆发", .legs, [("罗马尼亚硬拉", 4, "8"), ("深蹲", 3, "8"), ("悬垂举腿", 3, "12")]),
                5: ("核心上肢", .core, [("引体向上", 3, "8"), ("上斜哑铃卧推", 3, "10"), ("面拉", 3, "15")]),
                6: ("节奏跑", .cardio, [("跑步", 1, "45 min")])
            ])
        ),
        WeekPlanTemplate(
            id: "week.newbieFirstMonth",
            title: "新手第一个月",
            subtitle: "全身入门周",
            activeWeekdaysMonFirst: [1, 2, 3, 5, 6],
            level: "入门",
            minutesPerSession: 45,
            isCardioTheme: false,
            categories: ["周计划", "新手入门", "全身"],
            days: makeWeek(trainDaysMonFirst: [
                1: ("推拉入门", .chest, [("杠铃卧推", 3, "10"), ("高位下拉", 3, "10")]),
                2: ("腿核心入门", .legs, [("深蹲", 3, "10"), ("平板支撑", 3, "40 秒")]),
                3: ("轻有氧", .cardio, [("划船机", 1, "20 min")]),
                5: ("上肢巩固", .shoulders, [("站姿推举", 3, "10"), ("坐姿绳索划船", 3, "12")]),
                6: ("下肢巩固", .legs, [("腿举", 3, "12"), ("罗马尼亚硬拉", 3, "10")])
            ])
        ),
        WeekPlanTemplate(
            id: "week.phul",
            title: "PHUL 力量增肌周",
            subtitle: "上下肢力量与肌肥大双循环",
            activeWeekdaysMonFirst: [1, 2, 4, 5, 6],
            level: "进阶",
            minutesPerSession: 63,
            isCardioTheme: false,
            categories: ["周计划", "分化训练"],
            days: makeWeek(trainDaysMonFirst: [
                1: ("上肢力量", .chest, [("杠铃卧推", 4, "5"), ("杠铃划船", 4, "5"), ("站姿推举", 3, "6")]),
                2: ("下肢力量", .legs, [("深蹲", 4, "5"), ("罗马尼亚硬拉", 3, "6"), ("站姿提踵", 4, "12")]),
                4: ("上肢肥大", .shoulders, [("上斜哑铃卧推", 4, "10"), ("高位下拉", 4, "10"), ("哑铃侧平举", 4, "15"), ("杠铃弯举", 3, "12")]),
                5: ("下肢肥大", .legs, [("腿举", 4, "12"), ("保加利亚分腿蹲", 3, "10"), ("站姿提踵", 4, "15")]),
                6: ("核心有氧", .core, [("悬垂举腿", 3, "12"), ("划船机", 1, "20 min")])
            ])
        ),
        WeekPlanTemplate(
            id: "week.hybridRun3",
            title: "混合训练",
            subtitle: "三分化 + 三次跑步",
            activeWeekdaysMonFirst: [1, 2, 3, 4, 5, 6],
            level: "进阶",
            minutesPerSession: 54,
            isCardioTheme: true,
            categories: ["周计划", "三分化", "有氧燃脂"],
            days: makeWeek(trainDaysMonFirst: [
                1: ("推日", .chest, [("杠铃卧推", 4, "8"), ("站姿推举", 3, "10"), ("绳索下压", 3, "12")]),
                2: ("轻松跑 5 km", .cardio, [("跑步", 1, "30 min")]),
                3: ("拉日", .back, [("引体向上", 4, "8"), ("杠铃划船", 4, "10"), ("杠铃弯举", 3, "12")]),
                4: ("间歇跑", .cardio, [("跑步", 1, "35 min")]),
                5: ("腿日", .legs, [("深蹲", 4, "8"), ("罗马尼亚硬拉", 3, "10"), ("站姿提踵", 3, "15")]),
                6: ("周末长跑", .cardio, [("跑步", 1, "50 min")])
            ])
        )
    ]

    // MARK: - 跑步周期计划

    static let runPrograms: [RunProgramTemplate] = [
        RunProgramTemplate(
            id: "run.walkRun",
            posterLines: ["WALK", "RUN"],
            accentRaw: "silver",
            title: "零基础 · 跑走结合",
            level: "入门",
            weeks: 6,
            sessionsPerWeek: 3,
            summary: "跑 2 分钟走 1 分钟起步，安全建立膝踝耐受与心肺基础。",
            sampleDays: makeWeek(trainDaysMonFirst: [
                2: ("跑走交替 25 分", .cardio, [("跑步", 1, "25 min")]),
                4: ("轻松跑走 30 分", .cardio, [("跑步", 1, "30 min")]),
                6: ("周末户外漫跑", .cardio, [("跑步", 1, "35 min")])
            ])
        ),
        RunProgramTemplate(
            id: "run.easyRun",
            posterLines: ["EASY", "RUN"],
            accentRaw: "green",
            title: "轻松跑养成",
            level: "入门",
            weeks: 4,
            sessionsPerWeek: 3,
            summary: "全程控制在对话心率区（Zone 2），打造有氧底座。",
            sampleDays: makeWeek(trainDaysMonFirst: [
                2: ("有氧轻松跑 30 分", .cardio, [("跑步", 1, "30 min")]),
                4: ("有氧轻松跑 35 分", .cardio, [("跑步", 1, "35 min")]),
                6: ("有氧轻松跑 45 分", .cardio, [("跑步", 1, "45 min")])
            ])
        ),
        RunProgramTemplate(
            id: "run.fatBurn",
            posterLines: ["FAT", "BURN"],
            accentRaw: "purple",
            title: "燃脂跑 · 4 周",
            level: "入门",
            weeks: 4,
            sessionsPerWeek: 4,
            summary: "有氧耐力搭配变速冲刺，兼顾减脂与心肺提升。",
            sampleDays: makeWeek(trainDaysMonFirst: [
                1: ("稳态燃脂跑", .cardio, [("跑步", 1, "35 min")]),
                3: ("变速法特莱克", .cardio, [("跑步", 1, "30 min")]),
                5: ("稳态燃脂跑", .cardio, [("跑步", 1, "35 min")]),
                7: ("长距慢跑", .cardio, [("跑步", 1, "45 min")])
            ])
        ),
        RunProgramTemplate(
            id: "run.5k",
            posterLines: ["5K"],
            accentRaw: "blue",
            title: "5 公里提速",
            level: "进阶",
            weeks: 6,
            sessionsPerWeek: 3,
            summary: "间歇速度课 + 节奏跑组合，冲击个人 5K PB。",
            sampleDays: makeWeek(trainDaysMonFirst: [
                2: ("400m × 6 间歇跑", .cardio, [("跑步", 1, "35 min")]),
                4: ("节奏门槛跑", .cardio, [("跑步", 1, "30 min")]),
                6: ("8 km 耐力巩固", .cardio, [("跑步", 1, "48 min")])
            ])
        ),
        RunProgramTemplate(
            id: "run.10k",
            posterLines: ["10K"],
            accentRaw: "silver",
            title: "10 公里完赛",
            level: "进阶",
            weeks: 8,
            sessionsPerWeek: 3,
            summary: "周跑量渐进爬坡至 30 km，轻松跑完 10 公里。",
            sampleDays: makeWeek(trainDaysMonFirst: [
                2: ("轻松跑 6 km", .cardio, [("跑步", 1, "36 min")]),
                4: ("乳酸阈值 5 km", .cardio, [("跑步", 1, "30 min")]),
                7: ("周末长距离 10 km", .cardio, [("跑步", 1, "62 min")])
            ])
        ),
        RunProgramTemplate(
            id: "run.half21k",
            posterLines: ["HALF", "21K"],
            accentRaw: "purple",
            title: "半程马拉松进阶",
            level: "高级",
            weeks: 8,
            sessionsPerWeek: 3,
            summary: "针对半马配速耐力与糖原补给的系统 8 周备赛周期。",
            sampleDays: makeWeek(trainDaysMonFirst: [
                2: ("间歇 1000m × 5", .cardio, [("跑步", 1, "45 min")]),
                4: ("半马配速节奏跑", .cardio, [("跑步", 1, "50 min")]),
                7: ("LSD 长距离 16 km", .cardio, [("跑步", 1, "95 min")])
            ])
        )
    ]

    // MARK: - 单次精选训练模板（带超大英文封面）

    static let singleWorkouts: [WorkoutTemplate] = [
        WorkoutTemplate(
            id: "single.shouldersOrder",
            posterWords: ["SHOULDERS"],
            accentRaw: "silver",
            title: "练肩先后顺序",
            level: "入门",
            estimatedMinutes: 50,
            categories: ["新手入门", "专项训练"],
            focus: .shoulders,
            exercises: [
                PlannedExercise(name: "站姿推举", sets: 4, reps: "8–10", note: "复合动作先练"),
                PlannedExercise(name: "哑铃侧平举", sets: 4, reps: "12–15", note: "中束宽度"),
                PlannedExercise(name: "面拉", sets: 4, reps: "15", note: "后束与肩袖稳定")
            ],
            isCustom: false
        ),
        WorkoutTemplate(
            id: "single.chestOrder",
            posterWords: ["CHEST"],
            accentRaw: "silver",
            title: "练胸先后顺序",
            level: "入门",
            estimatedMinutes: 50,
            categories: ["新手入门", "专项训练"],
            focus: .chest,
            exercises: [
                PlannedExercise(name: "杠铃卧推", sets: 4, reps: "8", note: "平推基础"),
                PlannedExercise(name: "上斜哑铃卧推", sets: 4, reps: "10", note: "补强上胸"),
                PlannedExercise(name: "绳索夹胸", sets: 3, reps: "12–15", note: "孤立顶峰收缩")
            ],
            isCustom: false
        ),
        WorkoutTemplate(
            id: "single.fullBody3",
            posterWords: ["FULL", "BODY"],
            accentRaw: "silver",
            title: "新手全身三练",
            level: "入门",
            estimatedMinutes: 45,
            categories: ["新手入门", "全身"],
            focus: .legs,
            exercises: [
                PlannedExercise(name: "深蹲", sets: 3, reps: "8–10"),
                PlannedExercise(name: "杠铃卧推", sets: 3, reps: "8–10"),
                PlannedExercise(name: "高位下拉", sets: 3, reps: "10–12"),
                PlannedExercise(name: "平板支撑", sets: 3, reps: "45 秒")
            ],
            isCustom: false
        ),
        WorkoutTemplate(
            id: "single.kettlebellFull",
            posterWords: ["FULL", "BODY"],
            accentRaw: "silver",
            title: "壶铃全身燃脂",
            level: "进阶",
            estimatedMinutes: 35,
            categories: ["全身", "有氧燃脂"],
            focus: .cardio,
            exercises: [
                PlannedExercise(name: "深蹲", sets: 4, reps: "12"),
                PlannedExercise(name: "罗马尼亚硬拉", sets: 4, reps: "12"),
                PlannedExercise(name: "划船机", sets: 3, reps: "3 min")
            ],
            isCustom: false
        ),
        WorkoutTemplate(
            id: "single.pushChestTri",
            posterWords: ["PUSH"],
            accentRaw: "silver",
            title: "三分化 · 胸 + 三头",
            level: "进阶",
            estimatedMinutes: 65,
            categories: ["三分化"],
            focus: .chest,
            exercises: [
                PlannedExercise(name: "杠铃卧推", sets: 4, reps: "6–8"),
                PlannedExercise(name: "上斜哑铃卧推", sets: 4, reps: "10"),
                PlannedExercise(name: "双杠臂屈伸", sets: 3, reps: "10"),
                PlannedExercise(name: "绳索下压", sets: 3, reps: "12–15")
            ],
            isCustom: false
        ),
        WorkoutTemplate(
            id: "single.shoulders3d",
            posterWords: ["SHOULDERS"],
            accentRaw: "silver",
            title: "肩部三束全练",
            level: "进阶",
            estimatedMinutes: 55,
            categories: ["分化训练", "专项训练"],
            focus: .shoulders,
            exercises: [
                PlannedExercise(name: "站姿推举", sets: 4, reps: "8"),
                PlannedExercise(name: "哑铃侧平举", sets: 5, reps: "15"),
                PlannedExercise(name: "面拉", sets: 4, reps: "15")
            ],
            isCustom: false
        ),
        WorkoutTemplate(
            id: "single.squat5x10",
            posterWords: ["LEGS"],
            accentRaw: "purple",
            title: "主项 + 5×10 · 深蹲日",
            level: "高级",
            estimatedMinutes: 65,
            categories: ["单动作专项"],
            focus: .legs,
            exercises: [
                PlannedExercise(name: "深蹲", sets: 5, reps: "5", note: "重重量主项"),
                PlannedExercise(name: "深蹲", sets: 5, reps: "10", note: "BBB 60% 容量组"),
                PlannedExercise(name: "悬垂举腿", sets: 3, reps: "12")
            ],
            isCustom: false
        ),
        WorkoutTemplate(
            id: "single.benchDay",
            posterWords: ["PUSH"],
            accentRaw: "silver",
            title: "卧推突破 · 胸日",
            level: "进阶",
            estimatedMinutes: 60,
            categories: ["单动作专项"],
            focus: .chest,
            exercises: [
                PlannedExercise(name: "杠铃卧推", sets: 5, reps: "5"),
                PlannedExercise(name: "上斜哑铃卧推", sets: 3, reps: "10"),
                PlannedExercise(name: "绳索夹胸", sets: 3, reps: "15")
            ],
            isCustom: false
        ),
        WorkoutTemplate(
            id: "single.homePullup",
            posterWords: ["UPPER"],
            accentRaw: "silver",
            title: "徒手单杠 · 上肢",
            level: "进阶",
            estimatedMinutes: 45,
            categories: ["居家"],
            focus: .back,
            exercises: [
                PlannedExercise(name: "引体向上", sets: 5, reps: "8"),
                PlannedExercise(name: "双杠臂屈伸", sets: 4, reps: "10"),
                PlannedExercise(name: "悬垂举腿", sets: 4, reps: "12")
            ],
            isCustom: false
        ),
        WorkoutTemplate(
            id: "single.hiitNoEquip",
            posterWords: ["HIIT"],
            accentRaw: "green",
            title: "居家无器械 · 全身燃脂",
            level: "入门",
            estimatedMinutes: 22,
            categories: ["有氧燃脂", "居家"],
            focus: .cardio,
            exercises: [
                PlannedExercise(name: "深蹲", sets: 4, reps: "20"),
                PlannedExercise(name: "平板支撑", sets: 4, reps: "45 秒"),
                PlannedExercise(name: "健腹轮", sets: 3, reps: "12")
            ],
            isCustom: false
        ),
        WorkoutTemplate(
            id: "single.gluteShape",
            posterWords: ["LEGS"],
            accentRaw: "purple",
            title: "臀腿塑形日",
            level: "进阶",
            estimatedMinutes: 55,
            categories: ["女性塑形"],
            focus: .legs,
            exercises: [
                PlannedExercise(name: "罗马尼亚硬拉", sets: 4, reps: "10"),
                PlannedExercise(name: "保加利亚分腿蹲", sets: 4, reps: "12/侧"),
                PlannedExercise(name: "腿举", sets: 3, reps: "15")
            ],
            isCustom: false
        ),
        WorkoutTemplate(
            id: "single.coreAbs",
            posterWords: ["CORE"],
            accentRaw: "silver",
            title: "马甲线养成计划",
            level: "入门",
            estimatedMinutes: 25,
            categories: ["女性塑形"],
            focus: .core,
            exercises: [
                PlannedExercise(name: "悬垂举腿", sets: 4, reps: "12"),
                PlannedExercise(name: "健腹轮", sets: 3, reps: "10"),
                PlannedExercise(name: "平板支撑", sets: 3, reps: "60 秒")
            ],
            isCustom: false
        ),
        WorkoutTemplate(
            id: "single.swanNeck",
            posterWords: ["UPPER"],
            accentRaw: "silver",
            title: "直角肩 · 天鹅颈体态",
            level: "入门",
            estimatedMinutes: 25,
            categories: ["体态改善"],
            focus: .shoulders,
            exercises: [
                PlannedExercise(name: "面拉", sets: 4, reps: "15"),
                PlannedExercise(name: "哑铃侧平举", sets: 3, reps: "15"),
                PlannedExercise(name: "坐姿绳索划船", sets: 3, reps: "12")
            ],
            isCustom: false
        ),
        WorkoutTemplate(
            id: "single.hunchback",
            posterWords: ["UPPER"],
            accentRaw: "silver",
            title: "改善圆肩驼背",
            level: "入门",
            estimatedMinutes: 20,
            categories: ["体态改善"],
            focus: .back,
            exercises: [
                PlannedExercise(name: "面拉", sets: 4, reps: "15"),
                PlannedExercise(name: "高位下拉", sets: 3, reps: "12")
            ],
            isCustom: false
        ),
        WorkoutTemplate(
            id: "single.pelvicTilt",
            posterWords: ["GLUTE"],
            accentRaw: "purple",
            title: "骨盆前倾矫正",
            level: "入门",
            estimatedMinutes: 25,
            categories: ["体态改善"],
            focus: .core,
            exercises: [
                PlannedExercise(name: "平板支撑", sets: 4, reps: "45 秒"),
                PlannedExercise(name: "罗马尼亚硬拉", sets: 3, reps: "12")
            ],
            isCustom: false
        ),
        WorkoutTemplate(
            id: "single.sleepStretch",
            posterWords: ["STRETCH"],
            accentRaw: "silver",
            title: "睡前 15 分钟拉伸助眠",
            level: "入门",
            estimatedMinutes: 15,
            categories: ["拉伸恢复"],
            focus: .cardio,
            exercises: [
                PlannedExercise(name: "全身放松拉伸", sets: 1, reps: "15 min")
            ],
            isCustom: false
        ),
        WorkoutTemplate(
            id: "single.officeStretch",
            posterWords: ["STRETCH"],
            accentRaw: "silver",
            title: "久坐办公族拉伸",
            level: "入门",
            estimatedMinutes: 15,
            categories: ["拉伸恢复", "特定人群"],
            focus: .cardio,
            exercises: [
                PlannedExercise(name: "胸椎与髋活动度拉伸", sets: 1, reps: "15 min")
            ],
            isCustom: false
        ),
        WorkoutTemplate(
            id: "single.runStretch",
            posterWords: ["STRETCH"],
            accentRaw: "silver",
            title: "跑后拉伸",
            level: "入门",
            estimatedMinutes: 10,
            categories: ["拉伸恢复"],
            focus: .legs,
            exercises: [
                PlannedExercise(name: "小腿与腘绳肌拉伸", sets: 1, reps: "10 min")
            ],
            isCustom: false
        ),
        WorkoutTemplate(
            id: "single.lowBackCore",
            posterWords: ["CORE"],
            accentRaw: "silver",
            title: "下背友好 · 核心稳定",
            level: "入门",
            estimatedMinutes: 20,
            categories: ["特定人群", "体态改善"],
            focus: .core,
            exercises: [
                PlannedExercise(name: "平板支撑", sets: 4, reps: "45 秒"),
                PlannedExercise(name: "悬垂举腿", sets: 3, reps: "10")
            ],
            isCustom: false
        )
    ]

    /// 个人默认起始模板（与图 34 对齐）
    static let starterPersonalTemplates: [WorkoutTemplate] = [
        WorkoutTemplate(
            id: "personal.squat",
            posterWords: ["LEG", "DAY"],
            accentRaw: "silver",
            title: "深蹲",
            level: "进阶",
            estimatedMinutes: 45,
            categories: ["单动作专项"],
            focus: .legs,
            exercises: [
                PlannedExercise(name: "深蹲", sets: 4, reps: "6–8"),
                PlannedExercise(name: "站姿提踵", sets: 3, reps: "15")
            ],
            isCustom: true
        ),
        WorkoutTemplate(
            id: "personal.chest",
            posterWords: ["CHEST", "TRAINING"],
            accentRaw: "silver",
            title: "胸训练",
            level: "进阶",
            estimatedMinutes: 50,
            categories: ["分化训练"],
            focus: .chest,
            exercises: [
                PlannedExercise(name: "杠铃卧推", sets: 4, reps: "8")
            ],
            isCustom: true
        ),
        WorkoutTemplate(
            id: "personal.leg",
            posterWords: ["LEG", "DAY"],
            accentRaw: "silver",
            title: "腿训练",
            level: "进阶",
            estimatedMinutes: 55,
            categories: ["分化训练"],
            focus: .legs,
            exercises: [
                PlannedExercise(name: "深蹲", sets: 4, reps: "8")
            ],
            isCustom: true
        ),
        WorkoutTemplate(
            id: "personal.back",
            posterWords: ["BACK", "DAY"],
            accentRaw: "silver",
            title: "背训练",
            level: "进阶",
            estimatedMinutes: 50,
            categories: ["分化训练"],
            focus: .back,
            exercises: [
                PlannedExercise(name: "引体向上", sets: 4, reps: "8")
            ],
            isCustom: true
        )
    ]
}
