import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var watch: WatchSession

    @State private var waterStepMl: Int = WaterLog.stepMl
    @State private var quoteIndex: Int = 0
    @State private var healthMetrics: HealthKitManager.DayMetrics?

    // 交互弹窗
    @State private var showWorkoutSheet = false
    @State private var showFoodSheet = false
    @State private var foodStartWithCamera = false
    @State private var showRunSheet = false
    @State private var showCoachSheet = false
    @State private var showWidgetManager = false
    @State private var showSupplementSheet = false
    @State private var showCaffeineSheet = false
    @State private var showHabitSheet = false
    @State private var showRecoverySheet = false
    @State private var showActivitySheet = false

    /// 供外层切换至“计划”Tab（点击连续训练日历时使用）
    var onJumpToPlan: (() -> Void)? = nil

    private var profile: Profile { store.state.profile }
    private var snapshot: DailySnapshot { store.todaySnapshot }
    private var nutrition: (kcal: Double, p: Double, c: Double, f: Double) { store.todayNutrition }

    private var stepsToday: Int {
        max(snapshot.steps, healthMetrics?.steps ?? 0)
    }

    private var kcalToday: Int {
        max(snapshot.activeKcal, healthMetrics?.activeKcal ?? 0)
    }

    private var habitSummary: TrainingHabitSummary {
        HabitAnalyzer.summarize(
            sessions: store.state.sessions,
            watchConnected: watch.reachable
        )
    }

    private var recoveryItems: [MuscleRecoveryItem] {
        let balance = ProgressiveEngine.weeklySetBalance(sessions: store.state.sessions)
        return MuscleRecoveryCalculator.assess(
            sessions: store.state.sessions,
            weeklySets: balance,
            plannedFocus: store.todaysPlannedDay?.focus
        )
    }

    private var monthlyStats: (hours: Double, count: Int) {
        MonthlyTrainingCalculator.stats(
            sessions: store.state.sessions,
            runs: store.state.runs
        )
    }

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Metrics.gap) {
                    ForEach(bentoRows) { row in
                        rowView(row)
                    }

                    addWidgetButton
                        .padding(.top, 8)
                }
                .padding(.horizontal, Metrics.page)
                .padding(.top, 66) // 为顶部悬浮 Liquid Glass 分段胶囊栏留出空间
                .padding(.bottom, Metrics.floatingTabBottomInset + 16)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            let metrics = await health.todayMetrics()
            if metrics.steps > 0 || metrics.activeKcal > 0 {
                healthMetrics = metrics
            }
        }
        .sheet(isPresented: $showWorkoutSheet) {
            SessionView(draft: SessionDraft.fromPlan(store.todaysPlannedDay))
        }
        .sheet(isPresented: $showFoodSheet) {
            FoodScanView(startWithPhotoPicker: foodStartWithCamera)
        }
        .sheet(isPresented: $showRunSheet) {
            RunCaptureView()
        }
        .sheet(isPresented: $showCoachSheet) {
            NavigationStack { CoachView() }
        }
        .sheet(isPresented: $showWidgetManager) {
            HomeWidgetManagerSheet()
        }
        .sheet(isPresented: $showSupplementSheet) {
            SupplementSheet()
        }
        .sheet(isPresented: $showCaffeineSheet) {
            CaffeineSheet()
        }
        .sheet(isPresented: $showHabitSheet) {
            HabitInsightSheet(summary: habitSummary)
        }
        .sheet(isPresented: $showRecoverySheet) {
            MuscleRecoverySheet(items: recoveryItems) {
                showWorkoutSheet = true
            }
        }
        .sheet(isPresented: $showActivitySheet) {
            ActivityDetailSheet(
                kcal: kcalToday,
                kcalGoal: max(1, profile.kcalTarget * 2 / 3),
                exerciseMin: snapshot.exerciseMin,
                steps: stepsToday,
                streak: store.streak,
                onStartWorkout: { showWorkoutSheet = true },
                onStartRun: { showRunSheet = true }
            )
        }
    }

    // MARK: - 底部“添加小组件”按钮

    private var addWidgetButton: some View {
        Button {
            showWidgetManager = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                Text("添加小组件")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color.white.opacity(0.11)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bento 行组装逻辑

    private enum BentoRowItem: Identifiable {
        case full(HomeWidgetKind)
        case pair(HomeWidgetKind, HomeWidgetKind?)

        var id: String {
            switch self {
            case .full(let k): return "full-\(k.rawValue)"
            case .pair(let l, let r): return "pair-\(l.rawValue)-\(r?.rawValue ?? "none")"
            }
        }
    }

    private var bentoRows: [BentoRowItem] {
        var rows: [BentoRowItem] = []
        var pendingLeft: HomeWidgetKind?

        for kind in store.visibleHomeWidgets {
            if kind.isFullWidth {
                if let left = pendingLeft {
                    rows.append(.pair(left, nil))
                    pendingLeft = nil
                }
                rows.append(.full(kind))
            } else if let left = pendingLeft {
                rows.append(.pair(left, kind))
                pendingLeft = nil
            } else {
                pendingLeft = kind
            }
        }
        if let left = pendingLeft {
            rows.append(.pair(left, nil))
        }
        return rows
    }

    @ViewBuilder
    private func rowView(_ row: BentoRowItem) -> some View {
        switch row {
        case .full(let kind):
            widgetView(kind)
        case .pair(let left, let right):
            HStack(spacing: Metrics.gap) {
                widgetView(left)
                    .frame(maxWidth: .infinity)
                if let right {
                    widgetView(right)
                        .frame(maxWidth: .infinity)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity, height: 178)
                }
            }
        }
    }

    @ViewBuilder
    private func widgetView(_ kind: HomeWidgetKind) -> some View {
        switch kind {
        case .aiHabit:
            AIHabitBannerCard(summary: habitSummary) {
                showHabitSheet = true
            }

        case .water:
            WaterBentoCard(
                ml: store.todayWaterMl(),
                goal: max(store.state.waterGoalMl, 1),
                stepMl: $waterStepMl
            ) { delta in
                store.addWater(delta: delta)
            }

        case .coachNote:
            CoachNoteBentoCard(quoteIndex: $quoteIndex) {
                showCoachSheet = true
            }

        case .supplements:
            SupplementBentoCard(
                items: store.state.supplements,
                takenIDs: store.takenSupplementIDs(),
                onToggle: { id in store.toggleSupplement(id) },
                onManage: { showSupplementSheet = true }
            )

        case .streakCalendar:
            StreakCalendarBentoCard(
                streak: store.streak,
                isRestDay: store.todaysPlannedDay == nil
            ) {
                if let onJumpToPlan {
                    onJumpToPlan()
                } else {
                    showWorkoutSheet = true
                }
            }

        case .calorieBalance:
            CalorieBalanceBentoCard(
                remaining: store.remainingKcalToday,
                goal: profile.kcalTarget,
                onCamera: {
                    foodStartWithCamera = true
                    showFoodSheet = true
                },
                onManual: {
                    foodStartWithCamera = false
                    showFoodSheet = true
                }
            )

        case .muscleRecovery:
            MuscleRecoveryBentoCard(items: recoveryItems) {
                showRecoverySheet = true
            }

        case .caffeine:
            CaffeineBentoCard(
                todayMg: store.todayCaffeineMg(),
                limitMg: store.state.caffeineLimitMg,
                sleepHour: store.state.sleepTargetHour,
                sleepMinute: store.state.sleepTargetMinute
            ) {
                showCaffeineSheet = true
            }

        case .foodReceipt:
            FoodReceiptBentoCard(
                foods: store.todayFoods,
                eatenKcal: Int(nutrition.kcal.rounded()),
                remainingKcal: store.remainingKcalToday
            ) {
                foodStartWithCamera = false
                showFoodSheet = true
            }

        case .activityRings:
            ActivityRingsBentoCard(
                moveProgress: Double(kcalToday) / Double(max(1, profile.kcalTarget * 2 / 3)),
                exerciseProgress: Double(snapshot.exerciseMin) / 45.0,
                standProgress: Double(stepsToday) / 10000.0
            ) {
                showActivitySheet = true
            }

        case .monthlyHours:
            MonthlyHoursBentoCard(
                hours: monthlyStats.hours,
                count: monthlyStats.count
            ) {
                showWorkoutSheet = true
            }
        }
    }
}
