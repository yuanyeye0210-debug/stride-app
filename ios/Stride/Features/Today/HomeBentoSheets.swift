import SwiftUI

// MARK: - 1. 小组件管理 Sheet

struct HomeWidgetManagerSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()

                List {
                    Section {
                        ForEach(store.visibleHomeWidgets) { kind in
                            HStack(spacing: 12) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Palette.textFaint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(kind.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Palette.text)
                                    Text(kind.subtitle)
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(Palette.textDim)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { store.isWidgetVisible(kind) },
                                    set: { store.setWidgetVisible(kind, visible: $0) }
                                ))
                                .labelsHidden()
                                .tint(Palette.green)
                            }
                            .listRowBackground(Palette.card)
                        }
                        .onMove { store.moveHomeWidgets(from: $0, to: $1) }
                    } header: {
                        Text("已显示（长按拖动可调整顺序）")
                            .foregroundStyle(Palette.textDim)
                    }

                    let hidden = store.state.hiddenHomeWidgets
                    if !hidden.isEmpty {
                        Section {
                            ForEach(hidden) { kind in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(kind.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Palette.text)
                                        Text(kind.subtitle)
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(Palette.textDim)
                                    }
                                    Spacer()
                                    Button("添加") {
                                        store.setWidgetVisible(kind, visible: true)
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Palette.green)
                                    .buttonStyle(.plain)
                                }
                                .listRowBackground(Palette.card)
                            }
                        } header: {
                            Text("未显示的小组件")
                                .foregroundStyle(Palette.textDim)
                        }
                    }

                    Section {
                        Button("恢复默认布局") {
                            store.resetHomeWidgets()
                        }
                        .foregroundStyle(Palette.blue)
                        .listRowBackground(Palette.card)
                    }
                }
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))
            }
            .navigationTitle("首页小组件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.text)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - 2. 补剂清单与打卡 Sheet

struct SupplementSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var dosage = ""
    @State private var timing = "随餐服用"

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        todayChecklistSection
                        quickPresetSection
                        customAddSection
                    }
                    .padding(Metrics.page)
                }
            }
            .navigationTitle("每日补剂")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var todayChecklistSection: some View {
        let taken = store.takenSupplementIDs()
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今日清单")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.text)
                Spacer()
                if !store.state.supplements.isEmpty {
                    Button("全部记一份") {
                        store.takeAllSupplementsToday()
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Palette.purple)
                }
            }

            if store.state.supplements.isEmpty {
                Text("还没有加入每日清单的补剂，可以从下方常见补剂一键添加。")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textDim)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
            } else {
                VStack(spacing: 8) {
                    ForEach(store.state.supplements) { item in
                        let isDone = taken.contains(item.id)
                        HStack(spacing: 12) {
                            Button {
                                store.toggleSupplement(item.id)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(isDone ? Palette.green : Palette.purple)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Palette.text)
                                        Text("\(item.dosage) · \(item.timingHint)")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Palette.textDim)
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)

                            Button(role: .destructive) {
                                store.removeSupplement(id: item.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Palette.textFaint)
                                    .padding(8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(13)
                        .card(radius: 16, fill: Palette.card, stroke: Palette.stroke)
                    }
                }
            }
        }
    }

    private var quickPresetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("常见补剂（点一下加入）")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.text)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(SupplementCatalog.presets) { preset in
                    let added = store.state.supplements.contains { $0.name == preset.name }
                    Button {
                        store.addSupplement(preset)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(Palette.text)
                                Text("\(preset.dosage) · \(preset.timingHint)")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(Palette.textDim)
                            }
                            Spacer()
                            Image(systemName: added ? "checkmark" : "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(added ? Palette.green : Palette.purple)
                        }
                        .padding(12)
                        .card(radius: 15, fill: added ? Palette.cardSoft : Palette.card, stroke: Palette.stroke)
                    }
                    .buttonStyle(.plain)
                    .disabled(added)
                }
            }
        }
    }

    private var customAddSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("自定义添加")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.text)

            VStack(spacing: 10) {
                TextField("补剂名称（例如：辅酶 Q10）", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.text)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.cardSoft))

                HStack(spacing: 10) {
                    TextField("剂量（如 1 粒）", text: $dosage)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.text)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.cardSoft))

                    TextField("时段提示", text: $timing)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.text)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.cardSoft))
                }

                PrimaryButton(
                    title: "加入每日清单",
                    enabled: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                    tint: Palette.purple
                ) {
                    let cleanName = name.trimmingCharacters(in: .whitespaces)
                    let cleanDose = dosage.trimmingCharacters(in: .whitespaces)
                    store.addSupplement(
                        SupplementItem(
                            name: cleanName,
                            dosage: cleanDose.isEmpty ? "1 份" : cleanDose,
                            timingHint: timing.trimmingCharacters(in: .whitespaces).isEmpty ? "每日一次" : timing
                        )
                    )
                    name = ""
                    dosage = ""
                }
            }
            .padding(14)
            .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
        }
    }
}

// MARK: - 3. 咖啡因录入与入睡时间 Sheet

struct CaffeineSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var customTitle = ""
    @State private var customMg = ""

    private var todayEntries: [CaffeineEntry] { store.todayCaffeineEntries() }
    private var todayMg: Int { store.todayCaffeineMg() }
    private var activeMg: Int { CaffeineCalculator.activeMg(entries: store.state.caffeineEntries) }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        summaryCard
                        presetsGrid
                        sleepTimeCard
                        customEntryCard
                        if !todayEntries.isEmpty {
                            todayHistoryCard
                        }
                    }
                    .padding(Metrics.page)
                }
            }
            .navigationTitle("咖啡因记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var summaryCard: some View {
        HStack(spacing: 10) {
            StatTile(value: "\(todayMg) mg", label: "今日总摄入", tint: todayMg > store.state.caffeineLimitMg ? Palette.amber : Palette.text)
            StatTile(value: "\(activeMg) mg", label: "当前体内估算", tint: Palette.amber)
            StatTile(value: "\(store.state.caffeineLimitMg) mg", label: "安全上限", tint: Palette.textDim)
        }
    }

    private var presetsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("快捷记一杯")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.text)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(CaffeineCalculator.presets) { preset in
                    Button {
                        store.addCaffeine(title: preset.title, mg: preset.mg)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.title)
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(Palette.text)
                                Text(preset.subtitle)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(Palette.textDim)
                            }
                            Spacer()
                            Text("+\(preset.mg)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Palette.amber)
                        }
                        .padding(12)
                        .card(radius: 15, fill: Palette.card, stroke: Palette.stroke)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var sleepTimeCard: some View {
        let sleepDate = Binding<Date>(
            get: {
                Calendar.current.date(
                    bySettingHour: store.state.sleepTargetHour,
                    minute: store.state.sleepTargetMinute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newDate in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                store.state.sleepTargetHour = parts.hour ?? 23
                store.state.sleepTargetMinute = parts.minute ?? 5
            }
        )

        let window = CaffeineCalculator.optimalWindowText(
            sleepHour: store.state.sleepTargetHour,
            sleepMinute: store.state.sleepTargetMinute
        )

        return VStack(alignment: .leading, spacing: 8) {
            DatePicker("预计入睡时间", selection: sleepDate, displayedComponents: .hourAndMinute)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.text)
                .tint(Palette.purple)

            Text("按 5 小时半衰期估算，建议最佳饮用窗口为 \(window.windowLabel)")
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.textDim)
        }
        .padding(14)
        .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
    }

    private var customEntryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("自定义记录")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Palette.text)
            HStack(spacing: 10) {
                TextField("饮品名", text: $customTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.text)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.cardSoft))
                TextField("mg", text: $customMg)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Palette.text)
                    .frame(width: 80)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.cardSoft))
                Button("记") {
                    let mg = Int(customMg) ?? 0
                    let title = customTitle.trimmingCharacters(in: .whitespaces)
                    if mg > 0 {
                        store.addCaffeine(title: title.isEmpty ? "咖啡饮品" : title, mg: mg)
                        customTitle = ""
                        customMg = ""
                    }
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.amber))
            }
        }
        .padding(14)
        .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
    }

    private var todayHistoryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日记录")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Palette.text)
            ForEach(todayEntries) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.text)
                        Text(Self.timeString(entry.date))
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.textFaint)
                    }
                    Spacer()
                    Text("\(entry.mg) mg")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.amber)
                    Button(role: .destructive) {
                        store.deleteCaffeine(id: entry.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Palette.textFaint)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .card(radius: 14, fill: Palette.card, stroke: Palette.stroke)
            }
        }
    }

    private static func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - 4. AI 训练习惯画像 Sheet

struct HabitInsightSheet: View {
    let summary: TrainingHabitSummary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(summary.headline)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Palette.text)
                        Text("基于你本机保存的训练记录与肌群分布实时计算。")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textDim)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .card(radius: 20, fill: Palette.card, stroke: Palette.stroke)

                    HStack(spacing: 10) {
                        StatTile(value: "\(summary.totalSessions)", label: "累计训练", tint: Palette.green)
                        StatTile(value: summary.favoriteGroup, label: "主力部位", tint: Palette.lime)
                    }
                    HStack(spacing: 10) {
                        StatTile(value: "\(summary.avgMinutes)′", label: "平均时长", tint: Palette.blue)
                        StatTile(value: summary.totalTonnageText, label: "累计容量", tint: Palette.amber)
                    }
                    Spacer()
                }
                .padding(Metrics.page)
            }
            .navigationTitle("训练习惯画像")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - 5. 肌肉恢复详情 Sheet

struct MuscleRecoverySheet: View {
    let items: [MuscleRecoveryItem]
    var onStartWorkout: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                VStack(spacing: 12) {
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            Text(item.group.rawValue)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(item.isRecommended ? Palette.lime : Palette.text)
                                .frame(width: 40, alignment: .leading)

                            BarProgress(
                                progress: Double(item.percent) / 100.0,
                                color: item.isRecommended ? Palette.lime : (item.percent >= 70 ? Palette.green : Palette.amber),
                                height: 8
                            )

                            Text("\(item.percent)%")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Palette.text)
                                .frame(width: 48, alignment: .trailing)
                        }
                        .padding(14)
                        .card(radius: 16, fill: Palette.card, stroke: item.isRecommended ? Palette.lime.opacity(0.45) : Palette.stroke)
                    }

                    Text("基于过去 72 小时内各个部位的完成组数与恢复时间线性估算。")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)

                    Spacer()

                    PrimaryButton(title: "按建议去开练", tint: Palette.lime) {
                        dismiss()
                        onStartWorkout()
                    }
                }
                .padding(Metrics.page)
            }
            .navigationTitle("肌肉恢复状态")
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

// MARK: - 6. 活动三环详情 Sheet

struct ActivityDetailSheet: View {
    let kcal: Int
    let kcalGoal: Int
    let exerciseMin: Int
    let steps: Int
    let streak: Int
    var onStartWorkout: () -> Void
    var onStartRun: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        StatTile(value: "\(kcal)", label: "活动千卡 / \(kcalGoal)", tint: Palette.ringMove)
                        StatTile(value: "\(exerciseMin)′", label: "今日锻炼 / 45′", tint: Palette.ringEx)
                    }
                    HStack(spacing: 10) {
                        StatTile(value: WaterLog.grouped(steps), label: "今日步数 / 10,000", tint: Palette.ringStand)
                        StatTile(value: "\(streak) 天", label: "连续训练", tint: Palette.coral)
                    }
                    Spacer()
                    HStack(spacing: 10) {
                        PrimaryButton(title: "力量开练", tint: .white) {
                            dismiss()
                            onStartWorkout()
                        }
                        PrimaryButton(title: "开始跑步", tint: Palette.lime) {
                            dismiss()
                            onStartRun()
                        }
                    }
                }
                .padding(Metrics.page)
            }
            .navigationTitle("今日活动三环")
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
