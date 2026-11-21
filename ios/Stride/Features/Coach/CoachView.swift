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
                composer
            }
        }
        .navigationTitle("教练")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: replyToken)
        .onDisappear { activeTask?.cancel() }
        .toast($toast)
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Palette.purple.opacity(0.16)).frame(width: 38, height: 38)
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.purple)
                    .symbolEffect(.pulse, isActive: sending)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(ai.isConfigured ? "AI 教练 · Gemini" : "AI 教练 · 本地模式")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Text(ai.isConfigured ? "已自动匹配 Gemini 教练与分析模型" : "当前离线，自动使用本机教练引擎")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textFaint)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(remaining)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.green)
                    .numericRoll(value: remaining, countsDown: true)
                Text("剩余")
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.textFaint)
            }
        }
        .padding(.horizontal, Metrics.page)
        .padding(.vertical, 10)
        .background(Palette.bg)
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

    // MARK: - 气泡

    private func bubble(_ turn: ChatTurn) -> some View {
        HStack {
            if turn.role == .user { Spacer(minLength: 44) }

            VStack(alignment: .leading, spacing: 8) {
                Text(turn.text)
                    .font(.system(size: 14.5))
                    .foregroundStyle(turn.role == .user ? Color.black : Palette.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(turn.role == .user ? Color.white : Palette.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(turn.role == .user ? .clear : Palette.stroke, lineWidth: 1)
                    )
                    .textSelection(.enabled)
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = turn.text
                            toast = "已复制"
                        } label: {
                            Label("复制内容", systemImage: "doc.on.doc")
                        }
                        if turn.role == .user {
                            Button {
                                triggerSend(text: turn.text)
                            } label: {
                                Label("再问一次", systemImage: "arrow.clockwise")
                            }
                        }
                    }

                if let plan = turn.attachedPlan {
                    planCard(plan, turnID: turn.id)
                }
            }

            if turn.role == .coach { Spacer(minLength: 44) }
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
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Palette.textDim)
                            .frame(width: 6, height: 6)
                            .opacity(0.4)
                            .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.15), value: sending)
                    }
                }
                Text(retryAttempt.flatMap { AIRetryPolicy.retryStatusText(nextAttempt: $0) } ?? "思考中…")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.textDim)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.card))

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

    // MARK: - 输入

    private var composer: some View {
        HStack(spacing: 9) {
            TextField("问点具体的，比如「深蹲该加多少」", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.card))

            Button {
                triggerSend(text: input)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(input.isEmpty || sending ? Palette.textFaint : Color.black)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(input.isEmpty || sending ? Palette.card : Color.white))
            }
            .buttonStyle(.stridePress)
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
