import Foundation

/// 教练的本地兜底：没配 AI Key 也能给出基于你真实记录的回答。
/// 配了 Key 就走模型，本地逻辑不再参与。
@MainActor
enum CoachEngine {

    static let systemPrompt = """
    你是「步迹 Stride」的私人力量与体能教练，用简体中文与用户自然交流，风格专业、真诚、有温度、像真私教一样懂人话。
    规则：
    1. 若用户只是打招呼（如“你好”“在吗”“早”）、闲聊或表达情绪，请自然友好回应并简要引导今天可以聊什么，不要生硬罗列数字或强行下命令。
    2. 后台状态里的今日摄入或训练如果为 0，先结合当前时间段判断（例如凌晨/上午尚未记录或还没吃早饭是正常的），切勿在对方只打招呼时误判为空腹异常或命令对方“马上吃几千大卡”。
    3. 当用户询问具体训练、配重、饮食缺口、伤病替代或恢复问题时，才结合后台真实记录给出科学、可落地的建议（尽量给出动作、重量、组次或替代方案），不要编造不存在的记录。
    4. 结合上下文连续对话，表达清晰简洁（日常问答 40–180 字即可，复杂规划可分点说明）。
    """

    static func context(store: AppStore) -> String {
        let p = store.state.profile
        var lines: [String] = []
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "zh_CN")
        timeFormatter.dateFormat = "HH:mm"
        let hour = Calendar.current.component(.hour, from: Date())
        let period: String = {
            switch hour {
            case 0..<5: return "凌晨"
            case 5..<9: return "早上"
            case 9..<12: return "上午"
            case 12..<14: return "中午"
            case 14..<18: return "下午"
            default: return "晚上"
            }
        }()
        lines.append("当前本地时间：\(timeFormatter.string(from: Date()))（\(period)）")
        let body = String(format: "%.0fcm / %.1fkg", p.heightCm, p.weightKg)
        lines.append("用户：\(p.nickname)，\(p.age) 岁，\(body)，目标 \(p.goal.rawValue)，经验 \(p.experience.rawValue)，每周 \(p.daysPerWeek) 练。")
        if !p.injuryAvoidAreas.isEmpty {
            lines.append("伤病规避区域：\(p.injuryAvoidAreas.joined(separator: "、"))（给建议时需主动避开对这些部位压力过大的动作）。")
        }

        let recent = store.recentSessions.prefix(4)
        if recent.isEmpty {
            lines.append("最近没有训练记录。")
        } else {
            lines.append("最近训练：")
            for s in recent {
                let ex = s.exercises.prefix(3).map { "\($0.name) \($0.doneSets.count)组" }.joined(separator: "、")
                lines.append("- \(dayString(s.date)) \(s.title)：\(ex)")
            }
        }

        let balance = ProgressiveEngine.weeklySetBalance(sessions: store.state.sessions)
        if !balance.isEmpty {
            let text = balance.sorted { $0.key.rawValue < $1.key.rawValue }
                .map { "\($0.key.rawValue)\($0.value)" }
                .joined(separator: " ")
            lines.append("本周组数：\(text)")
        }

        if let today = store.todaysPlannedDay {
            lines.append("今天计划：\(today.title)")
        }

        let n = store.todayNutrition
        lines.append("今日摄入：\(Int(n.kcal)) kcal / 蛋白 \(Int(n.p))g（目标 \(p.kcalTarget) kcal，蛋白 \(p.proteinTarget)g）")
        return lines.joined(separator: "\n")
    }

    /// 根据提问复杂度自动选择最合适的 Gemini 模型（深层规划/分析走 Pro，日常问答走 Flash）。
    nonisolated static func useCase(for text: String) -> AIUseCase {
        let deepKeywords = ["计划", "周期", "分化", "瓶颈", "评估", "分析", "对比", "减载", "弱项", "1RM", "周期化", "复盘"]
        if text.count >= 36 || deepKeywords.contains(where: { text.contains($0) }) {
            return .coachDeepAnalysis
        }
        return .coachChat
    }

    /// 判断提问是否要求生成可直接写入本周的训练课表。
    nonisolated static func wantsGeneratedPlan(for text: String) -> Bool {
        let lower = text.lowercased()
        let actionWords = ["生成", "排", "制定", "安排", "出一份", "给我一份"]
        let planWords = ["计划", "课表", "训练周", "周练"]
        return actionWords.contains(where: { lower.contains($0) }) && planWords.contains(where: { lower.contains($0) })
    }

    static func ask(_ text: String, store: AppStore, config: AIConfig, onRetry: (@MainActor (Int) -> Void)? = nil) async -> (answer: String, usedAI: Bool, attachedPlan: TrainingPlan?) {
        let shouldAttachPlan = wantsGeneratedPlan(for: text)
        let candidatePlan: TrainingPlan? = shouldAttachPlan
            ? PlanGenerator.generate(
                goal: store.state.profile.goal,
                days: store.state.profile.daysPerWeek,
                experience: store.state.profile.experience
            )
            : nil

        if config.isConfigured {
            do {
                let ragNotes = FitnessKnowledgeBase.ragContext(for: text)
                let ragSection = ragNotes.isEmpty ? "" : "\n\n【步迹专业健身知识库参考（请融合贯通、结合用户记录用人话回复）】\n\(ragNotes)"
                let enrichedSystem = """
                \(systemPrompt)

                【用户后台档案与今日实时状态（仅作参考，请结合时间段自然使用）】
                \(context(store: store))\(ragSection)
                """
                let historyTurns = store.state.chats.dropLast().suffix(8)
                var conversation: [AIClient.Message] = historyTurns.map { turn in
                    AIClient.Message(
                        role: turn.role == .coach ? "assistant" : "user",
                        content: .text(turn.text)
                    )
                }
                conversation.append(AIClient.Message(role: "user", content: .text(text)))

                let selectedUseCase = useCase(for: text)
                let answer = try await AIClient.complete(
                    system: enrichedSystem,
                    messages: conversation,
                    model: selectedUseCase.primaryGeminiModel,
                    config: config,
                    useCase: selectedUseCase,
                    maxTokens: 900,
                    onRetry: onRetry
                )
                return (answer, true, candidatePlan)
            } catch is CancellationError {
                let local = localReply(text, store: store)
                return (local + "\n\n（已切回本机专业知识库即时回复）", false, candidatePlan)
            } catch let aiError as AIError {
                let local = localReply(text, store: store)
                let note: String
                switch aiError {
                case .timeout, .offline:
                    note = "（当前直连云端 Gemini 超时，已使用本机健身知识库为您回复；开启外网可解锁云端自由推演）"
                default:
                    note = "（云端模型暂忙：\(aiError.localizedDescription)，已使用本机健身知识库回复）"
                }
                return (local + "\n\n\(note)", false, candidatePlan)
            } catch {
                let local = localReply(text, store: store)
                return (local + "\n\n（云端连接失败：\(error.localizedDescription)，以上为本机知识库解答。）", false, candidatePlan)
            }
        }
        return (localReply(text, store: store), false, candidatePlan)
    }

    // MARK: - 本地规则 + 全量健身知识库驱动

    static func localReply(_ text: String, store: AppStore) -> String {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if ["你好", "hi", "hello", "嗨", "哈喽", "在吗", "早", "晚上好"].contains(where: { q == $0 || q.hasPrefix($0) }) && q.count <= 12 {
            let todayTitle = store.todaysPlannedDay?.title ?? "自由安排"
            let n = store.todayNutrition
            let p = store.state.profile
            return """
            在的，\(p.nickname)！今天计划是「\(todayTitle)」，已记录 \(Int(n.kcal))/\(p.kcalTarget) kcal、蛋白 \(Int(n.p))g。
            无论是动作技术瓶颈、减脂配餐、外卖怎么选还是伤病替代，直接问我就行。
            """
        }

        if (q.contains("gemini") || q.contains("ai") || q.contains("模型") || q.contains("为什么") || q.contains("怎么"))
            && (q.contains("超时") || q.contains("连不上") || q.contains("不回") || q.contains("失败") || q.contains("断网")) {
            return """
            这是因为 App 需要向海外接口 generativelanguage.googleapis.com 请求 Gemini 大模型，在国内纯 5G/Wi-Fi 无外网环境下数据包会被拦截挂起，超过 12 秒就会自动断线保护不让界面卡死。
            我已经把完整的循证健身知识库和 1,324 个动作要领内置在本机里，即便不连外网也能随时直接回答你的训练、饮食和伤病问题；开启外网环境后会自动切回云端高速 Gemini 模型。
            """
        }

        for name in ["卧推", "深蹲", "硬拉", "划船", "推举", "引体"] where q.contains(name) {
            let base = exerciseAdvice(name: name, store: store)
            let rag = FitnessKnowledgeBase.retrieve(for: text, limit: 1)
            if let tip = rag.first {
                return "\(base)\n\n【\(tip.title)】\(tip.content)"
            }
            return base
        }

        if q.contains("今天") || q.contains("练什么") {
            if let day = store.todaysPlannedDay {
                let list = day.exercises.prefix(4).map { "\($0.name) \($0.sets)×\($0.reps)" }.joined(separator: "，")
                return "今天计划是「\(day.title)」：\(list)。组间休息 90 秒，主动作可放到 150 秒。"
            }
            return "今天暂无固定安排。推荐要么做 20 分钟 Zone 2 快走 + 关节活动度，要么开一节推/拉/腿自选训练。"
        }

        // 优先从本机 24 条专业运动科学知识库 + 1,324 动作库做 RAG 检索回答
        let matchedKnowledge = FitnessKnowledgeBase.retrieve(for: text, limit: 2)
        let matchedExercises = Array(ExerciseCatalogStore.shared.filter(query: text, bodyPart: nil, equipment: nil).prefix(1))

        if !matchedKnowledge.isEmpty {
            let p = store.state.profile
            var parts = matchedKnowledge.map { "【\($0.title)】\n\($0.content)" }
            if !p.injuryAvoidAreas.isEmpty {
                parts.append("（已记录你的重点规避部位：\(p.injuryAvoidAreas.joined(separator: "、"))，实操时如遇关节不适请果断降重或换用无痛替代。）")
            }
            if let ex = matchedExercises.first {
                let stepTip = ex.steps.prefix(2).joined(separator: " ")
                parts.append("参考动作「\(ex.displayTitle)」：\(stepTip)")
            }
            return parts.joined(separator: "\n\n")
        }

        if let ex = matchedExercises.first {
            let stepTip = ex.steps.prefix(3).joined(separator: " ")
            return "动作库为你匹配到「\(ex.displayTitle)」（目标肌群：\(ex.targetZH)，器械：\(ex.equipmentZH)）。\n动作要领：\(stepTip)"
        }

        if q.contains("睡") || q.contains("累") || q.contains("疲") || q.contains("没劲") {
            let vols = store.weeklyVolume.map(\.volume)
            if ProgressiveEngine.needsDeload(weeklyVolumes: vols) {
                let last = vols.last ?? 0
                let prev = max(1, vols.dropLast().last ?? 1)
                let dropPercent = Int((1 - last / prev) * 100)
                return """
                这周训练量比上周掉了 \(dropPercent)%，确实是该减载的信号。
                这周所有主动作降到 70% 重量、组数砍一半，把睡眠补回来，下周再顶。
                """
            }
            return """
            状态差就别硬上大重量。今天做主项 3 组 × 6 次，重量取平时 80%，做完还有余力就收工。
            训练量可以少，动作质量不能降。
            """
        }

        if q.contains("吃") || q.contains("热量") || q.contains("蛋白") {
            let n = store.todayNutrition
            let p = store.state.profile
            let left = max(0, p.kcalTarget - Int(n.kcal))
            let proteinLeft = max(0, p.proteinTarget - Int(n.p))
            return """
            今天已摄入 \(Int(n.kcal)) kcal，还剩 \(left) kcal；蛋白还差 \(proteinLeft)g。
            补法：\(proteinLeft)g 蛋白 ≈ \(Int(Double(proteinLeft) / 0.22))g 鸡胸，或 2–3 勺乳清蛋白粉。
            """
        }

        // 未命中任何专题时再给本周训练概览与可提问指引
        let week = store.weekSessions
        let sets = week.reduce(0) { $0 + $1.totalSets }
        let vol = week.reduce(0) { $0 + $1.totalVolume }
        let balance = ProgressiveEngine.weeklySetBalance(sessions: store.state.sessions)
        let weakest = balance.min { $0.value < $1.value }?.key.rawValue ?? "腿"

        return """
        本周目前 \(week.count) 练、\(sets) 组、总容量 \(Int(vol)) kg（可关注弱项：\(weakest)）。
        你可以直接问我具体训练或饮食问题，例如：
        ·「卧推卡在70kg上不去怎么办」
        ·「肩痛或腰酸怎么替代练胸练背」
        ·「减脂期外卖火锅怎么吃、肌酸怎么补」
        """
    }

    private static func exerciseAdvice(name: String, store: AppStore) -> String {
        let history = store.history(for: name)
        guard let last = history.last else {
            return "还没有\(name)的记录。第一次先做 3 组 × 8 次，重量选能留 2 次余力的，我记下来之后再给建议。"
        }
        let best = history.map(\.e1rm).max() ?? 0
        let recentSets = store.recentSessions
            .flatMap(\.exercises)
            .first { $0.name == name }?
            .doneSets ?? []

        let suggestion = ProgressiveEngine.suggest(
            lastSets: recentSets,
            referenceWeight: last.e1rm * 0.78,
            referenceReps: 8,
            goal: store.state.profile.goal
        )

        return """
        \(name)：上次估算 1RM \(Int(last.e1rm)) kg，历史最好 \(Int(best)) kg。
        这次建议 \(suggestion.headline)：\(suggestion.sets) 组 × \(suggestion.reps) 次 @ \(format(suggestion.weight)) kg。
        \(suggestion.detail)
        """
    }

    private static func format(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    private static func dayString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: d)
    }
}
