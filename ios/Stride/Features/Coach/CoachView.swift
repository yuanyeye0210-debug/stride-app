import SwiftUI

struct CoachView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var ai: AISettings

    @State private var input = ""
    @State private var sending = false
    @State private var retryAttempt: Int?
    @State private var activeTask: Task<Void, Never>?
    @State private var replyToken = 0
    @State private var appliedPlanTurnIDs: Set<UUID> = []
    @State private var appliedWorkoutTurnIDs: Set<UUID> = []
    @State private var likedTurnIDs: Set<UUID> = []
    @State private var speakingTurnID: UUID? = nil
    @State private var showQuickPrompts = false
    @State private var toast: String?

    private var messages: [ChatTurn] { store.state.chats }

    private var userCount: Int {
        messages.filter { $0.role == .user }.count
    }

    private var remaining: Int {
        Gate.coachRemaining(used: userCount)
    }

    var body: some View {
        ZStack {
            ScreenBackground()

            VStack(spacing: 0) {
                header
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            if messages.count <= 1 {
                                suggestions
                            }
                            ForEach(messages) { turn in
                                bubble(turn)
                                    .id(turn.id)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.94)),
                                        removal: .opacity
                                    ))
                            }
                            if sending {
                                typing
                                    .id("typing")
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, Metrics.page)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                        .animation(.spring(response: 0.34, dampingFraction: 0.8), value: messages.count)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: sending)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: messages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(messages.last?.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: sending) { _, isSending in
                        if isSending {
                            withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                        }
                    }
                }
                if showQuickPrompts {
                    quickPromptsTray
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                composer
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: showQuickPrompts)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.success, trigger: replyToken)
        .onDisappear { activeTask?.cancel() }
        .toast($toast)
    }

    // MARK: - 头部（WHOOP AI 极光弥散顶栏 + 新开对话）

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                AuroraBannerBackground()
                    .clipShape(Circle())
                    .frame(width: 32, height: 32)
                Image(systemName: "sparkles")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(Color.white)
                    .symbolEffect(.pulse, isActive: sending)
            }
            Text(ai.isConfigured ? "AI 教练 · Gemini" : "AI 教练 · 本地")
                .font(.system(size: 15.5, weight: .bold))
                .foregroundStyle(Palette.text)
            Spacer()
            if messages.count > 1 {
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        store.clearChat()
                    }
                    toast = "已开启新一轮对话"
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.textDim)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Palette.cardHigh))
                }
                .buttonStyle(.strideSpin)
                .accessibilityLabel("清空对话")
            }
            HStack(spacing: 3) {
                Text("余")
                Text("\(remaining)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.green)
                    .numericRoll(value: remaining, countsDown: true)
                Text("次")
            }
            .font(.system(size: 12))
            .foregroundStyle(Palette.textFaint)
        }
        .frame(height: 52)
        .padding(.horizontal, Metrics.page)
        .background(
            ZStack {
                Palette.bg
                AuroraBannerBackground()
                    .opacity(0.14)
            }
        )
        .overlay(Rectangle().fill(Palette.stroke).frame(height: 0.5), alignment: .bottom)
    }

    // MARK: - 建议

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("试试这样问")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.textFaint)
            ForEach(suggested, id: \.self) { text in
                Button {
                    input = text
                } label: {
                    Text(text)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Palette.card))
                        .overlay(Capsule().strokeBorder(Palette.stroke, lineWidth: 1))
                }
                .buttonStyle(.stridePress)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
    }

    private var suggested: [String] {
        [
            "帮我生成下周训练课表",
            "今天练什么？",
            "卧推 62.5 做了 8 次，下次加多少？",
            "这周睡得很差，要不要减载？",
            "我还差多少蛋白？"
        ]
    }

    // MARK: - 气泡与内嵌方案卡片

    private func bubble(_ turn: ChatTurn) -> some View {
        let parsed = turn.role == .coach
            ? CoachEngine.parseStructuredReply(turn.text)
            : nil
        let showsFullWidthCard = turn.attachedPlan != nil || parsed?.workoutCard != nil

        return HStack {
            if turn.role == .user { Spacer(minLength: 44) }

            VStack(alignment: .leading, spacing: 10) {
                if turn.role == .user {
                    userTextBubble(turn.text)
                } else if let parsed {
                    coachStructuredContent(turnID: turn.id, rawText: turn.text, parsed: parsed)
                }

                if let plan = turn.attachedPlan {
                    planCard(plan, turnID: turn.id)
                }
            }

            if turn.role == .coach && !showsFullWidthCard {
                Spacer(minLength: 32)
            }
        }
    }

    private func userTextBubble(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14.5))
            .foregroundStyle(Color.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            .textSelection(.enabled)
            .contextMenu {
                Button {
                    UIPasteboard.general.string = text
                    toast = "已复制"
                } label: {
                    Label("复制内容", systemImage: "doc.on.doc")
                }
                Button {
                    triggerSend(text: text)
                } label: {
                    Label("再问一次", systemImage: "arrow.clockwise")
                }
            }
    }

    @ViewBuilder
    private func coachStructuredContent(turnID: UUID, rawText: String, parsed: CoachReplyStructure) -> some View {
        let cleanCopy = CoachEngine.sanitizePlainText(rawText)
        VStack(alignment: .leading, spacing: 8) {
            if let card = parsed.workoutCard {
                if !parsed.intro.isEmpty {
                    coachTextBubble(parsed.intro, copyText: cleanCopy)
                        .padding(.trailing, 32)
                }
                inlineWorkoutCard(card, turnID: turnID, copyText: cleanCopy)
                if !parsed.outro.isEmpty {
                    coachTextBubble(parsed.outro, copyText: cleanCopy)
                        .padding(.trailing, 32)
                }
            } else {
                coachTextBubble(
                    parsed.intro.isEmpty ? cleanCopy : parsed.intro,
                    copyText: cleanCopy
                )
            }
            coachActionRow(turnID: turnID, copyText: cleanCopy)
        }
    }

    private func coachActionRow(turnID: UUID, copyText: String) -> some View {
        let liked = likedTurnIDs.contains(turnID)
        let speaking = speakingTurnID == turnID
        return HStack(spacing: 8) {
            Button {
                UIPasteboard.general.string = copyText
                toast = "回复已复制"
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Palette.textDim)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Palette.cardHigh))
            }
            .buttonStyle(.stridePress)

            Button {
                if speaking {
                    speakingTurnID = nil
                } else {
                    speakingTurnID = turnID
                    RunVoiceCoach.shared.speak(copyText)
                    toast = "正在语音朗读教练建议"
                }
            } label: {
                Image(systemName: speaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(speaking ? Palette.purple : Palette.textDim)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Palette.cardHigh))
            }
            .buttonStyle(.strideStepper(accent: Palette.purple))

            Button {
                if liked {
                    likedTurnIDs.remove(turnID)
                } else {
                    likedTurnIDs.insert(turnID)
                    toast = "已标记为有帮助"
                }
            } label: {
                Image(systemName: liked ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(liked ? Palette.green : Palette.textDim)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Palette.cardHigh))
            }
            .buttonStyle(.strideHeart(accent: Palette.green))
        }
        .padding(.leading, 4)
    }

    private func coachTextBubble(_ text: String, copyText: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(Palette.text)
            .lineSpacing(3)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.stroke, lineWidth: 1))
            .textSelection(.enabled)
            .contextMenu {
                Button {
                    UIPasteboard.general.string = copyText
                    toast = "已复制"
                } label: {
                    Label("复制内容", systemImage: "doc.on.doc")
                }
            }
    }

    private func inlineWorkoutCard(_ card: ParsedWorkoutCard, turnID: UUID, copyText: String) -> some View {
        let applied = appliedWorkoutTurnIDs.contains(turnID)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.green)
                Text(card.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(card.metaSummary)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.textDim)
                    .lineLimit(1)
            }

            Rectangle()
                .fill(Palette.stroke)
                .frame(height: 0.5)

            VStack(alignment: .leading, spacing: 9) {
                ForEach(card.items) { item in
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(item.id). \(item.title)")
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundStyle(Palette.text)
                            if !item.subtitle.isEmpty {
                                Text(item.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Palette.textFaint)
                            }
                        }
                        Spacer(minLength: 8)
                        if !item.dose.isEmpty {
                            Text(item.dose)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(Palette.green)
                        }
                    }
                }
            }

            Button {
                let weekday = Calendar.current.component(.weekday, from: Date())
                store.setDayOverride(card.toPlannedDay(weekday: weekday), on: Date())
                appliedWorkoutTurnIDs.insert(turnID)
                replyToken += 1
                toast = "已写入「今日训练计划」"
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: applied ? "checkmark.circle.fill" : "square.and.arrow.down")
                    Text(applied ? "已写入今日计划" : "一键应用到今日计划")
                }
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(applied ? Palette.green : Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(applied ? Palette.green.opacity(0.16) : Palette.green)
                )
            }
            .buttonStyle(.stridePress)
            .disabled(applied)
        }
        .padding(14)
        .card(radius: 18, fill: Palette.cardSoft, stroke: Palette.green.opacity(0.35))
        .contextMenu {
            Button {
                UIPasteboard.general.string = copyText
                toast = "已复制"
            } label: {
                Label("复制完整回复", systemImage: "doc.on.doc")
            }
        }
    }

    private func planCard(_ plan: TrainingPlan, turnID: UUID) -> some View {
        let applied = appliedPlanTurnIDs.contains(turnID)
        let activeDays = plan.days.filter { !$0.rest }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundStyle(Palette.green)
                Text("生成课表 · \(plan.goal.rawValue)（每周 \(activeDays.count) 练）")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(Palette.text)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(activeDays.prefix(5)) { day in
                    Text("· \(day.title)（\(day.exercises.prefix(3).map(\.name).joined(separator: " / "))）")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.textDim)
                        .lineLimit(1)
                }
            }

            Button {
                store.setPlan(plan)
                appliedPlanTurnIDs.insert(turnID)
                replyToken += 1
                toast = "已一键写入「本周计划」"
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: applied ? "checkmark.circle.fill" : "square.and.arrow.down")
                    Text(applied ? "已写入本周计划" : "一键应用到本周计划")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(applied ? Palette.green : Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(applied ? Palette.green.opacity(0.16) : Palette.green)
                )
            }
            .buttonStyle(.stridePress)
            .disabled(applied)
        }
        .padding(13)
        .card(radius: 18, fill: Palette.cardSoft, stroke: Palette.green.opacity(0.35))
    }

    private var typing: some View {
        HStack(spacing: 8) {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { i in
                            let phase = sin(t * 5.0 + Double(i) * 0.9) * 0.5 + 0.5
                            Circle()
                                .fill(Palette.purple)
                                .frame(width: 6.5, height: 6.5)
                                .scaleEffect(0.75 + phase * 0.45)
                                .opacity(0.45 + phase * 0.55)
                        }
                    }
                    Text(retryAttempt.flatMap { AIRetryPolicy.retryStatusText(nextAttempt: $0) } ?? "正在推演训练方案…")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Palette.textDim)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .luxuryCard(radius: 18, accent: Palette.purple)
            }

            Button {
                activeTask?.cancel()
            } label: {
                Text("直接本地回复")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Palette.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Palette.green.opacity(0.14)))
            }
            .buttonStyle(.stridePress)

            Spacer()
        }
    }

    // MARK: - 输入与快捷提问

    private var quickPromptsTray: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("快捷提问")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.textFaint)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggested, id: \.self) { text in
                        Button {
                            showQuickPrompts = false
                            triggerSend(text: text)
                        } label: {
                            Text(text)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Palette.text)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Palette.cardHigh))
                                .overlay(Capsule().strokeBorder(Palette.stroke, lineWidth: 1))
                        }
                        .buttonStyle(.stridePress)
                    }
                }
            }
        }
        .padding(.horizontal, Metrics.page)
        .padding(.vertical, 10)
        .background(Palette.surface)
        .overlay(Rectangle().fill(Palette.stroke).frame(height: 0.5), alignment: .top)
    }

    private var composer: some View {
        HStack(spacing: 8) {
            Button {
                showQuickPrompts.toggle()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .rotationEffect(.degrees(showQuickPrompts ? 45 : 0))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(showQuickPrompts ? Palette.cardHigh : Palette.card))
                    .overlay(Circle().strokeBorder(Palette.stroke, lineWidth: 1))
            }
            .buttonStyle(.stridePress)
            .accessibilityLabel("快捷提问")

            TextField("问点具体的，比如「深蹲该加多少」", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 21, style: .continuous).fill(Palette.card))

            Button {
                triggerSend(text: input)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(input.isEmpty || sending ? Palette.textFaint : Color.white)
                    .frame(width: 42, height: 42)
                    .background {
                        if input.isEmpty || sending {
                            Circle().fill(Palette.card)
                        } else {
                            AuroraBannerBackground().clipShape(Circle())
                        }
                    }
            }
            .buttonStyle(.strideAurora)
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
        }
        .padding(.horizontal, Metrics.page)
        .padding(.vertical, 10)
        .background(Palette.bg)
        .overlay(Rectangle().fill(Palette.stroke).frame(height: 0.5), alignment: .top)
    }

    private func triggerSend(text raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !sending else { return }

        guard Gate.canUseCoach(used: userCount) else {
            toast = "对话额度用完了"
            return
        }

        showQuickPrompts = false
        if raw == input { input = "" }
        store.appendChat(ChatTurn(role: .user, text: text))
        sending = true

        activeTask = Task {
            let result = await CoachEngine.ask(text, store: store, config: ai.config, onRetry: { retryAttempt = $0 })
            await MainActor.run {
                store.appendChat(ChatTurn(role: .coach, text: result.answer, attachedPlan: result.attachedPlan))
                sending = false
                retryAttempt = nil
                replyToken += 1
                activeTask = nil
            }
        }
    }
}
