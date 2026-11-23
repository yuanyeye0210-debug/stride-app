import SwiftUI

struct PlanScheduleView: View {
    @EnvironmentObject private var store: AppStore

    var onCreateTemplate: () -> Void
    var onQuickStart: () -> Void

    @State private var anchorDate = Date()
    @State private var expandedMonth = false
    @State private var selectedDate: Date? = nil
    @State private var activeDraft: SessionDraft? = nil
    @State private var showSession = false
    @State private var showReorder = false
    @State private var showRhythmSheet = false
    @State private var showRepeatDialog = false
    @State private var showGuideSheet = false
    @State private var showSearchSheet = false
    @State private var selectedTemplate: WorkoutTemplate? = nil
    @State private var detailSession: WorkoutSession? = nil
    @State private var toast: String?

    private let cal = Calendar.current
    private let monFirstNames = ["一", "二", "三", "四", "五", "六", "日"]

    private var personalTemplates: [WorkoutTemplate] {
        store.state.customTemplates.isEmpty ? TemplateCatalog.starterPersonalTemplates : store.state.customTemplates
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    scheduleCard

                    if let today = store.todaysPlannedDay {
                        todayBanner(today)
                    }

                    personalTemplatesGrid

                    recentHistoryCompact
                }
                .padding(.horizontal, Metrics.page)
                .padding(.top, 64)
                .padding(.bottom, Metrics.floatingTabBottomInset + 72)
            }

            // 右下角悬浮搜索 + 创建模板
            HStack(spacing: 10) {
                Button {
                    showSearchSheet = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.text)
                        .frame(width: 46, height: 46)
                        .liquidGlassCapsule(tint: Color.black.opacity(0.55))
                }
                .buttonStyle(.stridePress)

                Button(action: onCreateTemplate) {
                    Text("创建模板")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 22)
                        .frame(height: 46)
                        .background(Capsule().fill(Palette.yellow))
                }
                .buttonStyle(.strideShimmer(glow: Palette.yellow))
            }
            .padding(.trailing, Metrics.page)
            .padding(.bottom, Metrics.floatingTabBottomInset + 8)
        }
        .sheet(item: $detailSession) { session in
            SessionDetailView(session: session)
                .strideSheetDetents([.medium, .large])
        }
        .sheet(isPresented: $showSession, onDismiss: { activeDraft = nil }) {
            SessionView(draft: activeDraft ?? .empty())
        }
        .sheet(isPresented: $showReorder) {
            PlanWeekReorderSheet()
                .strideSheetDetents([.medium, .large])
        }
        .sheet(isPresented: $showRhythmSheet) {
            RhythmEditorSheet { toastMessage in toast = toastMessage }
                .strideSheetDetents([.medium, .large])
        }
        .sheet(isPresented: $showGuideSheet) {
            PlanGuideSheet()
                .strideSheetDetents([.medium, .large])
        }
        .sheet(isPresented: $showSearchSheet) {
            PersonalTemplateSearchSheet(templates: personalTemplates) { tpl in
                selectedTemplate = tpl
            }
            .strideSheetDetents([.medium, .large])
        }
        .sheet(item: $selectedTemplate) { tpl in
            WorkoutTemplateDetailSheet(template: tpl) { draft in
                activeDraft = draft
                showSession = true
            }
            .strideSheetDetents([.medium, .large])
        }
        .sheet(item: Binding(
            get: { selectedDate.map { IdentifiableDate(date: $0) } },
            set: { selectedDate = $0?.date }
        )) { item in
            DayScheduleActionSheet(date: item.date) { draft in
                activeDraft = draft
                showSession = true
            }
            .strideSheetDetents([.medium, .large])
        }
        .sensoryFeedback(.selection, trigger: selectedDate)
        .confirmationDialog("这周的排法重复...", isPresented: $showRepeatDialog) {
            Button("重复 2 周") { store.state.planRepeatWeeks = 2; toast = "已设置重复 2 周" }
            Button("重复 4 周") { store.state.planRepeatWeeks = 4; toast = "已设置重复 4 周" }
            Button("重复 8 周") { store.state.planRepeatWeeks = 8; toast = "已设置重复 8 周" }
            Button("关闭自动重复", role: .destructive) { store.state.planRepeatWeeks = 0; toast = "已取消周期重复" }
            Button("取消", role: .cancel) {}
        }
        .toast($toast)
    }

    // MARK: - 黑金碳纤磨砂标题周/月排期卡片

    private var scheduleCard: some View {
        VStack(spacing: 0) {
            // 黑金鎏金顶栏（告别刺眼纯亮黄）
            HStack {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Palette.yellow)
                        .frame(width: 7, height: 7)
                        .shadow(color: Palette.yellow, radius: 4)
                    Text(expandedMonth ? expandedMonthTitle : weekHeaderTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Palette.text)
                }

                Spacer()

                HStack(spacing: 6) {
                    yellowHeaderIcon("chevron.left") { stepPeriod(-1) }
                    yellowHeaderIcon("chevron.right") { stepPeriod(1) }
                    yellowHeaderIcon(expandedMonth ? "chevron.up" : "chevron.down") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            expandedMonth.toggle()
                        }
                    }
                    moreScheduleMenu
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0x2F2716), Color(hex: 0x1A1814)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Rectangle()
                    .fill(Palette.yellow.opacity(0.24))
                    .frame(height: 0.7),
                alignment: .bottom
            )

            // 网格内容
            VStack(spacing: 12) {
                if expandedMonth {
                    monthGridView
                } else {
                    weekRowView
                }
            }
            .padding(14)
            .background(Palette.card)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Palette.yellow.opacity(0.35), Palette.stroke],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private func yellowHeaderIcon(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.yellow)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Palette.yellow.opacity(0.14)))
                .overlay(Circle().strokeBorder(Palette.yellow.opacity(0.28), lineWidth: 0.7))
        }
        .buttonStyle(.strideSpin)
    }

    private var moreScheduleMenu: some View {
        Menu {
            Section(store.state.planRepeatWeeks > 0 ? "当前每 \(store.state.planRepeatWeeks) 周循环" : "还没有节奏") {
                Button {
                    showRhythmSheet = true
                } label: {
                    Label("排节奏", systemImage: "arrow.triangle.2.circlepath")
                }
                Button {
                    let p = store.state.profile
                    store.setPlan(PlanGenerator.generate(goal: p.goal, days: p.daysPerWeek, experience: p.experience))
                    toast = "AI 已按 \(p.goal.rawValue) · 每周 \(p.daysPerWeek) 练重排"
                } label: {
                    Label("让 AI 帮我排", systemImage: "sparkles")
                }
                Button {
                    showReorder = true
                } label: {
                    Label("拖动调整这一周", systemImage: "arrow.up.arrow.down")
                }
            }

            Section {
                Button {
                    toast = store.copyLastWeekToThisWeek() ? "已复制上周安排" : "暂无上周安排"
                } label: {
                    Label("复制上周到这一周", systemImage: "doc.on.doc")
                }
                Button {
                    showRepeatDialog = true
                } label: {
                    Label("这周的排法重复...", systemImage: "repeat")
                }
            }

            Section {
                Button {
                    showGuideSheet = true
                } label: {
                    Label("看看怎么用", systemImage: "play.circle")
                }
            }

            Section {
                Button(role: .destructive) {
                    store.clearThisWeek()
                    toast = "这一周已清空"
                } label: {
                    Label("清空这一周", systemImage: "eraser")
                }
                Button(role: .destructive) {
                    store.clearAllPlanAndOverrides()
                    toast = "全部排期已清空"
                } label: {
                    Label("清空全部", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.yellow)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Palette.yellow.opacity(0.14)))
                .overlay(Circle().strokeBorder(Palette.yellow.opacity(0.28), lineWidth: 0.7))
        }
    }

    private var weekHeaderTitle: String {
        let nowWeek = WeekPlanOps.stamp(for: Date(), calendar: cal)
        let targetWeek = WeekPlanOps.stamp(for: anchorDate, calendar: cal)
        if nowWeek == targetWeek { return "本周" }
        let f = DateFormatter()
        f.dateFormat = "M/d 周"
        return f.string(from: mondayOfWeek(for: anchorDate))
    }

    private var expandedMonthTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy 年 M 月"
        return f.string(from: anchorDate)
    }

    private func stepPeriod(_ delta: Int) {
        let comp: Calendar.Component = expandedMonth ? .month : .weekOfYear
        if let next = cal.date(byAdding: comp, value: delta, to: anchorDate) {
            anchorDate = next
        }
    }

    private func mondayOfWeek(for date: Date) -> Date {
        let weekday = cal.component(.weekday, from: date) // 1=Sun, 2=Mon...7=Sat
        let offset = (weekday + 5) % 7
        return cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: date)) ?? date
    }

    private var weekRowView: some View {
        let start = mondayOfWeek(for: anchorDate)
        return HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { idx in
                let dayDate = cal.date(byAdding: .day, value: idx, to: start) ?? start
                VStack(spacing: 6) {
                    Text(monFirstNames[idx])
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.textFaint)
                    dayCell(dayDate, compact: false)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.cardSoft))
    }

    private var monthGridView: some View {
        let days = monthCells(for: anchorDate)
        return VStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(monFirstNames, id: \.self) { name in
                    Text(name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.textFaint)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 10) {
                ForEach(days.indices, id: \.self) { idx in
                    if let d = days[idx] {
                        dayCell(d, compact: true)
                    } else {
                        Color.clear.frame(height: 52)
                    }
                }
            }

            // 底部图例
            HStack(spacing: 12) {
                legendDot(color: .clear, border: .white, text: "今天")
                legendCheck(text: "全部完成")
                legendDot(color: Palette.green, border: Palette.green, text: "休息")
                Text("黄字 = 单日改动")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.yellow)
            }
            .padding(.top, 4)
        }
    }

    private func legendDot(color: Color, border: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .overlay(Circle().strokeBorder(border, lineWidth: 1.3))
                .frame(width: 9, height: 9)
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(Palette.textDim)
        }
    }

    private func legendCheck(text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.white)
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(Palette.textDim)
        }
    }

    private func dayCell(_ date: Date, compact: Bool) -> some View {
        let isToday = cal.isDateInToday(date)
        let dayNum = cal.component(.day, from: date)
        let daySessions = store.state.sessions.filter { cal.isDate($0.date, inSameDayAs: date) }
        let planned = store.plannedDay(on: date)
        let hasOverride = store.hasDayOverride(on: date)
        let completed = !daySessions.isEmpty

        let ringColors: [Color] = daySessions.isEmpty
            ? (planned?.rest == true ? [Palette.green] : [Palette.indigo])
            : daySessions.map { $0.inferredIntensity.color }

        let caption: String = {
            if let first = daySessions.first {
                let extra = daySessions.count > 1 ? " +\(daySessions.count - 1)" : ""
                return first.title + extra
            }
            if let p = planned {
                return p.rest ? "休息" : p.title
            }
            return ""
        }()

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if completed {
                        SegmentedEffortRing(colors: ringColors)
                            .frame(width: 34, height: 34)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(Color.black)
                    } else if planned?.rest == true && compact {
                        Circle()
                            .strokeBorder(Palette.green, lineWidth: 2)
                            .frame(width: 32, height: 32)
                        Text("\(dayNum)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.text)
                    } else if isToday {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.65), lineWidth: 1.5)
                            .frame(width: 34, height: 34)
                        Circle()
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 26, height: 26)
                        Text("\(dayNum)")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                    } else if planned != nil && !(planned?.rest ?? true) && compact {
                        Circle()
                            .strokeBorder(Palette.purple, lineWidth: 1.8)
                            .frame(width: 32, height: 32)
                        Text("\(dayNum)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.text)
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 30, height: 30)
                        Text("\(dayNum)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Palette.textDim)
                    }
                }
                .frame(height: 36)

                if !caption.isEmpty && (completed || planned?.rest == true || hasOverride || (!(planned?.rest ?? true) && !compact)) {
                    Text(caption)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(hasOverride ? Palette.yellow : Palette.textDim)
                        .lineLimit(1)
                } else {
                    Text(" ")
                        .font(.system(size: 9.5))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.strideRow(radius: 10))
    }

    private func monthCells(for monthDate: Date) -> [Date?] {
        guard let monthInterval = cal.dateInterval(of: .month, for: monthDate),
              let range = cal.range(of: .day, in: .month, for: monthDate) else { return [] }
        let firstWeekday = cal.component(.weekday, from: monthInterval.start)
        let leadingEmpty = (firstWeekday + 5) % 7
        var cells: [Date?] = Array(repeating: nil, count: leadingEmpty)
        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: monthInterval.start) {
                cells.append(d)
            }
        }
        return cells
    }

    // MARK: - 今日开练横条

    private func todayBanner(_ today: PlannedDay) -> some View {
        Button {
            activeDraft = .fromPlan(today)
            showSession = true
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("今日训练 · \(today.title)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.text)
                    Text("\(today.exercises.count) 个动作 · 点此按计划开练")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textDim)
                }
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "play.fill").font(.system(size: 11, weight: .bold))
                    Text("开练").font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Palette.yellow))
            }
            .padding(14)
            .card(radius: 20, fill: Palette.card, stroke: Palette.stroke)
        }
        .buttonStyle(.strideCard(radius: 20))
    }

    // MARK: - 个人训练模板 2 列海报网格（图 34）

    private var personalTemplatesGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(personalTemplates) { tpl in
                    Button {
                        selectedTemplate = tpl
                    } label: {
                        PersonalPosterCard(template: tpl)
                    }
                    .buttonStyle(.strideCard)
                    .strideScrollDepth(minScale: 0.96, minOpacity: 0.85)
                    .contextMenu {
                        Button {
                            activeDraft = SessionDraft(
                                title: tpl.title,
                                kind: .strength,
                                exercises: tpl.exercises.map { ex in
                                    let lib = SeedData.library.first { $0.name == ex.name }
                                    return LoggedExercise(
                                        exerciseID: lib?.id ?? UUID(),
                                        name: ex.name,
                                        group: lib?.group ?? (tpl.focus ?? .chest),
                                        isTimed: lib?.isTimed ?? false,
                                        sets: (0..<max(1, ex.sets)).map { _ in SetEntry(weight: 0, reps: 8) }
                                    )
                                }
                            )
                            showSession = true
                        } label: {
                            Label("立即开练", systemImage: "play.fill")
                        }

                        Button {
                            store.applyTemplateToDay(tpl, on: Date())
                            toast = "已安排到今天"
                        } label: {
                            Label("设为今天计划", systemImage: "calendar.badge.plus")
                        }

                        if !store.state.customTemplates.isEmpty {
                            Button(role: .destructive) {
                                store.deleteCustomTemplate(id: tpl.id)
                            } label: {
                                Label("删除模板", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 近期训练历史摘要（补全点击进入训练详情）

    private var recentHistoryCompact: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "最近训练", trailing: "\(store.state.sessions.count) 次")

            if store.recentSessions.isEmpty {
                EmptyHint(icon: "dumbbell", title: "还没有训练记录", message: "点右上 + 或下方模板立即开始。")
            } else {
                ForEach(store.recentSessions.prefix(4)) { session in
                    Button {
                        detailSession = session
                    } label: {
                        SessionRow(session: session)
                    }
                    .buttonStyle(.strideCard(radius: 18))
                    .contextMenu {
                        Button(role: .destructive) {
                            store.deleteSession(id: session.id)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 分段耗能彩色圆环

struct SegmentedEffortRing: View {
    let colors: [Color]

    var body: some View {
        ZStack {
            if colors.count <= 1 {
                Circle()
                    .stroke(colors.first ?? Palette.indigo, lineWidth: 3)
            } else {
                ForEach(colors.indices, id: \.self) { i in
                    let count = Double(colors.count)
                    let gap = 0.03
                    let start = Double(i) / count + gap / 2
                    let end = Double(i + 1) / count - gap / 2
                    Circle()
                        .trim(from: start, to: max(start + 0.02, end))
                        .stroke(colors[i], style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
            }
        }
    }
}

// MARK: - 个人海报模板卡（图 34）

struct PersonalPosterCard: View {
    let template: WorkoutTemplate

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 16)

                VStack(alignment: .leading, spacing: -4) {
                    ForEach(template.posterWords.indices, id: \.self) { idx in
                        Text(template.posterWords[idx])
                            .font(.system(size: template.posterWords.count > 1 ? 30 : 34, weight: .black))
                            .tracking(-0.8)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: template.accent.colors,
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.45)
                    }
                }

                Spacer(minLength: 8)

                Text(template.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 158)
            .card(radius: 22, fill: Color(hex: 0x151517), stroke: Palette.stroke)

            Text("\(template.exercises.count) 动作")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.textDim)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.09)))
                .padding(12)
        }
    }
}

// MARK: - 辅助 Sheets（排节奏、调周、单日操作、说明）

private struct IdentifiableDate: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

private struct DayScheduleActionSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let date: Date
    var onStartWorkout: (SessionDraft) -> Void

    private var dateTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M 月 d 日 EEEE"
        return f.string(from: date)
    }

    var body: some View {
        let planned = store.plannedDay(on: date)
        let hasOverride = store.hasDayOverride(on: date)

        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(planned?.rest == true ? "休息 / 恢复日" : (planned?.title ?? "未安排"))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Palette.text)
                            Spacer()
                            if hasOverride {
                                Pill(text: "单日改动", fg: Color.black, bg: Palette.yellow, size: 11)
                            }
                        }
                        if let exs = planned?.exercises, !exs.isEmpty {
                            ForEach(exs) { ex in
                                HStack {
                                    Text(ex.name)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Palette.text)
                                    Spacer()
                                    Text("\(ex.sets) × \(ex.reps)")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Palette.textDim)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .card(radius: 20, fill: Palette.card, stroke: Palette.stroke)

                    if let planned, !planned.rest {
                        PrimaryButton(title: "按此计划开始训练", tint: Palette.yellow) {
                            dismiss()
                            onStartWorkout(.fromPlan(planned))
                        }
                    }

                    HStack(spacing: 10) {
                        SecondaryButton(title: "设为休息日", icon: "bed.double") {
                            store.setDayOverride(PlannedDay(weekday: 1, title: "休息", focus: nil, exercises: [], rest: true), on: date)
                            dismiss()
                        }
                        if hasOverride {
                            SecondaryButton(title: "恢复周默认", icon: "arrow.uturn.backward") {
                                store.clearDayOverride(on: date)
                                dismiss()
                            }
                        }
                    }
                    Spacer()
                }
                .padding(Metrics.page)
            }
            .navigationTitle(dateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct PlanWeekReorderSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private let names = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.state.plan?.days.sorted { $0.weekday < $1.weekday } ?? []) { day in
                    HStack {
                        Text(names[max(0, min(6, day.weekday - 1))])
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Palette.textDim)
                            .frame(width: 28, alignment: .leading)
                        Text(day.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Palette.text)
                        Spacer()
                        if day.rest {
                            Text("休息")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.textFaint)
                        }
                    }
                    .listRowBackground(Palette.card)
                }
                .onMove { store.reorderThisWeek(from: $0, to: $1) }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(Palette.bg)
            .navigationTitle("拖动调整这一周")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { store.prepareWeekUndo() }
    }
}

private struct RhythmEditorSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var onDone: (String) -> Void
    @State private var daysPerWeek: Int = 4
    @State private var goal: Goal = .recomp

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("每周训练天数")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Palette.text)
                        HStack(spacing: 8) {
                            ForEach(3...6, id: \.self) { count in
                                Button {
                                    daysPerWeek = count
                                } label: {
                                    Text("\(count) 天")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(daysPerWeek == count ? Color.black : Palette.textDim)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Capsule().fill(daysPerWeek == count ? Palette.yellow : Palette.cardSoft))
                                }
                                .buttonStyle(.stridePress)
                            }
                        }
                        .sensoryFeedback(.selection, trigger: daysPerWeek)

                        Text("训练主目标")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Palette.text)
                            .padding(.top, 4)
                        HStack(spacing: 8) {
                            ForEach(Goal.allCases) { g in
                                Button {
                                    goal = g
                                } label: {
                                    Text(g.rawValue)
                                        .font(.system(size: 13.5, weight: .bold))
                                        .foregroundStyle(goal == g ? Color.black : Palette.textDim)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Capsule().fill(goal == g ? Color.white : Palette.cardSoft))
                                }
                                .buttonStyle(.stridePress)
                            }
                        }
                        .sensoryFeedback(.selection, trigger: goal)
                    }
                    .padding(16)
                    .card(radius: 20, fill: Palette.card, stroke: Palette.stroke)

                    Spacer()

                    PrimaryButton(title: "生成并应用节奏", tint: Palette.yellow) {
                        store.state.profile.daysPerWeek = daysPerWeek
                        store.state.profile.goal = goal
                        store.setPlan(PlanGenerator.generate(goal: goal, days: daysPerWeek, experience: store.state.profile.experience))
                        onDone("已排好每周 \(daysPerWeek) 练（\(goal.rawValue)）")
                        dismiss()
                    }
                }
                .padding(Metrics.page)
            }
            .navigationTitle("排节奏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
        }
        .onAppear {
            daysPerWeek = store.state.profile.daysPerWeek
            goal = store.state.profile.goal
        }
        .preferredColorScheme(.dark)
    }
}

private struct PlanGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 14) {
                    guideRow(icon: "calendar", title: "周 / 月视图切换", detail: "点黄色标题栏上的下拉箭头展开整月排期，点具体日期可单日调整或立即按计划开练。")
                    guideRow(icon: "sparkles", title: "节奏与周期", detail: "点「...」可使用 AI 重排、拖动调序、复制上周或设置自动重复。")
                    guideRow(icon: "square.grid.2x2", title: "个人与官方模板", detail: "下方卡片为个人快捷模板；切换到顶部「模板」可浏览全部 16 分类精选计划并收藏使用。")
                    Spacer()
                }
                .padding(Metrics.page)
            }
            .navigationTitle("使用说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("知道了") { dismiss() }.foregroundStyle(Palette.yellow)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func guideRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.yellow)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10).fill(Palette.yellow.opacity(0.14)))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.text)
                Text(detail).font(.system(size: 13)).foregroundStyle(Palette.textDim)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
    }
}

private struct PersonalTemplateSearchSheet: View {
    let templates: [WorkoutTemplate]
    var onSelect: (WorkoutTemplate) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [WorkoutTemplate] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return templates }
        return templates.filter {
            $0.title.localizedCaseInsensitiveContains(q)
                || $0.posterWords.joined(separator: " ").localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(filtered) { tpl in
                            Button {
                                dismiss()
                                onSelect(tpl)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(tpl.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Palette.text)
                                        Text("\(tpl.exercises.count) 个动作 · 约 \(tpl.estimatedMinutes) 分钟")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Palette.textDim)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(Palette.textFaint)
                                }
                                .padding(14)
                                .card(radius: 16, fill: Palette.card, stroke: Palette.stroke)
                            }
                            .buttonStyle(.strideCard(radius: 16))
                        }
                    }
                    .padding(Metrics.page)
                }
            }
            .searchable(text: $query, prompt: "搜个人模板")
            .navigationTitle("搜索模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
