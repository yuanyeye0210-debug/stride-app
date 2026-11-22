import SwiftUI

struct DietDashboardView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date = Date()
    @State private var waterStepMl: Int = WaterLog.stepMl
    @State private var showFoodSheet = false
    @State private var showCaffeineSheet = false
    @State private var showSupplementSheet = false
    @State private var showCarbCycleSheet = false
    @State private var showGoalsSheet = false
    @State private var showDatePicker = false
    @State private var timelineExpanded = true
    @State private var toast: String?

    private var cal: Calendar { Calendar.current }
    private var dayFoods: [FoodEntry] { store.foods(on: selectedDate) }
    private var nutrition: (kcal: Double, p: Double, c: Double, f: Double) { store.nutrition(on: selectedDate) }
    private var fiberG: Double { store.fiber(on: selectedDate) }

    private var waterMl: Int { store.todayWaterMl(now: selectedDate) }
    private var waterGoal: Int { max(1, store.state.waterGoalMl) }

    private var kcalTarget: Int { store.state.profile.kcalTarget }
    private var proteinTarget: Int { max(1, store.state.profile.proteinTarget) }
    private var carbTarget: Int { max(1, store.carbTarget(on: selectedDate)) }
    private var fatTarget: Int { max(1, Int((Double(kcalTarget) * 0.28 / 9.0).rounded())) }
    private var fiberTarget: Double { max(1, store.state.fiberGoalG) }

    private var dayCaffeineEntries: [CaffeineEntry] {
        store.state.caffeineEntries.filter { cal.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var dayCaffeineMg: Int {
        dayCaffeineEntries.reduce(0) { $0 + $1.mg }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    // Row 1: 饮水 + 饮食
                    HStack(spacing: 12) {
                        waterWaveCard
                        dietKcalCard
                    }

                    // Row 2: 咖啡因 + 补剂
                    HStack(spacing: 12) {
                        CaffeineBentoCard(
                            todayMg: dayCaffeineMg,
                            limitMg: store.state.caffeineLimitMg,
                            sleepHour: store.state.sleepTargetHour,
                            sleepMinute: store.state.sleepTargetMinute
                        ) {
                            showCaffeineSheet = true
                        }
                        supplementCard
                    }

                    // Row 3: 蛋白质 + 碳水
                    HStack(spacing: 12) {
                        proteinCard
                        carbsCard
                    }

                    // Row 4: 脂肪 + 膳食纤维
                    HStack(spacing: 12) {
                        fatCard
                        fiberCard
                    }

                    // 今天的时间轴
                    timelineCard

                    // 碳循环卡片
                    carbCycleCard
                        .strideScrollDepth(minScale: 0.96, minOpacity: 0.85)

                    Text("记录左滑或长按可删除 · 可在右上齿轮调整每日目标")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textFaint)
                        .padding(.top, 4)
                }
                .padding(.horizontal, Metrics.page)
                .padding(.top, 10)
                .padding(.bottom, 96)
            }

            // 底部亮蓝色主按钮
            Button {
                showFoodSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("添加记录")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 26)
                .frame(height: 46)
                .background(Capsule().fill(Palette.blue))
                .shadow(color: Palette.blue.opacity(0.4), radius: 14, y: 6)
            }
            .buttonStyle(StridePressButtonStyle(scale: 0.95, pressedOpacity: 0.9, haptic: .medium))
            .padding(.bottom, 18)
        }
        .navigationTitle(cal.isDateInToday(selectedDate) ? "饮食记录" : dateString(selectedDate))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    Button {
                        showDatePicker = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Palette.coralHi))
                    }
                    .buttonStyle(.stridePress)

                    Button {
                        showGoalsSheet = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.text)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white.opacity(0.14)))
                    }
                    .buttonStyle(.stridePress)
                }
            }
        }
        .sheet(isPresented: $showFoodSheet) {
            FoodScanView()
        }
        .sheet(isPresented: $showCaffeineSheet) {
            CaffeineSheet()
                .strideSheetDetents([.medium, .large])
        }
        .sheet(isPresented: $showSupplementSheet) {
            SupplementSheet()
                .strideSheetDetents([.medium, .large])
        }
        .sheet(isPresented: $showCarbCycleSheet) {
            CarbCycleEditorSheet()
                .strideSheetDetents([.medium, .large])
        }
        .sheet(isPresented: $showGoalsSheet) {
            NutritionGoalsSheet()
                .strideSheetDetents([.medium, .large])
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                ZStack {
                    Palette.bg.ignoresSafeArea()
                    DatePicker("选择日期", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(Palette.coralHi)
                        .padding()
                }
                .navigationTitle("切换日期")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") { showDatePicker = false }.foregroundStyle(Palette.coralHi)
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
        .toast($toast)
    }

    // MARK: - 1. 饮水水波半圆卡片

    private var waterWaveCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("饮水")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.text)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(WaterLog.grouped(waterMl))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.text)
                    .numericRoll(value: waterMl)
                Text("/ \(WaterLog.grouped(waterGoal)) 毫升")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textDim)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            ZStack(alignment: .bottom) {
                // 蓝色水波填充背景
                GeometryReader { geo in
                    let pct = min(1.0, Double(waterMl) / Double(waterGoal))
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(Palette.blue.opacity(0.28))
                            .frame(height: geo.size.height * pct)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .frame(height: 82)

                HStack(spacing: 6) {
                    Button { store.addWater(delta: -waterStepMl, now: selectedDate) } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                    .buttonStyle(.stridePress)

                    Button {
                        waterStepMl = waterStepMl == 500 ? 200 : (waterStepMl == 200 ? 350 : 500)
                    } label: {
                        Text("\(waterStepMl) 毫升")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.text)
                            .numericRoll(value: waterStepMl)
                            .padding(.horizontal, 9)
                            .frame(height: 28)
                            .background(Capsule().fill(Color.white.opacity(0.16)))
                    }
                    .buttonStyle(.stridePress)

                    Button { store.addWater(delta: waterStepMl, now: selectedDate) } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Palette.blue))
                    }
                    .buttonStyle(.stridePress)
                }
                .padding(.bottom, 6)
            }
        }
        .padding(14)
        .frame(height: 178)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
        .sensoryFeedback(.selection, trigger: waterStepMl)
        .sensoryFeedback(.impact(weight: .light), trigger: waterMl)
    }

    // MARK: - 2. 饮食热量缺口与宏量卡

    private var dietKcalCard: some View {
        let eaten = Int(nutrition.kcal.rounded())
        let gap = eaten - kcalTarget
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("饮食")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Text("缺口 \(gap)")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(gap <= 0 ? Palette.green : Palette.coralHi)
                Spacer()
                Button { showFoodSheet = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.stridePress)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(WaterLog.grouped(eaten))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.text)
                Text("/ \(WaterLog.grouped(kcalTarget)) 千卡")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Palette.textDim)
                    .lineLimit(1)
            }

            Text(gap <= 0 ? "还可以吃 \(WaterLog.grouped(abs(gap))) 千卡" : "已超标 \(WaterLog.grouped(gap)) 千卡")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textFaint)

            Spacer(minLength: 0)

            VStack(spacing: 5) {
                miniMacroRow("蛋白质", cur: nutrition.p, target: Double(proteinTarget), color: Palette.green)
                miniMacroRow("碳水", cur: nutrition.c, target: Double(carbTarget), color: Palette.blue)
                miniMacroRow("脂肪", cur: nutrition.f, target: Double(fatTarget), color: Palette.amber)
            }
        }
        .padding(14)
        .frame(height: 178)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    private func miniMacroRow(_ name: String, cur: Double, target: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(name).font(.system(size: 9.5)).foregroundStyle(Palette.textDim)
                Spacer()
                Text("\(Int(cur))/\(Int(target))g")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textFaint)
            }
            BarProgress(progress: target > 0 ? cur / target : 0, color: color, height: 4)
        }
    }

    // MARK: - 4. 补剂卡

    private var supplementCard: some View {
        let taken = store.takenSupplementIDs(on: selectedDate)
        let list = store.state.supplements
        let doneCount = list.filter { taken.contains($0.id) }.count

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("补剂")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Button { showSupplementSheet = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.stridePress)
            }

            Text("\(doneCount) 种")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.text)
                .numericRoll(value: doneCount)

            Spacer(minLength: 0)

            if list.isEmpty || doneCount == 0 {
                Text(list.isEmpty ? "点右上 + 添加补剂" : "今天还没吃补剂")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textFaint)
            } else {
                Text("已打卡 \(doneCount) / \(list.count) 项")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.purple)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(height: 178)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
        .contentShape(Rectangle())
        .onTapGesture { showSupplementSheet = true }
    }

    // MARK: - 5. 蛋白质（早午晚加 4 餐槽）

    private var proteinCard: some View {
        let cur = Int(nutrition.p.rounded())
        let left = max(0, proteinTarget - cur)
        let mealValues = Meal.allCases.map { meal in
            dayFoods.filter { $0.meal == meal }.reduce(0.0) { $0 + $1.protein }
        }
        let maxMeal = max(25.0, mealValues.max() ?? 25.0)
        let shortNames = ["早", "午", "晚", "加"]

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("蛋白质").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.text)
                Spacer()
                Button { showFoodSheet = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.stridePress)
            }
            Text("\(cur) / \(proteinTarget) g")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.text)
            Text("还差 \(left) 克")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textFaint)

            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(0..<4, id: \.self) { i in
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08))
                            RoundedRectangle(cornerRadius: 5).fill(Palette.green)
                                .frame(height: 44 * min(1, mealValues[i] / maxMeal))
                        }
                        .frame(height: 44)
                        Text(shortNames[i])
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.textFaint)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .frame(height: 168)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 6. 碳水

    private var carbsCard: some View {
        let cur = Int(nutrition.c.rounded())
        let left = max(0, carbTarget - cur)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("碳水").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.text)
                Spacer()
                Button { showFoodSheet = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.stridePress)
            }
            Text("\(cur) / \(carbTarget) g")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.text)
            Text("还差 \(left) 克")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textFaint)

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                BarProgress(progress: Double(cur) / Double(carbTarget), color: Palette.blue, height: 10)
                HStack {
                    Text("0").font(.system(size: 10)).foregroundStyle(Palette.textFaint)
                    Spacer()
                    Text("\(carbTarget) g").font(.system(size: 10)).foregroundStyle(Palette.textFaint)
                }
            }
        }
        .padding(14)
        .frame(height: 168)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 7. 脂肪（2×10 圆点矩阵）

    private var fatCard: some View {
        let cur = Int(nutrition.f.rounded())
        let left = max(0, fatTarget - cur)
        let litDots = min(20, Int((Double(cur) / Double(fatTarget) * 20.0).rounded()))

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("脂肪").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.text)
                Spacer()
                Button { showFoodSheet = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.stridePress)
            }
            Text("\(cur) / \(fatTarget) g")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.text)
            Text("还差 \(left) 克")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textFaint)

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 5) {
                        ForEach(0..<10, id: \.self) { col in
                            let idx = row * 10 + col
                            Circle()
                                .fill(idx < litDots ? Palette.amber : Color.white.opacity(0.14))
                                .frame(width: 7, height: 7)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .frame(height: 168)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 8. 膳食纤维（刻度标尺）

    private var fiberCard: some View {
        let cur = Int(fiberG.rounded())
        let target = Int(fiberTarget.rounded())
        let left = max(0, target - cur)
        let litTicks = min(14, Int((fiberG / fiberTarget * 14.0).rounded()))

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("膳食纤维").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.text)
                Spacer()
                Button { showFoodSheet = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.stridePress)
            }
            Text("\(cur) / \(target) g")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.text)
            Text("还差 \(left) 克")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textFaint)

            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<14, id: \.self) { i in
                    Capsule()
                        .fill(i < litTicks ? Palette.green : Color.white.opacity(0.16))
                        .frame(width: 3, height: i % 5 == 0 ? 22 : 13)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .frame(height: 168)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 今天的时间轴（图 71）

    private var timelineCard: some View {
        let activeCaf = CaffeineCalculator.activeMg(entries: store.state.caffeineEntries, at: Date())
        let eventCount = dayFoods.count + dayCaffeineEntries.count + (waterMl > 0 ? 1 : 0)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textDim)
                Text(cal.isDateInToday(selectedDate) ? "今天的时间轴" : "当日时间轴")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text("\(eventCount) 条")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.textDim)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        timelineExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textDim)
                }
                .buttonStyle(.stridePress)
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("热量").font(.system(size: 11)).foregroundStyle(Palette.textFaint)
                    Text("\(Int(nutrition.kcal.rounded())) 千卡")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.text)
                        .numericRoll(value: Int(nutrition.kcal.rounded()))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text("饮水").font(.system(size: 11)).foregroundStyle(Palette.textFaint)
                    Text("\(WaterLog.grouped(waterMl)) 毫升")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.text)
                        .numericRoll(value: waterMl)
                    BarProgress(progress: Double(waterMl) / Double(waterGoal), color: Palette.blue, height: 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text("体内咖啡因").font(.system(size: 11)).foregroundStyle(Palette.textFaint)
                    Text("\(activeCaf) 毫克")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.text)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if timelineExpanded {
                VStack(spacing: 10) {
                    if waterMl > 0 {
                        timelineRow(time: "今日", barColor: Palette.blue, title: "水", detail: "\(waterMl) ml")
                    }
                    ForEach(dayCaffeineEntries) { caf in
                        timelineRow(time: timeString(caf.date), barColor: Palette.amber, title: caf.title, detail: "\(caf.mg) mg")
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.deleteCaffeine(id: caf.id)
                                    toast = "已删除咖啡因记录"
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                    ForEach(dayFoods) { entry in
                        timelineRow(
                            time: timeString(entry.date),
                            barColor: Palette.green,
                            title: entry.items.first?.name ?? entry.meal.rawValue,
                            detail: "\(Int(entry.kcal.rounded())) kcal"
                        )
                        .contextMenu {
                            Button(role: .destructive) {
                                store.deleteFood(id: entry.id)
                                toast = "已删除饮食记录"
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }

                    // 红色「现在」基准线
                    HStack(spacing: 8) {
                        Text(timeString(Date()))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Palette.coralHi)
                        Circle().fill(Palette.coralHi).frame(width: 7, height: 7)
                        Text("现在")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Palette.coralHi)
                        Rectangle()
                            .fill(Palette.coralHi.opacity(0.6))
                            .frame(height: 1)
                    }
                }
            }

            Button {
                showFoodSheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                    Text("记加餐")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.stridePress)
        }
        .padding(16)
        .card(radius: 24, fill: Palette.card, stroke: Palette.stroke)
    }

    private func timelineRow(time: String, barColor: Color, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Text(time)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Palette.textFaint)
                .frame(width: 40, alignment: .leading)
            Capsule()
                .fill(barColor)
                .frame(width: 3, height: 22)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.text)
                .lineLimit(1)
            Capsule()
                .fill(barColor.opacity(0.55))
                .frame(maxWidth: .infinity)
                .frame(height: 10)
            Text(detail)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.textDim)
        }
    }

    // MARK: - 碳循环卡片

    private var carbCycleCard: some View {
        let cfg = store.state.carbCycle
        let names = ["一", "二", "三", "四", "五", "六", "日"]
        let monFirstToCal = [2, 3, 4, 5, 6, 7, 1]
        let todayWd = cal.component(.weekday, from: Date())

        return Button {
            showCarbCycleSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("碳循环")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Palette.text)
                    Spacer()
                    HStack(spacing: 4) {
                        Text(cfg.enabled ? "已开启" : "未开启")
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(cfg.enabled ? Palette.green : Palette.textDim)
                }

                HStack(alignment: .bottom, spacing: 14) {
                    Text("练大肌群的日子多吃碳水，休息日少吃，一周平均照目标走。")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textDim)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(0..<7, id: \.self) { i in
                            let wd = monFirstToCal[i]
                            let isHigh = cfg.highDays.contains(wd)
                            let isToday = wd == todayWd
                            VStack(spacing: 3) {
                                Capsule()
                                    .fill(isHigh ? Palette.blue : (isToday ? Palette.green : Color.white.opacity(0.2)))
                                    .frame(width: 8, height: isHigh ? 28 : 14)
                                Text(names[i])
                                    .font(.system(size: 9.5, weight: isToday ? .bold : .medium))
                                    .foregroundStyle(isToday ? Palette.text : Palette.textFaint)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
        }
        .buttonStyle(.strideCard(radius: 22))
    }

    private func dateString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d 饮食"
        return f.string(from: d)
    }

    private func timeString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }
}

// MARK: - 碳循环配置与每日营养目标弹窗

private struct CarbCycleEditorSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private let monNames = ["一", "二", "三", "四", "五", "六", "日"]
    private let monToCal = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("启用碳循环目标", isOn: $store.state.carbCycle.enabled)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .tint(Palette.blue)
                        .padding(16)
                        .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("选择高碳日（通常选腿日/背日等大肌群日）")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.textDim)
                        HStack(spacing: 6) {
                            ForEach(0..<7, id: \.self) { i in
                                let wd = monToCal[i]
                                let on = store.state.carbCycle.highDays.contains(wd)
                                Button {
                                    if on {
                                        store.state.carbCycle.highDays.removeAll { $0 == wd }
                                    } else {
                                        store.state.carbCycle.highDays.append(wd)
                                    }
                                } label: {
                                    Text(monNames[i])
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(on ? Color.black : Palette.textDim)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Capsule().fill(on ? Palette.blue : Palette.cardSoft))
                                }
                                .buttonStyle(.stridePress)
                            }
                        }
                        .sensoryFeedback(.selection, trigger: store.state.carbCycle.highDays)

                        Stepper("高碳日：\(store.state.carbCycle.highCarbG) g", value: $store.state.carbCycle.highCarbG, in: 120...500, step: 10)
                            .foregroundStyle(Palette.text)
                        Stepper("中碳日：\(store.state.carbCycle.mediumCarbG) g", value: $store.state.carbCycle.mediumCarbG, in: 80...400, step: 10)
                            .foregroundStyle(Palette.text)
                        Stepper("低碳日：\(store.state.carbCycle.lowCarbG) g", value: $store.state.carbCycle.lowCarbG, in: 40...300, step: 10)
                            .foregroundStyle(Palette.text)
                    }
                    .padding(16)
                    .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)

                    Spacer()
                }
                .padding(Metrics.page)
            }
            .navigationTitle("碳循环")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.foregroundStyle(Palette.blue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct NutritionGoalsSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                VStack(spacing: 14) {
                    Stepper("每日饮水目标：\(store.state.waterGoalMl) ml", value: $store.state.waterGoalMl, in: 800...5000, step: 100)
                        .foregroundStyle(Palette.text)
                        .padding(14)
                        .card(radius: 16, fill: Palette.card, stroke: Palette.stroke)

                    Stepper("咖啡因上限：\(store.state.caffeineLimitMg) mg", value: $store.state.caffeineLimitMg, in: 100...800, step: 50)
                        .foregroundStyle(Palette.text)
                        .padding(14)
                        .card(radius: 16, fill: Palette.card, stroke: Palette.stroke)

                    Stepper("膳食纤维目标：\(Int(store.state.fiberGoalG)) g", value: $store.state.fiberGoalG, in: 10...60, step: 5)
                        .foregroundStyle(Palette.text)
                        .padding(14)
                        .card(radius: 16, fill: Palette.card, stroke: Palette.stroke)

                    Spacer()
                }
                .padding(Metrics.page)
            }
            .navigationTitle("饮食与饮水目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.foregroundStyle(Palette.blue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
