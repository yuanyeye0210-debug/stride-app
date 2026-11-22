import SwiftUI

struct TemplateLibraryView: View {
    @EnvironmentObject private var store: AppStore

    var onCreateTemplate: () -> Void

    @State private var selectedCategory: String = "全部"
    @State private var selectedSingle: WorkoutTemplate?
    @State private var selectedWeekPlan: WeekPlanTemplate?
    @State private var selectedRunProgram: RunProgramTemplate?
    @State private var showSession = false
    @State private var activeDraft: SessionDraft?
    @State private var toast: String?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    categoryChipsBar

                    contentForSelectedCategory
                }
                .padding(.top, 64)
                .padding(.bottom, Metrics.floatingTabBottomInset + 74)
            }

            Button(action: onCreateTemplate) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("新建模板")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(Color.black)
                .padding(.horizontal, 18)
                .frame(height: 44)
                .background(Capsule().fill(Color.white.opacity(0.94)))
                .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
            }
            .buttonStyle(.stridePress)
            .padding(.trailing, Metrics.page)
            .padding(.bottom, Metrics.floatingTabBottomInset + 8)
        }
        .sheet(item: $selectedSingle) { tpl in
            WorkoutTemplateDetailSheet(template: tpl) { draft in
                activeDraft = draft
                showSession = true
            }
            .strideSheetDetents([.medium, .large])
        }
        .sheet(item: $selectedWeekPlan) { weekTpl in
            WeekPlanTemplateDetailSheet(template: weekTpl) { msg in
                toast = msg
            }
            .strideSheetDetents([.medium, .large])
        }
        .sheet(item: $selectedRunProgram) { runTpl in
            RunProgramDetailSheet(program: runTpl) { msg in
                toast = msg
            }
            .strideSheetDetents([.medium, .large])
        }
        .sheet(isPresented: $showSession, onDismiss: { activeDraft = nil }) {
            SessionView(draft: activeDraft ?? .empty())
        }
        .sensoryFeedback(.selection, trigger: selectedCategory)
        .toast($toast)
    }

    // MARK: - 16 分类横向筛选胶囊

    private var categoryChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TemplateCatalog.categories, id: \.self) { category in
                    let active = selectedCategory == category
                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            selectedCategory = category
                        }
                    } label: {
                        Text(category)
                            .font(.system(size: 13, weight: active ? .bold : .medium))
                            .foregroundStyle(active ? Color.black : Palette.textDim)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(active ? Palette.yellow : Palette.card))
                            .overlay(
                                Capsule().strokeBorder(active ? .clear : Palette.stroke, lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(.stridePress)
                }
            }
            .padding(.horizontal, Metrics.page)
        }
    }

    // MARK: - 内容分发

    @ViewBuilder
    private var contentForSelectedCategory: some View {
        switch selectedCategory {
        case "全部":
            allCategorySections
        case "周计划":
            twoColumnGrid(weeks: TemplateCatalog.weekPlans, singles: [])
        case "跑步计划":
            runProgramsFullWidthList
        case "我的收藏":
            favoritesSection
        default:
            let matchingWeeks = TemplateCatalog.weekPlans.filter { $0.categories.contains(selectedCategory) }
            let matchingSingles = allSingleWorkouts.filter { $0.categories.contains(selectedCategory) }
            twoColumnGrid(weeks: matchingWeeks, singles: matchingSingles)
        }
    }

    private var allSingleWorkouts: [WorkoutTemplate] {
        store.state.customTemplates + TemplateCatalog.singleWorkouts
    }

    // MARK: - 「全部」纵深专题滑动视图（图 38–47）

    private var allCategorySections: some View {
        VStack(alignment: .leading, spacing: 22) {
            // 1. 周计划横滑
            sectionHeader(title: "周计划", subtitle: nil, targetCategory: "周计划")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(TemplateCatalog.weekPlans.prefix(6)) { plan in
                        Button { selectedWeekPlan = plan } label: {
                            WeekPlanCard(template: plan)
                                .frame(width: 172)
                        }
                        .buttonStyle(.strideCard)
                    }
                }
                .padding(.horizontal, Metrics.page)
            }

            // 2. 跑步计划横滑
            sectionHeader(title: "跑步计划", subtitle: "跑步 · 按周进阶，排进日历照着跑", targetCategory: "跑步计划")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(TemplateCatalog.runPrograms) { prog in
                        Button { selectedRunProgram = prog } label: {
                            RunProgramCompactCard(program: prog)
                                .frame(width: 264)
                        }
                        .buttonStyle(.strideCard)
                    }
                }
                .padding(.horizontal, Metrics.page)
            }

            // 3. 各个精选单次训练专题
            let topicCategories = [
                "新手入门", "全身", "三分化", "分化训练", "单动作专项",
                "专项训练", "有氧燃脂", "居家", "女性塑形", "体态改善",
                "拉伸恢复", "特定人群"
            ]

            ForEach(topicCategories, id: \.self) { topic in
                let singles = allSingleWorkouts.filter { $0.categories.contains(topic) }
                if !singles.isEmpty {
                    sectionHeader(title: topic, subtitle: nil, targetCategory: topic)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(singles) { tpl in
                                Button { selectedSingle = tpl } label: {
                                    SingleTemplateCard(template: tpl)
                                        .frame(width: 172)
                                }
                                .buttonStyle(.strideCard)
                            }
                        }
                        .padding(.horizontal, Metrics.page)
                    }
                }
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String?, targetCategory: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Palette.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textDim)
                }
            }
            Spacer()
            Button {
                withAnimation(.snappy(duration: 0.22)) {
                    selectedCategory = targetCategory
                }
            } label: {
                HStack(spacing: 3) {
                    Text("查看全部")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Palette.textDim)
            }
            .buttonStyle(.stridePress)
        }
        .padding(.horizontal, Metrics.page)
    }

    // MARK: - 2 列混排网格（周计划置顶 + 单次无缝衔接）

    private func twoColumnGrid(weeks: [WeekPlanTemplate], singles: [WorkoutTemplate]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
            ForEach(weeks) { plan in
                Button { selectedWeekPlan = plan } label: {
                    WeekPlanCard(template: plan)
                }
                .buttonStyle(.strideCard)
                .strideScrollDepth(minScale: 0.95, minOpacity: 0.85)
                .contextMenu {
                    Button {
                        store.applyWeekTemplate(plan)
                    } label: {
                        Label("应用到本周计划", systemImage: "calendar.badge.plus")
                    }
                    Button {
                        store.toggleTemplateFavorite(plan.id)
                    } label: {
                        Label(
                            store.isTemplateFavorite(plan.id) ? "取消收藏" : "收藏周计划",
                            systemImage: store.isTemplateFavorite(plan.id) ? "heart.slash" : "heart"
                        )
                    }
                }
            }
            ForEach(singles) { tpl in
                Button { selectedSingle = tpl } label: {
                    SingleTemplateCard(template: tpl)
                }
                .buttonStyle(.strideCard)
                .strideScrollDepth(minScale: 0.95, minOpacity: 0.85)
                .contextMenu {
                    Button {
                        store.toggleTemplateFavorite(tpl.id)
                    } label: {
                        Label(
                            store.isTemplateFavorite(tpl.id) ? "取消收藏" : "收藏模板",
                            systemImage: store.isTemplateFavorite(tpl.id) ? "heart.slash" : "heart"
                        )
                    }
                }
            }
        }
        .padding(.horizontal, Metrics.page)
    }

    // MARK: - 跑步计划单列全宽横向 Banner

    private var runProgramsFullWidthList: some View {
        VStack(spacing: 12) {
            ForEach(TemplateCatalog.runPrograms) { prog in
                Button { selectedRunProgram = prog } label: {
                    RunProgramBannerCard(program: prog)
                }
                .buttonStyle(.strideCard)
                .strideScrollDepth(minScale: 0.96, minOpacity: 0.85)
            }
        }
        .padding(.horizontal, Metrics.page)
    }

    // MARK: - 我的收藏（含图 66 空状态）

    @ViewBuilder
    private var favoritesSection: some View {
        let favIDs = Set(store.state.favoriteTemplateIDs)
        let favWeeks = TemplateCatalog.weekPlans.filter { favIDs.contains($0.id) }
        let favSingles = allSingleWorkouts.filter { favIDs.contains($0.id) }
        let favRuns = TemplateCatalog.runPrograms.filter { favIDs.contains($0.id) }

        if favWeeks.isEmpty && favSingles.isEmpty && favRuns.isEmpty {
            VStack(spacing: 8) {
                Text("还没有收藏")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.text)
                Text("看到想练的，点右上角的心形先存着")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textDim)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
            .padding(.horizontal, 20)
            .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
            .padding(.horizontal, Metrics.page)
        } else {
            VStack(spacing: 14) {
                if !favRuns.isEmpty {
                    ForEach(favRuns) { prog in
                        Button { selectedRunProgram = prog } label: {
                            RunProgramBannerCard(program: prog)
                        }
                        .buttonStyle(.strideCard)
                        .strideScrollDepth(minScale: 0.96, minOpacity: 0.85)
                    }
                    .padding(.horizontal, Metrics.page)
                }
                if !favWeeks.isEmpty || !favSingles.isEmpty {
                    twoColumnGrid(weeks: favWeeks, singles: favSingles)
                }
            }
        }
    }
}

// MARK: - 卡片组件：WEEK PLAN 7 日点阵卡

struct WeekPlanCard: View {
    let template: WeekPlanTemplate

    private var themeGradient: [Color] {
        template.isCardioTheme ? [Color.white, Palette.green] : [Color.white, Color(hex: 0xB8BAC2)]
    }

    private var activeDotColor: Color {
        template.isCardioTheme ? Palette.green : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Text("WEEK PLAN")
                        .font(.system(size: 10.5, weight: .black))
                        .foregroundStyle(template.isCardioTheme ? Palette.green : Color.white.opacity(0.85))
                    Spacer()
                    HStack(spacing: 3) {
                        ForEach(1...7, id: \.self) { idx in
                            let on = template.activeWeekdaysMonFirst.contains(idx)
                            Capsule()
                                .fill(on ? activeDotColor : Color.white.opacity(0.18))
                                .frame(width: 4, height: 11)
                        }
                    }
                }

                Spacer(minLength: 14)

                Text(template.title)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(
                        LinearGradient(colors: themeGradient, startPoint: .top, endPoint: .bottom)
                    )
                    .lineLimit(2)

                if !template.subtitle.isEmpty {
                    Text(template.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.textDim)
                        .lineLimit(2)
                        .padding(.top, 3)
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 158)
            .card(radius: 22, fill: Color(hex: 0x141416), stroke: Palette.stroke)

            Text("一周 \(template.activeWeekdaysMonFirst.count) 练")
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(Palette.text)
                .lineLimit(1)
            Text("\(template.level) · 每次约 \(template.minutesPerSession) 分钟")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textDim)
                .lineLimit(1)
        }
    }
}

// MARK: - 卡片组件：单次英文海报卡

struct SingleTemplateCard: View {
    let template: WorkoutTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: -4) {
                Spacer(minLength: 0)
                ForEach(template.posterWords.indices, id: \.self) { idx in
                    Text(template.posterWords[idx])
                        .font(.system(size: template.posterWords.count > 1 ? 30 : 34, weight: .black))
                        .tracking(-0.8)
                        .foregroundStyle(
                            LinearGradient(colors: template.accent.colors, startPoint: .top, endPoint: .bottom)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 158)
            .card(radius: 22, fill: Color(hex: 0x141416), stroke: Palette.stroke)

            Text(template.title)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(Palette.text)
                .lineLimit(1)
            Text("\(template.level) · 约 \(template.estimatedMinutes) 分钟")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textDim)
                .lineLimit(1)
        }
    }
}

// MARK: - 卡片组件：跑步计划横向/全宽卡片

struct RunProgramCompactCard: View {
    let program: RunProgramTemplate

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: -4) {
                    ForEach(program.posterLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(
                                LinearGradient(colors: program.accent.colors, startPoint: .top, endPoint: .bottom)
                            )
                            .lineLimit(1)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(program.title)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(Palette.text)
                    Text("\(program.weeks) 周 · 每周 \(program.sessionsPerWeek) 次")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textDim)
                }
            }
            .padding(16)
            .frame(height: 116)
            .card(radius: 22, fill: Color(hex: 0x141416), stroke: Palette.stroke)

            Text(program.level)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Palette.textDim)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.08)))
                .padding(12)
        }
    }
}

struct RunProgramBannerCard: View {
    let program: RunProgramTemplate

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: -5) {
                    ForEach(program.posterLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 38, weight: .black))
                            .foregroundStyle(
                                LinearGradient(colors: program.accent.colors, startPoint: .top, endPoint: .bottom)
                            )
                            .lineLimit(1)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(program.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.text)
                    Text("\(program.weeks) 周 · 每周 \(program.sessionsPerWeek) 次")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textDim)
                }
            }
            .padding(18)
            .frame(height: 132)
            .card(radius: 24, fill: Color(hex: 0x141416), stroke: Palette.stroke)

            Text(program.level)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.textDim)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.09)))
                .padding(14)
        }
    }
}

// MARK: - 详情弹窗：单次 / 周计划 / 跑步周期

struct WorkoutTemplateDetailSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let template: WorkoutTemplate
    var onStartSession: (SessionDraft) -> Void

    var body: some View {
        let fav = store.isTemplateFavorite(template.id)
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("\(template.level) · 约 \(template.estimatedMinutes) 分钟 · \(template.exercises.count) 动作")
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.textDim)
                            Spacer()
                        }

                        ForEach(template.exercises) { ex in
                            HStack {
                                Text(ex.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Palette.text)
                                Spacer()
                                Text("\(ex.sets) × \(ex.reps)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Palette.yellow)
                            }
                            .padding(14)
                            .card(radius: 16, fill: Palette.card, stroke: Palette.stroke)
                        }

                        HStack(spacing: 10) {
                            SecondaryButton(title: "安排到今天", icon: "calendar.badge.plus") {
                                store.applyTemplateToDay(template, on: Date())
                                dismiss()
                            }
                            PrimaryButton(title: "立即开练", tint: Palette.yellow) {
                                let logged = template.exercises.map { ex in
                                    let lib = SeedData.library.first { $0.name == ex.name }
                                    return LoggedExercise(
                                        exerciseID: lib?.id ?? UUID(),
                                        name: ex.name,
                                        group: lib?.group ?? (template.focus ?? .chest),
                                        isTimed: lib?.isTimed ?? false,
                                        sets: (0..<max(1, ex.sets)).map { _ in SetEntry(weight: 0, reps: 8) }
                                    )
                                }
                                dismiss()
                                onStartSession(SessionDraft(title: template.title, kind: .strength, exercises: logged))
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(Metrics.page)
                }
            }
            .navigationTitle(template.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.toggleTemplateFavorite(template.id)
                    } label: {
                        Image(systemName: fav ? "heart.fill" : "heart")
                            .foregroundStyle(fav ? Palette.coralHi : Palette.text)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct WeekPlanTemplateDetailSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let template: WeekPlanTemplate
    var onApplied: (String) -> Void
    private let names = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        let fav = store.isTemplateFavorite(template.id)
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(template.subtitle) · 一周 \(template.activeWeekdaysMonFirst.count) 练 · \(template.level)")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textDim)

                        ForEach(template.days.sorted { $0.weekday < $1.weekday }) { day in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("周\(names[max(0, min(6, day.weekday - 1))])")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(day.rest ? Palette.textFaint : Palette.yellow)
                                    Text(day.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Palette.text)
                                }
                                ForEach(day.exercises) { ex in
                                    HStack {
                                        Text(ex.name).font(.system(size: 13)).foregroundStyle(Palette.textDim)
                                        Spacer()
                                        Text("\(ex.sets) × \(ex.reps)").font(.system(size: 12, design: .rounded)).foregroundStyle(Palette.textFaint)
                                    }
                                }
                            }
                            .padding(14)
                            .card(radius: 16, fill: Palette.card, stroke: Palette.stroke)
                        }

                        PrimaryButton(title: "应用为我的本周计划", tint: Palette.yellow) {
                            store.applyWeekTemplate(template)
                            onApplied("已应用「\(template.title)」")
                            dismiss()
                        }
                        .padding(.top, 6)
                    }
                    .padding(Metrics.page)
                }
            }
            .navigationTitle(template.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.toggleTemplateFavorite(template.id)
                    } label: {
                        Image(systemName: fav ? "heart.fill" : "heart")
                            .foregroundStyle(fav ? Palette.coralHi : Palette.text)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct RunProgramDetailSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let program: RunProgramTemplate
    var onApplied: (String) -> Void

    var body: some View {
        let fav = store.isTemplateFavorite(program.id)
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("\(program.weeks) 周 · 每周 \(program.sessionsPerWeek) 次 · \(program.level)")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.green)

                        Text(program.summary)
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.textDim)

                        ForEach(program.sampleDays.filter { !$0.rest }) { day in
                            HStack {
                                Text(day.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Palette.text)
                                Spacer()
                                Text(day.exercises.first?.reps ?? "30 min")
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(Palette.textDim)
                            }
                            .padding(14)
                            .card(radius: 16, fill: Palette.card, stroke: Palette.stroke)
                        }

                        PrimaryButton(title: "排进本周日历", tint: Palette.green) {
                            let weekTpl = WeekPlanTemplate(
                                id: program.id,
                                title: program.title,
                                subtitle: "\(program.weeks)周周期",
                                activeWeekdaysMonFirst: [2, 4, 6],
                                level: program.level,
                                minutesPerSession: 40,
                                isCardioTheme: true,
                                categories: ["跑步计划"],
                                days: program.sampleDays
                            )
                            store.applyWeekTemplate(weekTpl)
                            onApplied("已将「\(program.title)」排入本周")
                            dismiss()
                        }
                    }
                    .padding(Metrics.page)
                }
            }
            .navigationTitle(program.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.toggleTemplateFavorite(program.id)
                    } label: {
                        Image(systemName: fav ? "heart.fill" : "heart")
                            .foregroundStyle(fav ? Palette.coralHi : Palette.text)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - 我的自定义模板管理 & 新建模板（本地管理，无社区后端）

struct MyCustomTemplatesSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var onCreateNew: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.card.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        Button(action: onCreateNew) {
                            HStack(spacing: 8) {
                                Text("创建新模板")
                                Image(systemName: "plus.circle.fill")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Palette.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .liquidGlassCapsule(tint: Color.white.opacity(0.08))
                        }
                        .buttonStyle(.stridePress)

                        if store.state.customTemplates.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "tray")
                                    .font(.system(size: 30, weight: .light))
                                    .foregroundStyle(Palette.textFaint)
                                Text("还没创建过自定义模板")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Palette.text)
                                Text("把你常用的分化训练存成模板，开练或排进日历只要点一下")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Palette.textDim)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 42)
                            .padding(.horizontal, 20)
                            .card(radius: 22, fill: Palette.bg.opacity(0.45), stroke: Palette.stroke)
                        } else {
                            ForEach(store.state.customTemplates) { tpl in
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
                                    Button(role: .destructive) {
                                        store.deleteCustomTemplate(id: tpl.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(Palette.red)
                                    }
                                    .buttonStyle(.stridePress)
                                }
                                .padding(14)
                                .card(radius: 16, fill: Palette.bg.opacity(0.45), stroke: Palette.stroke)
                            }
                        }
                    }
                    .padding(Metrics.page)
                }
            }
            .navigationTitle("我的模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Palette.textDim)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct CreateTemplateSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var posterWord = "CUSTOM"
    @State private var focus: MuscleGroup = .chest
    @State private var level = "进阶"
    @State private var minutes = 50
    @State private var exercises: [PlannedExercise] = []
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("模板名称（例如：推胸强化日）", text: $title)
                                .textFieldStyle(.plain)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Palette.text)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.cardSoft))

                            TextField("封面英文大字（如 PUSH / LEG DAY）", text: $posterWord)
                                .textInputAutocapitalization(.characters)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Palette.text)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.cardSoft))

                            Stepper("预计时长：\(minutes) 分钟", value: $minutes, in: 10...120, step: 5)
                                .font(.system(size: 14))
                                .foregroundStyle(Palette.text)
                        }
                        .padding(14)
                        .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)

                        HStack {
                            Text("动作列表（\(exercises.count)）")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Palette.text)
                            Spacer()
                            Button("+ 从动作库添加") {
                                showPicker = true
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.yellow)
                        }

                        ForEach(exercises.indices, id: \.self) { idx in
                            HStack {
                                Text(exercises[idx].name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Palette.text)
                                Spacer()
                                Stepper("\(exercises[idx].sets) 组", value: $exercises[idx].sets, in: 1...8)
                                    .labelsHidden()
                                Text("\(exercises[idx].sets) 组 × \(exercises[idx].reps)")
                                    .font(.system(size: 12.5, design: .rounded))
                                    .foregroundStyle(Palette.textDim)
                            }
                            .padding(12)
                            .card(radius: 14, fill: Palette.card, stroke: Palette.stroke)
                        }

                        PrimaryButton(
                            title: "保存模板",
                            enabled: !title.trimmingCharacters(in: .whitespaces).isEmpty && !exercises.isEmpty,
                            tint: Palette.yellow
                        ) {
                            let cleanTitle = title.trimmingCharacters(in: .whitespaces)
                            let words = posterWord
                                .trimmingCharacters(in: .whitespaces)
                                .uppercased()
                                .split(separator: " ")
                                .map(String.init)
                            let tpl = WorkoutTemplate(
                                id: "custom.\(UUID().uuidString)",
                                posterWords: words.isEmpty ? ["CUSTOM"] : words,
                                accentRaw: focus == .legs ? "purple" : "silver",
                                title: cleanTitle,
                                level: level,
                                estimatedMinutes: minutes,
                                categories: ["分化训练"],
                                focus: focus,
                                exercises: exercises,
                                isCustom: true
                            )
                            store.addCustomTemplate(tpl)
                            dismiss()
                        }
                        .padding(.top, 8)
                    }
                    .padding(Metrics.page)
                }
            }
            .navigationTitle("新建训练模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
            .sheet(isPresented: $showPicker) {
                ExerciseLibraryView { exercise in
                    exercises.append(PlannedExercise(name: exercise.name, sets: 4, reps: exercise.isTimed ? "45 秒" : "8–12"))
                    if exercises.count == 1 {
                        focus = exercise.group
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
