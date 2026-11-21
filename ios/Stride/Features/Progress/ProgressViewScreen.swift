import SwiftUI
import PhotosUI
import Charts
import UIKit

struct ProgressViewScreen: View {
    @EnvironmentObject private var store: AppStore

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var showCameraPicker = false
    @State private var showGallerySheet = false

    @State private var showDietDashboard = false
    @State private var showFoodScan = false
    @State private var foodStartWithCamera = false
    @State private var showTrainingDetail = false
    @State private var showWeightSheet = false
    @State private var showAllInsights = false
    @State private var showSessionSheet = false
    @State private var showCaffeineSheet = false
    @State private var toast: String?

    private var insights: [HealthInsightItem] {
        InsightsEngine.generate(state: store.state)
    }

    private var nutrition: (kcal: Double, p: Double, c: Double, f: Double) {
        store.todayNutrition
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Palette.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    headerBar
                    photoFanCard
                    dualWaterAndDietRow
                    todayStateCard
                    trainingRecordCard
                    weightRecordCard
                    sleepMoonCard
                    highlightsSection
                }
                .padding(.horizontal, Metrics.page)
                .padding(.top, 8)
                .padding(.bottom, Metrics.floatingTabBottomInset + 64)
            }

            // 右下角悬浮毛玻璃 + 添加记录
            addRecordMenuButton
                .padding(.trailing, Metrics.page)
                .padding(.bottom, Metrics.floatingTabBottomInset + 8)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showDietDashboard) {
            DietDashboardView()
        }
        .navigationDestination(isPresented: $showTrainingDetail) {
            TrainingAndRoutesDetailView()
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared())
        .onChange(of: selectedPhotoItem) { _, item in
            Task { await importPhoto(item) }
        }
        .sheet(isPresented: $showCameraPicker) {
            SafeCameraPicker { image in
                store.savePhotoMemory(image: image, caption: "打卡", category: "meal")
                toast = "照片已存入图片库"
            } onUnavailable: {
                toast = "当前设备无可用相机，已为你保留相册上传"
            } onClose: {
                showCameraPicker = false
            }
        }
        .sheet(isPresented: $showGallerySheet) {
            PhotoGallerySheet()
        }
        .sheet(isPresented: $showFoodScan) {
            FoodScanView(startWithPhotoPicker: foodStartWithCamera)
        }
        .sheet(isPresented: $showWeightSheet) {
            WeightLogSheet()
        }
        .sheet(isPresented: $showAllInsights) {
            AllInsightsSheet(items: insights)
        }
        .sheet(isPresented: $showSessionSheet) {
            SessionView(draft: .empty())
        }
        .sheet(isPresented: $showCaffeineSheet) {
            CaffeineSheet()
        }
        .toast($toast)
    }

    // MARK: - 顶部标题与右上角 +

    private var headerBar: some View {
        HStack {
            Text("记录")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Palette.text)
            Spacer()
            Menu {
                Button { foodStartWithCamera = false; showFoodScan = true } label: {
                    Label("记一餐", systemImage: "fork.knife")
                }
                Button { store.addWater(delta: 500); toast = "+500 ml 饮水" } label: {
                    Label("喝水 +500 ml", systemImage: "drop.fill")
                }
                Button { showWeightSheet = true } label: {
                    Label("记体重", systemImage: "scalemass")
                }
                Button { showSessionSheet = true } label: {
                    Label("记一次训练", systemImage: "dumbbell.fill")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .frame(width: 40, height: 40)
                    .liquidGlassCapsule(tint: Color.black.opacity(0.45))
            }
        }
        .padding(.top, 4)
    }

    // MARK: - 图片库扇形照片墙（图 67–68）

    private var photoFanCard: some View {
        let memories = Array(store.state.photoMemories.prefix(5))
        let angles: [Double] = [-10, -5, 0, 5, 10]
        let xOffsets: [CGFloat] = [-72, -36, 0, 36, 72]
        let yOffsets: [CGFloat] = [8, 3, 0, 3, 8]

        return ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                ZStack {
                    ForEach(0..<5, id: \.self) { idx in
                        let memory = idx < memories.count ? memories[idx] : nil
                        Group {
                            if let memory, let uiImg = store.loadPhotoImage(fileName: memory.fileName) {
                                Image(uiImage: uiImg)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                LinearGradient(
                                    colors: placeholderColors(idx),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .overlay {
                                    Image(systemName: idx % 2 == 0 ? "fork.knife" : "figure.strengthtraining.traditional")
                                        .font(.system(size: 18, weight: .light))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                }
                            }
                        }
                        .frame(width: 68, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
                        )
                        .rotationEffect(.degrees(angles[idx]))
                        .offset(x: xOffsets[idx], y: yOffsets[idx])
                        .zIndex(idx == 2 ? 3 : (idx == 1 || idx == 3 ? 2 : 1))
                    }
                }
            }
            .frame(height: 112)
            .padding(.bottom, 30)
            .onTapGesture { showGallerySheet = true }

            // 前景液态玻璃长胶囊
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(hex: 0xBDBDC4))
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text("图片库")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.text)
                    if !store.state.photoMemories.isEmpty {
                        Text("已存 \(store.state.photoMemories.count) 张")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Palette.textDim)
                    }
                }

                Spacer()

                Menu {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label("从相册选择", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            showCameraPicker = true
                        } else {
                            toast = "模拟器无相机，请用「从相册选择」"
                        }
                    } label: {
                        Label("拍照", systemImage: "camera")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.white.opacity(0.14)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .liquidGlassCapsule(tint: Color.black.opacity(0.52))
            .onTapGesture { showGallerySheet = true }
        }
        .padding(.top, 4)
    }

    private func placeholderColors(_ idx: Int) -> [Color] {
        switch idx {
        case 0: return [Color(hex: 0x3D5A3E), Color(hex: 0x1D291E)]
        case 1: return [Color(hex: 0x5C4828), Color(hex: 0x292012)]
        case 2: return [Color(hex: 0x5A5138), Color(hex: 0x2B271C)]
        case 3: return [Color(hex: 0x4E4735), Color(hex: 0x232018)]
        default: return [Color(hex: 0x374B5A), Color(hex: 0x182128)]
        }
    }

    // MARK: - 今日饮水 & 今日饮食双卡（图 67–69）

    private var dualWaterAndDietRow: some View {
        let waterMl = store.todayWaterMl()
        let waterGoal = max(1, store.state.waterGoalMl)
        let waterPct = WaterLog.percent(waterMl, goal: waterGoal)

        let eaten = Int(nutrition.kcal.rounded())
        let kcalGoal = max(1, store.state.profile.kcalTarget)
        let kcalPct = Int((Double(eaten) / Double(kcalGoal) * 100.0).rounded())

        return HStack(spacing: 12) {
            // 左：今日饮水
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.blue)
                    Text("今日饮水")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Palette.text)
                    Spacer()
                    Button {
                        store.addWater(delta: 500)
                        toast = "+500 ml 饮水"
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Palette.blue)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.09)))
                    }
                    .buttonStyle(.plain)
                }

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(waterMl)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.text)
                    Text("/ \(waterGoal) ml")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.blue)
                        .lineLimit(1)
                }

                BarProgress(progress: Double(waterMl) / Double(waterGoal), color: Palette.blue, height: 5)

                Text("\(waterPct)% · 约 \(WaterLog.cups(waterMl)) 杯")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textFaint)
            }
            .padding(14)
            .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
            .contentShape(Rectangle())
            .onTapGesture { showDietDashboard = true }

            // 右：今日饮食
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.amber)
                    Text("今日饮食")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Palette.text)
                    Spacer()
                    Menu {
                        Section("按默认量记一次") {
                            ForEach(store.state.quickFoodTemplates) { tpl in
                                Button {
                                    store.addFood(FoodEntry(meal: .snack, items: [tpl.toFoodItem()]))
                                    toast = "已记录 \(tpl.name)"
                                } label: {
                                    Text("\(tpl.name) · \(Int(tpl.kcal)) kcal")
                                }
                            }
                        }
                        Section {
                            Button {
                                foodStartWithCamera = true
                                showFoodScan = true
                            } label: {
                                Label("拍照记录", systemImage: "camera")
                            }
                            Button {
                                foodStartWithCamera = false
                                showFoodScan = true
                            } label: {
                                Label("手动记录", systemImage: "square.and.pencil")
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Palette.amber)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.09)))
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(eaten)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.text)
                    Text("/ \(kcalGoal) kcal")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.amber)
                        .lineLimit(1)
                }

                BarProgress(progress: Double(eaten) / Double(kcalGoal), color: Palette.amber, height: 5)

                Text("\(kcalPct)% · 今日 \(store.todayFoods.count) 餐")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textFaint)
            }
            .padding(14)
            .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
            .contentShape(Rectangle())
            .onTapGesture { showDietDashboard = true }
        }
    }

    // MARK: - 今日状态卡片（三排睡眠分期点阵）

    private var todayStateCard: some View {
        let lastSleep = store.todaySnapshot.sleepMinutes > 0 ? store.todaySnapshot.sleepMinutes : 445
        let sleepHours = lastSleep / 60
        let sleepMins = lastSleep % 60
        let statusText = lastSleep >= 420 ? "状态不错" : "睡眠略短"

        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("今日状态")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textDim)
                Text(statusText)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.text)
                Text(String(format: "昨晚睡了 %dh%02d", sleepHours, sleepMins))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textFaint)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                sleepStageDotsRow(count: 8, color: Palette.indigo)
                sleepStageDotsRow(count: 10, color: Palette.blue)
                sleepStageDotsRow(count: 4, color: Palette.cyan)
            }
        }
        .padding(18)
        .card(radius: 24, fill: Palette.card, stroke: Palette.stroke)
    }

    private func sleepStageDotsRow(count: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { _ in
                Capsule()
                    .fill(color)
                    .frame(width: 9, height: 7)
            }
        }
    }

    // MARK: - 训练记录卡片（近 7 天暖黄柱图，点击看详页）

    private var trainingRecordCard: some View {
        let week = store.weekSessions
        let cal = Calendar.current
        let last7Min: [Double] = (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date())) ?? Date()
            return Double(store.state.sessions.filter { cal.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.durationSec / 60 })
        }
        let total7Min = Int(last7Min.reduce(0, +).rounded())
        let maxMin = max(1.0, last7Min.max() ?? 1.0)

        return Button {
            showTrainingDetail = true
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("训练记录")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Palette.textDim)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(week.count)")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(Palette.text)
                        Text("次 本周")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.textDim)
                    }
                    Text("近 7 天 \(total7Min) 分钟")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textFaint)
                }

                Spacer()

                HStack(alignment: .bottom, spacing: 7) {
                    ForEach(last7Min.indices, id: \.self) { i in
                        let v = last7Min[i]
                        let h = v <= 0 ? 7.0 : max(12.0, 56.0 * (v / maxMin))
                        Capsule()
                            .fill(v > 0 ? Palette.yellow : Color.white.opacity(0.12))
                            .frame(width: 8, height: h)
                    }
                }
                .frame(height: 58, alignment: .bottom)
            }
            .padding(18)
            .card(radius: 24, fill: Palette.card, stroke: Palette.stroke)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 体重记录卡片

    private var weightRecordCard: some View {
        let sorted = store.state.snapshots.filter { $0.weightKg > 20 }.sorted { $0.date < $1.date }
        let current = sorted.last?.weightKg ?? store.state.profile.weightKg
        let prev = sorted.dropLast(min(sorted.count - 1, 6)).last?.weightKg ?? current
        let delta = current - prev

        return Button {
            showWeightSheet = true
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("体重记录")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Palette.textDim)
                    Text(String(format: "%.1f kg", current))
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.text)
                    Text(String(format: "本周 %+.1f kg", delta))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(delta <= 0 ? Palette.green : Palette.amber)
                }

                Spacer()

                HStack(spacing: 12) {
                    ForEach(Array(sorted.suffix(4).enumerated()), id: \.offset) { idx, item in
                        VStack {
                            Circle()
                                .fill(idx == sorted.suffix(4).count - 1 ? Palette.green : Palette.cyan)
                                .frame(width: 9, height: 9)
                                .offset(y: CGFloat((current - item.weightKg) * 8))
                        }
                    }
                }
                .frame(height: 44)
            }
            .padding(18)
            .card(radius: 24, fill: Palette.card, stroke: Palette.stroke)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 睡眠月相卡

    private var sleepMoonCard: some View {
        let sorted = store.state.snapshots.sorted { $0.date < $1.date }
        let last7 = (0..<7).map { i -> Int in
            let snaps = sorted.suffix(7)
            if i < snaps.count {
                let s = Array(snaps)[i]
                return s.sleepMinutes > 0 ? s.sleepMinutes : 420
            }
            return 420
        }
        let latest = last7.last ?? 420
        let avg = last7.reduce(0, +) / max(1, last7.count)
        let pct = Int((Double(latest) / 480.0 * 100.0).rounded())

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("睡眠")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text("目标的 \(pct)%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.yellow)
            }

            SleepMoonPhaseRowView(minutes: last7, goalMin: 480)

            Text(String(format: "昨晚 %d:%02d · 平均 %d:%02d", latest / 60, latest % 60, avg / 60, avg % 60))
                .font(.system(size: 12))
                .foregroundStyle(Palette.textDim)
        }
        .padding(18)
        .card(radius: 24, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 「亮点」周环比健康洞察流（图 72–77）

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("亮点")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Button("全部") {
                    showAllInsights = true
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.blue)
            }
            .padding(.top, 8)

            ForEach(insights) { item in
                HealthInsightRowView(item: item)
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 0.6)
            }
        }
    }

    // MARK: - 右下角悬浮 + 添加记录

    private var addRecordMenuButton: some View {
        Menu {
            Button { foodStartWithCamera = false; showFoodScan = true } label: {
                Label("记一餐（热量与营养）", systemImage: "fork.knife")
            }
            Button { store.addWater(delta: 500); toast = "已记录 500 ml 饮水" } label: {
                Label("记一杯水 (+500 ml)", systemImage: "drop.fill")
            }
            Button { showCaffeineSheet = true } label: {
                Label("记咖啡因", systemImage: "cup.and.saucer.fill")
            }
            Button { showWeightSheet = true } label: {
                Label("记今日体重", systemImage: "scalemass")
            }
            Button { showSessionSheet = true } label: {
                Label("记一次训练", systemImage: "dumbbell.fill")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                Text("添加记录")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 18)
            .frame(height: 44)
            .liquidGlassCapsule(tint: Color.black.opacity(0.58))
        }
    }

    private func importPhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        store.savePhotoMemory(image: image, caption: "相册导入", category: "meal")
        selectedPhotoItem = nil
        toast = "已添加到图片库"
    }
}

// MARK: - 原有训练分析 + 跑步足迹详情（从训练记录卡片进入）

struct TrainingAndRoutesDetailView: View {
    @EnvironmentObject private var store: AppStore
    @State private var tab = 0
    @State private var selectedRun: RouteRun?

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    Picker("", selection: $tab) {
                        Text("力量与容量").tag(0)
                        Text("跑步足迹").tag(1)
                    }
                    .pickerStyle(.segmented)

                    if tab == 0 {
                        strengthSection
                    } else {
                        runsGrid
                    }
                }
                .padding(.horizontal, Metrics.page)
                .padding(.bottom, Metrics.floatingTabBottomInset + 16)
            }
        }
        .navigationTitle("训练与足迹")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedRun) { run in
            RouteDetailView(run: run)
        }
    }

    private var strengthSection: some View {
        let data = store.weeklyVolume
        let balance = ProgressiveEngine.weeklySetBalance(sessions: store.state.sessions)
        let maxSets = max(1, balance.values.max() ?? 1)
        let lifts = ["杠铃卧推", "深蹲", "罗马尼亚硬拉", "站姿推举"]

        return VStack(spacing: 14) {
            HStack(spacing: 10) {
                StatTile(value: "\(store.streak)", label: "连续天数", tint: Palette.green)
                StatTile(value: "\(store.state.sessions.count)", label: "总训练", tint: Palette.text)
                StatTile(value: "\(Int(store.state.sessions.reduce(0) { $0 + $1.totalVolume } / 1000))t", label: "累计容量", tint: Palette.blue)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("每周容量")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.text)
                if data.isEmpty {
                    Text("练两次就会有曲线").font(.system(size: 13)).foregroundStyle(Palette.textFaint)
                } else {
                    Chart(data) { item in
                        BarMark(x: .value("周", item.week, unit: .weekOfYear), y: .value("容量", item.volume))
                            .foregroundStyle(Palette.green)
                            .cornerRadius(6)
                    }
                    .frame(height: 140)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                }
            }
            .padding(16)
            .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)

            VStack(alignment: .leading, spacing: 10) {
                Text("本周肌群分布").font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.text)
                ForEach(MuscleGroup.allCases) { group in
                    let sets = balance[group] ?? 0
                    if sets > 0 {
                        HStack(spacing: 10) {
                            Text(group.rawValue).font(.system(size: 12, weight: .medium)).foregroundStyle(group.tint).frame(width: 34, alignment: .leading)
                            BarProgress(progress: Double(sets) / Double(maxSets), color: group.tint, height: 6)
                            Text("\(sets)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(Palette.textDim).frame(width: 24, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(16)
            .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)

            VStack(alignment: .leading, spacing: 10) {
                Text("主力动作 1RM").font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.text)
                ForEach(lifts, id: \.self) { name in
                    let history = store.history(for: name)
                    let e1rm = history.last?.e1rm ?? 0
                    let best = history.map(\.e1rm).max() ?? 0
                    HStack {
                        Text(name).font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.text)
                        Spacer()
                        Text(history.isEmpty ? "—" : "\(Int(e1rm)) kg").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Palette.text)
                        Text(history.isEmpty ? "" : "最好 \(Int(best))").font(.system(size: 11)).foregroundStyle(Palette.textFaint).frame(width: 62, alignment: .trailing)
                    }
                }
            }
            .padding(16)
            .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
        }
    }

    private var runsGrid: some View {
        Group {
            if store.state.runs.isEmpty {
                EmptyHint(icon: "map", title: "还没有轨迹", message: "跑一次，就会留下一条线。")
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(store.state.runs) { run in
                        Button {
                            selectedRun = run
                        } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                RouteArtView(points: run.points, style: run.style, lineWidth: 2.4)
                                    .frame(height: 118)
                                    .background(Palette.cardSoft)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(run.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.text).lineLimit(1)
                                    Text(String(format: "%.2f km · %@", run.distanceM / 1000, run.style.title))
                                        .font(.system(size: 11, design: .rounded)).foregroundStyle(Palette.textFaint)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .card(radius: 20, fill: Palette.card, stroke: Palette.stroke)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - 辅助 Sheets（相册、体重、全部亮点、安全相机选择器）

private struct PhotoGallerySheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                if store.state.photoMemories.isEmpty {
                    EmptyHint(icon: "photo.stack", title: "图片库还是空的", message: "在记录页点「图片库 +」即可拍照或导入打卡照片。")
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                            ForEach(store.state.photoMemories) { item in
                                if let img = store.loadPhotoImage(fileName: item.fileName) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 116)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                store.deletePhotoMemory(id: item.id)
                                            } label: {
                                                Label("删除照片", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                        .padding(Metrics.page)
                    }
                }
            }
            .navigationTitle("图片库")
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

private struct WeightLogSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var kgText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("今日体重 (kg)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.textDim)
                        TextField("75.0", text: $kgText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.text)
                            .padding(14)
                            .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
                    }

                    PrimaryButton(title: "保存体重", enabled: Double(kgText) != nil, tint: Palette.green) {
                        if let val = Double(kgText) {
                            store.recordWeight(val)
                            dismiss()
                        }
                    }
                    Spacer()
                }
                .padding(Metrics.page)
            }
            .navigationTitle("记录体重")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
        }
        .onAppear {
            kgText = String(format: "%.1f", store.state.profile.weightKg)
        }
        .preferredColorScheme(.dark)
    }
}

private struct AllInsightsSheet: View {
    let items: [HealthInsightItem]
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [HealthInsightItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return items }
        return items.filter { $0.category.localizedCaseInsensitiveContains(q) || $0.headline.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(filtered) { item in
                            HealthInsightRowView(item: item)
                            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.6)
                        }
                    }
                    .padding(Metrics.page)
                }
            }
            .searchable(text: $query, prompt: "筛选亮点指标")
            .navigationTitle("全部亮点（\(items.count)）")
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

struct SafeCameraPicker: UIViewControllerRepresentable {
    var onPicked: (UIImage) -> Void
    var onUnavailable: () -> Void
    var onClose: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
            DispatchQueue.main.async { onUnavailable() }
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: SafeCameraPicker
        init(parent: SafeCameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.onPicked(img)
            }
            parent.onClose()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onClose()
        }
    }
}
