import SwiftUI

struct TrainingHomeView: View {
    @EnvironmentObject private var store: AppStore

    @State private var draft: SessionDraft?
    @State private var showSession = false
    @State private var detail: WorkoutSession?
    @State private var showReorder = false
    @State private var reorderToken = 0
    @State private var toast: String?

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    weekStats
                    planCard
                    startRow
                    historyList
                }
                .padding(.horizontal, Metrics.page)
                .padding(.bottom, Metrics.floatingTabBottomInset + 16)
            }
        }
        .navigationTitle("计划")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Palette.bg, for: .navigationBar)
        .sheet(isPresented: $showSession, onDismiss: { draft = nil }) {
            SessionView(draft: draft ?? .empty())
        }
        .sheet(item: $detail) { session in
            SessionDetailView(session: session)
                .strideSheetDetents([.medium, .large])
        }
        .sheet(isPresented: $showReorder) {
            WeekReorderSheet()
                .strideSheetDetents([.medium, .large])
        }
        .sensoryFeedback(.success, trigger: reorderToken)
        .toast($toast)
    }

    // MARK: - 本周

    private var weekStats: some View {
        let week = store.weekSessions
        let sets = week.reduce(0) { $0 + $1.totalSets }
        let volume = week.reduce(0) { $0 + $1.totalVolume }
        return HStack(spacing: 10) {
            StatTile(value: "\(week.count)", label: "本周训练", tint: Palette.green)
            StatTile(value: "\(sets)", label: "总组数", tint: Palette.text)
            StatTile(value: "\(Int(volume / 1000))t", label: "总容量", tint: Palette.blue)
        }
    }

    // MARK: - 计划

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("本周")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Palette.text)
                    if let plan = store.state.plan {
                        Text("\(plan.goal.rawValue) · 每周 \(store.state.profile.daysPerWeek) 练")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textDim)
                    }
                }
                Spacer()
                Button {
                    regenerate()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles").font(.system(size: 11, weight: .bold))
                        Text("重排").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Palette.cardHigh))
                }
                .buttonStyle(.stridePress)
            }

            if let plan = store.state.plan {
                HStack(spacing: 6) {
                    ForEach(plan.days.sorted { $0.weekday < $1.weekday }) { day in
                        dayChip(day)
                    }
                }
            }

            if let today = store.todaysPlannedDay {
                VStack(alignment: .leading, spacing: 8) {
                    Text(today.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.green)
                    ForEach(today.exercises) { ex in
                        HStack {
                            Text(ex.name).font(.system(size: 14)).foregroundStyle(Palette.text)
                            Spacer()
                            Text("\(ex.sets)×\(ex.reps)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.textFaint)
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.cardSoft))
            }
        }
        .padding(18)
        .card(radius: 24, fill: Palette.card, stroke: Palette.stroke)
        .contextMenu {
            Button {
                showReorder = true
            } label: {
                Label("拖动调整这一周", systemImage: "arrow.up.arrow.down")
            }
            Button {
                toast = store.copyLastWeekToThisWeek() ? "已复制上周" : "没有上周的安排"
            } label: {
                Label("复制上周到这一周", systemImage: "doc.on.doc")
            }
            Button(role: .destructive) {
                store.clearThisWeek()
                toast = "这一周已清空"
            } label: {
                Label("清空这一周", systemImage: "trash")
            }
            Button {
                toast = store.restoreWeek() ? "已还原" : "没有可还原的修改"
            } label: {
                Label("还原", systemImage: "arrow.uturn.backward")
            }
        }
    }

    private func dayChip(_ day: PlannedDay) -> some View {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let isToday = day.weekday == weekday
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        return VStack(spacing: 5) {
            Text(names[max(0, min(6, day.weekday - 1))])
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isToday ? Color.black : Palette.textDim)
            Circle()
                .fill(day.rest ? Palette.cardHigh : (isToday ? Color.black : Palette.green.opacity(0.7)))
                .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isToday ? Color.white : Palette.cardSoft)
        )
    }

    // MARK: - 开始

    private var startRow: some View {
        HStack(spacing: 10) {
            Button {
                draft = .fromPlan(store.todaysPlannedDay)
                showSession = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "play.fill").font(.system(size: 12, weight: .bold))
                    Text("按计划开练").font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            }
            .buttonStyle(.stridePress)

            Button {
                draft = .empty()
                showSession = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.text)
                    .frame(width: 52, height: 50)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.cardHigh))
            }
            .buttonStyle(.stridePress)
        }
    }

    // MARK: - 历史

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "训练历史", trailing: "\(store.state.sessions.count) 次")

            if store.recentSessions.isEmpty {
                EmptyHint(icon: "clock.arrow.circlepath", title: "还没有训练", message: "按计划开练，记录会自动出现在这里。")
            } else {
                ForEach(store.recentSessions) { session in
                    Button {
                        detail = session
                    } label: {
                        SessionRow(session: session)
                    }
                    .buttonStyle(.strideCard(radius: 18))
                    .strideScrollDepth(minScale: 0.96, minOpacity: 0.85)
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

    private func regenerate() {
        let p = store.state.profile
        store.setPlan(PlanGenerator.generate(goal: p.goal, days: p.daysPerWeek, experience: p.experience))
        reorderToken += 1
        toast = "计划已按 \(p.goal.rawValue) / 每周 \(p.daysPerWeek) 练重排"
    }
}

// MARK: - 行

struct SessionRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: session.kind.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.green)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Palette.green.opacity(0.1)))

            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textDim)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.textFaint)
        }
        .padding(14)
        .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
    }

    private var subtitle: String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return "\(f.string(from: session.date)) · \(session.totalSets) 组 · \(Int(session.totalVolume)) kg"
    }
}

// MARK: - 详情

struct SessionDetailView: View {
    let session: WorkoutSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            StatTile(value: "\(session.durationSec / 60)′", label: "时长")
                            StatTile(value: "\(session.totalSets)", label: "组数")
                            StatTile(value: "\(Int(session.totalVolume))", label: "容量 kg")
                        }

                        ForEach(session.exercises) { ex in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(ex.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Palette.text)
                                ForEach(ex.sets.indices, id: \.self) { idx in
                                    let set = ex.sets[idx]
                                    HStack {
                                        Text("第 \(idx + 1) 组")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Palette.textFaint)
                                        Spacer()
                                        Text("\(fmt(set.weight)) kg × \(ex.isTimed ? "\(set.seconds)″" : "\(set.reps)")")
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundStyle(Palette.text)
                                        if let rpe = set.rpe {
                                            Text("@\(fmt(rpe))")
                                                .font(.system(size: 11))
                                                .foregroundStyle(Palette.textDim)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .card(radius: 20, fill: Palette.card, stroke: Palette.stroke)
                        }
                    }
                    .padding(Metrics.page)
                }
            }
            .navigationTitle(session.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
        }
    }

    private func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}

// MARK: - 动作库

struct ExerciseGroupBox: Identifiable {
    let group: MuscleGroup
    let list: [Exercise]
    var id: String { group.rawValue }
}

struct ExerciseLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (Exercise) -> Void

    var body: some View {
        NavigationStack {
            ExerciseVideoLibraryView(onPick: onPick, embeddedInPlanHub: false)
                .navigationTitle("动作视频库")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("关闭") { dismiss() }.foregroundStyle(Palette.textDim)
                    }
                }
        }
    }
}

private struct WeekReorderSheet: View {
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
