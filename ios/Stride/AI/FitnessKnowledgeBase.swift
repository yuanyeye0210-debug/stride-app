import Foundation

// MARK: - 专业健身知识库与本地 RAG 检索引擎

/// 单条循证运动科学知识条目（覆盖力量训练、营养、伤病替代、补剂、有氧与恢复）。
struct FitnessKnowledgeEntry: Identifiable, Hashable {
    let id: String
    let category: String
    let title: String
    let keywords: [String]
    let content: String
}

enum FitnessKnowledgeBase {

    /// 全维度循证运动科学知识库（24 条核心条目，基于 NSCA / ACSM / ISSN 指南整理）。
    static let entries: [FitnessKnowledgeEntry] = [
        // MARK: 1. 肌肥大与容量管理
        FitnessKnowledgeEntry(
            id: "hypertrophy_volume",
            category: "肌肥大原理",
            title: "周有效训练容量（MEV / MAV）与训练频率",
            keywords: ["增肌", "肌肥大", "多少组", "容量", "频率", "一周练几次", "练不长", "分化", "组数"],
            content: "每个目标肌群每周完成 10–18 组接近力竭的有效工作组（RIR 1–3）处于黄金增肌区间（MAV）；新手每周 8–10 组（MEV 以上）即可显著进步。将同一肌群拆分为每周 2 次刺激通常优于一周 1 次大轰炸，动作质量更高、恢复更快、蛋白合成窗口更频繁。"
        ),
        FitnessKnowledgeEntry(
            id: "double_progression",
            category: "渐进超负荷",
            title: "双进阶法与安全加重时机",
            keywords: ["加重", "加多少", "瓶颈", "卡住", "上不去", "渐进", "超负荷", "次数", "重量", "平台期"],
            content: "突破重量推荐「双进阶法」：例如目标 3 组 × 8–12 次，当 3 组都能以标准幅度做满 12 次且留 1 次余力时，下次训练上肢加 2.5 kg（哑铃每侧 +1–2 kg）、下肢加 2.5–5 kg，次数回落到 8 次重新往上爬。控制离心 2–3 秒与顶峰微停同样属于高质量进阶，不必每练必强冲极限。"
        ),
        FitnessKnowledgeEntry(
            id: "rpe_rir",
            category: "强度控制",
            title: "RPE / RIR 强度自调节与组间休息",
            keywords: ["rpe", "rir", "力竭", "休息", "组间", "歇多久", "强度", "状态差"],
            content: "绝大多数工作组建议落在 RPE 7.5–9（即 RIR 1–2，还能标准完成 1–2 次），仅在安全的孤立动作或最后一组逼近力竭以防过度疲劳。组间休息：深蹲/硬拉/卧推等大复合动作休息 2–3 分钟，中等复合动作 90–120 秒，孤立小肌群 60–90 秒；休息太短会显著拉低后几组有效次数。"
        ),
        FitnessKnowledgeEntry(
            id: "deload",
            category: "疲劳管理",
            title: "减载周（Deload）判定与执行方案",
            keywords: ["减载", "疲劳", "累", "没劲", "睡不好", "状态差", "力量掉了", "恢复", "过度训练"],
            content: "当连续 2 周主项重量下滑、关节肌腱隐隐发紧、训练欲望骤降或持续睡眠不足时，应果断安排 5–7 天减载周：保留原有动作模式避免神经生疏，但将工作组数减半（或重量降至平时的 65–70%，RPE ≤ 6），保证睡眠与蛋白摄入，下周往往会迎来超量恢复。"
        ),

        // MARK: 2. 动作技术精讲与瓶颈突破
        FitnessKnowledgeEntry(
            id: "bench_press",
            category: "动作技术",
            title: "卧推技术细节与平台期突破",
            keywords: ["卧推", "胸", "推不动", "70kg", "起桥", "胸肌", "平板卧推", "上斜", "胸没感觉"],
            content: "卧推核心：双脚踩实地面产生腿驱、肩胛骨后缩下沉贴紧凳面、胸椎自然微起桥、手腕保持中立不后折、大臂与躯干呈 45°–60° 夹角，杠铃落于乳头下沿。若卡在底端起不来，加练 2 秒暂停卧推和哑铃卧推增大胸肌底端启动力量；若卡在中后段锁定困难，加强窄距卧推、双杠臂屈伸与绳索下压；若只有前束和三头酸，先做夹胸预疲劳并放慢离心。"
        ),
        FitnessKnowledgeEntry(
            id: "squat",
            category: "动作技术",
            title: "深蹲技术要点与常见代偿纠正",
            keywords: ["深蹲", "腿", "股四", "屁股眨眼", "膝盖", "蹲不下去", "脚踝", "下肢", "屈髋"],
            content: "深蹲核心：吸气入腹做 360° 瓦式核心加压、膝盖顺着脚尖方向稳定外展、重心稳落在整个足中（不踮脚不后坐），下蹲至髋关节略低于膝盖。蹲不深或脚跟翘起多为踝背屈受限，可在脚跟垫 1.25–2.5 kg 小片或换硬底鞋；底端屁股眨眼检查是否超出了当前髋屈幅度，可多用高脚杯深蹲、保加利亚分腿蹲和暂停深蹲打牢下肢与核心控制。"
        ),
        FitnessKnowledgeEntry(
            id: "deadlift",
            category: "动作技术",
            title: "传统硬拉与罗马尼亚硬拉（RDL）要点",
            keywords: ["硬拉", "后链", "腰酸", "圆背", "拉不动", "握力", "罗马尼亚", "rdl", "臀腿"],
            content: "传统硬拉：杠铃贴近胫骨正中，起拉前先沉肩收紧背阔肌（像腋下夹橙子）拉紧杠铃空隙、保持脊柱中立、用“双脚把地板蹬下去”启动，避免腰椎屈曲或顶部过度挺腰反弓。罗马尼亚硬拉重点是屈髋向后推臀，膝微屈锁定角度，下放到腘绳肌强烈拉伸感即起。握力先竭时可大胆使用助力带。"
        ),
        FitnessKnowledgeEntry(
            id: "pull_back",
            category: "动作技术",
            title: "引体向上从零解锁与练背发力感",
            keywords: ["引体", "背", "背阔肌", "高位下拉", "划船", "拉不上去", "手臂酸", "圆肩", "翼状肩"],
            content: "练背总觉手臂二头酸、背没感觉，关键是启动前先做肩胛骨下沉与微后缩，采用虚握或助力带减小前臂抓握代偿，想象“用手肘往两侧裤兜后下方带”而非单纯用手把重量掰向胸口。引体从零解锁建议：顶峰跳起 4–5 秒慢放离心 + 弹力带辅助引体 + 澳式划船，每周 2–3 次推进。"
        ),
        FitnessKnowledgeEntry(
            id: "shoulders_arms",
            category: "动作技术",
            title: "肩部立体感与手臂维度打造",
            keywords: ["肩", "侧平举", "三角肌", "斜方", "手臂", "二头", "三头", "弯举", "蝴蝶袖", "溜肩"],
            content: "侧平举总是斜方发力，应改为轻重量（12–20 次高次数）、大臂在躯干前 30° 肩胛骨平面抬起、想象把哑铃往两侧远方“推甩出去”而非往上耸、肘不高于肩。后束重点练绳索面拉与反向飞鸟改善圆肩。肱三头肌占手臂近 2/3 维度，必须兼顾过顶臂屈伸（拉伸长头）与绳索下压；二头建议搭配上斜哑铃弯举与锤式弯举。"
        ),
        FitnessKnowledgeEntry(
            id: "glutes_core",
            category: "动作技术",
            title: "练臀不粗腿与深层核心塑形",
            keywords: ["臀", "翘臀", "臀推", "不粗腿", "腹肌", "马甲线", "核心", "平板支撑", "卷腹"],
            content: "高效孤立翘臀优先选杠铃臀推（髋伸顶峰收缩，小腿垂直地面避免大腿前侧代偿）、罗马尼亚硬拉、身体微前倾的保加利亚分腿蹲和绳索髋外展（强化臀中肌饱满）。腹肌线条显露主要看体脂，训练上用负重绳索卷腹和悬垂举腿给腹直肌渐进阻力，辅以死虫、鸟狗与健腹轮增强核心稳定。"
        ),

        // MARK: 3. 营养、减脂、增肌与外食
        FitnessKnowledgeEntry(
            id: "fat_loss_nutrition",
            category: "减脂营养",
            title: "科学减脂热量缺口与保肌法则",
            keywords: ["减脂", "减肥", "刷脂", "掉秤", "热量缺口", "瘦", "平台", "饥饿", "节食", "体脂"],
            content: "可持续减脂每日热量缺口控制在 TDEE 减去 300–500 kcal，对应每周体重下降约 0.5%–1%。切忌极端节食导致代谢适应与掉肌肉：减脂期蛋白质反而建议提高至 1.8–2.2 g/kg 体重，继续坚持中大重量力量训练作为“留肌信号”，配合每日 8,000–10,000 步日常非运动消耗。"
        ),
        FitnessKnowledgeEntry(
            id: "bulk_nutrition",
            category: "增肌营养",
            title: "干净增肌热量盈余与瘦子增重策略",
            keywords: ["增重", "太瘦", "吃不胖", "增肌饮食", "盈余", "蛋白", "碳水"],
            content: "干净增肌建议每日热量盈余 200–350 kcal（每月稳步增重约 0.5–1 kg，少长多余脂肪）。蛋白质 1.6–2.0 g/kg，脂肪 0.8–1.0 g/kg，其余热量主要分配给优质碳水（米面、燕麦、土豆、香蕉）支撑高训练容量。胃口小难以吃够的瘦子可用高热量奶昔（牛奶+乳清+燕麦+香蕉+花生酱）轻松补足。"
        ),
        FitnessKnowledgeEntry(
            id: "macros_protein",
            category: "营养窗口",
            title: "三大营养素分配、练前练后加餐与碳水循环",
            keywords: ["蛋白质", "碳水", "脂肪", "练前吃", "练后吃", "碳循环", "吃什么", "蛋白粉", "鸡胸"],
            content: "每日蛋白建议分 3–4 餐均匀摄入（每餐 25–45g），刺激全天多次肌肉蛋白合成。练前 1–2 小时吃易消化碳水配适量蛋白（如全麦吐司+香蕉+蛋白），避免过多油脂影响消化；练后 2 小时内及时补蛋白与碳水回填糖原。实施碳水循环时：练腿/背等大负荷日适当提高碳水，休息日下调碳水并略增健康脂肪。"
        ),
        FitnessKnowledgeEntry(
            id: "eating_out",
            category: "外食指南",
            title: "外卖、食堂、火锅与便利店健身选餐",
            keywords: ["外卖", "食堂", "聚餐", "火锅", "麻辣烫", "便利店", "宵夜", "奶茶", "外食"],
            content: "外食/外卖选餐原则：先锁定高蛋白低脂主菜（去皮白切鸡、卤牛肉、清蒸鱼、虾仁、鸡蛋、豆腐），主食选米饭/玉米/杂粮避开炒饭炒粉和油炸面食，菜品偏油时备热水略涮。火锅选清汤或番茄锅，吃牛肉卷/鲜虾/巴沙鱼/绿叶菜配醋+蒜泥蘸料；麻辣烫不喝汤、多选瘦肉鸡蛋菌菇蔬菜少丸子；便利店首选即食鸡胸、茶叶蛋、无糖豆浆、纯奶或金枪鱼饭团。"
        ),
        FitnessKnowledgeEntry(
            id: "hydration",
            category: "补水电解质",
            title: "每日科学饮水与训练出汗补液",
            keywords: ["喝水", "饮水", "口渴", "抽筋", "电解质", "出汗"],
            content: "日常基础饮水约 30–35 ml/kg 体重（70kg 约 2100–2500 ml），每进行 1 小时中高强度出汗训练再额外补水 500–800 ml。夏季或高强度长跑超 60 分钟时，及时补充含钠/钾的电解质水能预防抽筋、维持耐力与神经募集效率。"
        ),

        // MARK: 4. 伤病分级与关节保护替代矩阵
        FitnessKnowledgeEntry(
            id: "pain_triage",
            category: "伤病防护",
            title: "延迟性酸痛（DOMS）vs 关节锐痛鉴别",
            keywords: ["痛", "疼", "拉伤", "扭伤", "受伤", "弹响", "酸痛", "doms"],
            content: "精准区分：① 肌肉双侧对称的酸胀或轻压痛（DOMS）多为正常训练适应，可降低 20% 负荷或换部位练；② 关节内部的刺痛、锐痛、卡顿、弹响伴痛或麻木放射感是明确的红灯警告，当天立即停掉诱发动作换无痛替代项，连续 3–5 天不缓解或有肿胀建议线下就医评估。"
        ),
        FitnessKnowledgeEntry(
            id: "shoulder_rehab",
            category: "伤病防护",
            title: "肩前痛/肩峰撞击的安全替代方案",
            keywords: ["肩痛", "肩膀疼", "肩峰", "撞击", "肩弹响", "卧推肩痛"],
            content: "肩前痛或推举弹响时：暂停大重量杠铃平板卧推、颈后推举和过深双杠臂屈伸。改为对肩关节更友好的对握/中立握哑铃卧推、地板卧推（限制肩过度后伸）、微斜板哑铃推举与地雷管单臂推，热身必做绳索面拉与弹力带肩外旋加固肩袖。"
        ),
        FitnessKnowledgeEntry(
            id: "lower_back_rehab",
            category: "伤病防护",
            title: "腰部/下背不适的护腰练法与替代动作",
            keywords: ["腰痛", "腰疼", "下背", "腰突", "闪腰", "硬拉腰疼", "深蹲腰疼"],
            content: "下背僵痛或腰椎敏感期，避开大重量杠铃背蹲、传统硬拉和无支撑俯身杠铃划船等纵向剪切负荷。改用带胸垫的器械划船/上斜哑铃划船、高位下拉、保加利亚分腿蹲、器械腿举、坐姿腿弯举/腿屈伸，辅以死虫、侧桥与鸟狗式强化脊柱抗旋转核心。"
        ),
        FitnessKnowledgeEntry(
            id: "knee_rehab",
            category: "伤病防护",
            title: "膝盖前侧痛/跑者膝的替代与肌腱强化",
            keywords: ["膝盖痛", "膝疼", "跑者膝", "髌骨", "半月板", "上下楼痛"],
            content: "膝前侧酸痛时，暂缓爆发跳跃与全幅度重蹲。改用箱式深蹲控制下放幅度，并将下肢重心偏向髋主导的罗马尼亚硬拉、杠铃臀推，热身加入跑步机倒走或无痛角度靠墙静蹲（每次 30–45 秒）提升髌腱耐受度，并强化臀中肌防止跑蹲膝内扣。"
        ),
        FitnessKnowledgeEntry(
            id: "wrist_elbow_rehab",
            category: "伤病防护",
            title: "手腕折压痛与网球肘/高尔夫球肘调整",
            keywords: ["手腕痛", "手腕疼", "手肘", "肘痛", "网球肘", "高尔夫球肘", "前臂痛"],
            content: "推类动作手腕痛通常源于杠铃重心没压在掌根、手腕过度背伸；改用护腕并调整握位让前臂与掌骨成直线，或暂时用哑铃/器械替代直杆。弯举或下拉引起肘内/外侧牵扯痛时，将直杆换成曲杆（EZ-Bar）、绳索锤式握或对握引体，放慢离心并放松前臂屈伸肌群。"
        ),

        // MARK: 5. 科学补剂、有氧与恢复
        FitnessKnowledgeEntry(
            id: "supplements_guide",
            category: "科学补剂",
            title: "循证有效补剂榜单与安全剂量",
            keywords: ["补剂", "肌酸", "氮泵", "蛋白粉", "鱼油", "咖啡因", "bcaa", "左旋", "维d", "镁"],
            content: "真正有强循证支持的补剂：① 一水肌酸：每天 3–5g，无需冲击期，连续 3 周饱和可提升爆发力与训练容量（体重微涨 0.5–1kg 为肌肉储水）；② 乳清蛋白粉：纯粹方便达标的优质蛋白质；③ 咖啡因：练前 30–60 分钟约 100–200mg 提神增效，睡前 6–8 小时停用护睡眠；④ 鱼油与维生素 D3。BCAA 和左旋肉碱在总蛋白与热量缺口合理时收益极低。"
        ),
        FitnessKnowledgeEntry(
            id: "running_cardio",
            category: "有氧耐力",
            title: "Zone 2 有氧二区、80/20 法则与力量衔接",
            keywords: ["跑步", "有氧", "配速", "心率", "二区", "zone2", "maf", "喘", "耐力", "马拉松", "步频", "先练力量还是有氧"],
            content: "跑得久、心肺稳优先遵循 80/20 法则：80% 跑量处于轻松聊天、微喘的 Zone 2 有氧二区（最大心率 65–75%），20% 穿插间歇或乳酸阈节奏跑，日常步频向 175–185 靠拢减震护膝。力量与有氧同一天时，想保力量和围度推荐「先力量、后有氧」，或上下午错开 6 小时以上。"
        ),
        FitnessKnowledgeEntry(
            id: "sleep_recovery",
            category: "恢复睡眠",
            title: "睡眠不足对皮质醇、激素与训练的调整",
            keywords: ["熬夜", "失眠", "睡不够", "睡眠", "恢复慢", "皮质醇"],
            content: "肌肉组织在深度睡眠时才进行高效率修复。长期睡不足 6 小时会导致皮质醇升高、饥饿素波动和神经募集下降。熬夜后的训练日切勿硬冲极限 1RM，主动将主力重量调低至平时的 75–80%、适当缩减几组以保证动作不变形。"
        ),
        FitnessKnowledgeEntry(
            id: "fitness_myths",
            category: "常见误区",
            title: "局部减脂、体重波动、女生练铁与出汗辟谣",
            keywords: ["瘦肚子", "局部减脂", "瘦腿", "体重涨了", "大体重", "出汗", "肌肉女", "女生练力量", "空腹有氧"],
            content: "常见科学事实：① 无法局部减脂，腹部赘肉只能靠整体热量缺口配合腹肌强化来改善比例；② 体重单日浮动 1–2 kg 多因碳水储水、盐分钠潴留、练后微水肿或生理期，看 7 天均值最准；③ 出汗多只是散热并非燃烧更多脂肪；④ 女性正常练铁只会让体态更紧致挺拔；⑤ 空腹有氧与餐后有氧减脂效率接近，选体感舒适易坚持的。"
        ),
        FitnessKnowledgeEntry(
            id: "home_travel",
            category: "居家徒手",
            title: "无器械/出差 20 分钟全身高效徒手方案",
            keywords: ["居家", "在家", "出差", "没器械", "徒手", "俯卧撑", "没时间", "20分钟"],
            content: "酒店/居家 20 分钟全身高效循环（共 4 轮，组间歇 90 秒）：① 标准或上斜俯卧撑 10–15 次；② 单腿保加利亚分腿蹲（搭沙发/床沿）每侧 12 次；③ 俯身超人背伸或毛巾门框划船 15 次；④ 单腿臀桥每侧 12 次；⑤ 平板支撑或死虫 45 秒。忙碌期保持最低有效剂量也能稳住 90% 肌肉量。"
        )
    ]

    /// 基于关键词匹配与中文双字重合度的轻量本地 RAG 检索。
    static func retrieve(for query: String, limit: Int = 3) -> [FitnessKnowledgeEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }

        let bigrams = chineseBigrams(from: q)
        let scored: [(entry: FitnessKnowledgeEntry, score: Int)] = entries.compactMap { entry in
            var score = 0
            for kw in entry.keywords {
                let lowerKW = kw.lowercased()
                if q.contains(lowerKW) {
                    score += lowerKW.count >= 2 ? 12 : 6
                }
            }
            if q.contains(entry.category.lowercased()) { score += 6 }
            for bg in bigrams {
                if entry.title.contains(bg) { score += 4 }
                else if entry.content.contains(bg) { score += 1 }
            }
            return score >= 5 ? (entry, score) : nil
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map(\.entry)
    }

    /// 组装注入给大模型的「专业健身知识库 + 57 核心真人视频动作库」RAG 参考上下文。
    static func ragContext(for query: String) -> String {
        let matchedKnowledge = retrieve(for: query, limit: 3)
        let matchedExercises = Array(ExerciseCatalogStore.shared.filter(query: query, bodyPart: nil, equipment: nil).prefix(2))

        var sections: [String] = []
        if !matchedKnowledge.isEmpty {
            let lines = matchedKnowledge.map { "【\($0.category) · \($0.title)】\($0.content)" }
            sections.append(lines.joined(separator: "\n"))
        }
        if !matchedExercises.isEmpty {
            let exLines = matchedExercises.map { ex in
                let stepTip = ex.steps.prefix(2).joined(separator: " ")
                return "【动作库参考 · \(ex.displayTitle)】部位：\(ex.bodyPartZH) / 器械：\(ex.equipmentZH) / 要领：\(stepTip)"
            }
            sections.append(exLines.joined(separator: "\n"))
        }
        return sections.joined(separator: "\n")
    }

    private static func chineseBigrams(from text: String) -> [String] {
        let chars = Array(text).filter { ch in
            ch.unicodeScalars.allSatisfy { (0x4E00...0x9FFF).contains($0.value) }
        }
        guard chars.count >= 2 else { return [] }
        var result: [String] = []
        for i in 0..<(chars.count - 1) {
            result.append(String([chars[i], chars[i + 1]]))
        }
        return result
    }
}
