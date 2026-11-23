import SwiftUI
import UniformTypeIdentifiers

/// 备份导出用的文件文档（系统保存框，存到文件 App）。
private struct BackupFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        .init(regularFileWithContents: data)
    }
}

struct MeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var ai: AISettings
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var watch: WatchSession
    @EnvironmentObject private var headphone: HeadphoneMotionManager
    @EnvironmentObject private var watchMotion: WatchMotionSessionController

    @State private var toast: String?
    @State private var syncing = false
    @State private var showExporter = false
    @State private var exportDocument: BackupFileDocument?
    @State private var showImporter = false
    @State private var showImportConfirm = false
    @State private var pendingImportData: Data?
    @State private var showRestoreDialog = false
    @State private var restoreCandidates: [URL] = []

    @State private var showSettingsSheet = false
    @State private var showProfileEdit = false
    @State private var showCoachSheet = false
    @State private var showInjurySheet = false
    @State private var showHeartRateSheet = false
    @State private var showWidgetGuideSheet = false
    @State private var showBrandAlert = false

    private var profile: Profile { store.state.profile }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.1"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        ZStack(alignment: .top) {
            Palette.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    avatarHeader

                    if store.state.showWidgetGuideCard {
                        widgetGuideCard
                    }

                    // Stride Intelligence 炫彩入口
                    intelligenceCard

                    // 提醒 & 设备
                    deviceAndReminderSection

                    // 数据与动作（趋势数据 / 训练负荷 / 动作库）
                    analyticsAndLibrarySection

                    // 个人体能档案（心率区间 / 经验 / 目标 / 伤病规避 / 训练重量 / 数据同步）
                    trainingProfileSection

                    // v1.2 数据备份与安全隔离提示（完整保留）
                    backupSection

                    // 关于与工具
                    aboutSection
                }
                .padding(.horizontal, Metrics.page)
                .padding(.top, 56)
                .padding(.bottom, Metrics.floatingTabBottomInset + 16)
            }

            // 顶部左右悬浮液态玻璃控件（图 78）
            topFloatingControls
        }
        .toolbar(.hidden, for: .navigationBar)
        .toast($toast)
        .fullScreenCover(isPresented: $showSettingsSheet) {
            SettingsView()
        }
        .navigationDestination(isPresented: $showProfileEdit) {
            ProfileEditView()
        }
        .sheet(isPresented: $showCoachSheet) {
            NavigationStack { CoachView() }
                .strideSheetDetents([.large])
        }
        .sheet(isPresented: $showInjurySheet) {
            InjuryAvoidEditorSheet()
                .strideSheetDetents([.medium, .large])
        }
        .sheet(isPresented: $showHeartRateSheet) {
            MaxHeartRateEditorSheet()
                .strideSheetDetents([.medium, .large])
        }
        .sheet(isPresented: $showWidgetGuideSheet) {
            HomeWidgetManagerSheet()
                .strideSheetDetents([.medium, .large])
        }
        .alert("\(Brand.nameZH) · \(Brand.name)", isPresented: $showBrandAlert) {
            Button("好的", role: .cancel) {}
        } message: {
            Text("当前版本 \(appVersion)\n全功能已开放，所有记录仅存于本机。")
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: AppStore.exportFileName()
        ) { result in
            if case .failure(let error) = result {
                toast = error.localizedDescription
            } else {
                toast = "备份已保存"
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                guard url.startAccessingSecurityScopedResource() else {
                    toast = "打不开这个文件"
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                do {
                    pendingImportData = try Data(contentsOf: url)
                    showImportConfirm = true
                } catch {
                    toast = error.localizedDescription
                }
            case .failure(let error):
                toast = error.localizedDescription
            }
        }
        .alert("导入备份？", isPresented: $showImportConfirm) {
            Button("替换全部数据", role: .destructive) { doImport() }
            Button("取消", role: .cancel) { pendingImportData = nil }
        } message: {
            Text("导入会替换当前全部数据，当前数据会先自动备份。")
        }
        .confirmationDialog("恢复自动备份", isPresented: $showRestoreDialog) {
            ForEach(restoreCandidates.prefix(3), id: \.self) { url in
                Button(restoreDisplayName(url)) { restoreBackup(url) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("会先自动备份当前数据，再整体替换。")
        }
    }

    // MARK: - 顶部左右液态玻璃悬浮操作栏

    private var topFloatingControls: some View {
        HStack {
            Button {
                showBrandAlert = true
            } label: {
                Text("STRIDE")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.text)
                    .frame(width: 46, height: 38)
                    .liquidGlassCapsule(tint: Color.black.opacity(0.45))
            }
            .buttonStyle(.stridePress)

            Spacer()

            HStack(spacing: 14) {
                Button {
                    showProfileEdit = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.text)
                }
                .buttonStyle(.stridePress)
                .accessibilityLabel("编辑资料")

                Button {
                    showSettingsSheet = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.text)
                }
                .buttonStyle(.stridePress)
                .accessibilityLabel("设置")
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            .liquidGlassCapsule(tint: Color.black.opacity(0.45))
        }
        .padding(.horizontal, Metrics.page)
        .padding(.top, 6)
    }

    // MARK: - 居中头像与昵称

    private var avatarHeader: some View {
        VStack(spacing: 10) {
            Button {
                showProfileEdit = true
            } label: {
                Circle()
                    .fill(Color.white)
                    .frame(width: 96, height: 96)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color(hex: 0xD1D1D6))
                    }
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
            }
            .buttonStyle(.stridePress)

            Text(profile.nickname)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Palette.text)

            Text("\(profile.goal.rawValue) · 每周 \(profile.daysPerWeek) 练 · \(store.state.sessions.count) 次记录")
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.textDim)
                .numericRoll(value: store.state.sessions.count)
        }
        .padding(.top, 4)
    }

    // MARK: - 添加小组件引导卡（图 78）

    private var widgetGuideCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Palette.blue)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("自定义首页看板小组件")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.text)
                Text("把饮水、肌肉恢复、咖啡因代谢和饮食小票排成你的专属首页。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.textDim)
                Button("立即开始") {
                    showWidgetGuideSheet = true
                }
                .buttonStyle(.stridePress)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.blue)
                .padding(.top, 2)
            }

            Spacer(minLength: 4)

            Button {
                withAnimation { store.state.showWidgetGuideCard = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textFaint)
            }
            .buttonStyle(.stridePress)
        }
        .padding(16)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - Stride Intelligence 炫彩声波入口（图 79）

    private var intelligenceCard: some View {
        VStack(spacing: 0) {
            Button {
                showCoachSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [Palette.amber, Palette.coralHi, Palette.purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: 30)

                    Text(Brand.intelligenceName)
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [Palette.coralHi, Palette.purple, Palette.blue], startPoint: .leading, endPoint: .trailing)
                        )

                    Spacer()

                    Text(ai.isConfigured ? "Gemini · 自动调度" : "本地教练")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.textDim)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.textFaint)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 15)
            }
            .buttonStyle(.strideRow(radius: 22))
        }
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 设备与提醒（图 78）

    private var deviceAndReminderSection: some View {
        VStack(spacing: 0) {
            NavigationLink {
                HeadphoneCompanionView()
            } label: {
                SettingRow(
                    icon: "airpodspro",
                    title: "智能耳机 · 护颈与 3D",
                    value: headphone.isHeadphoneConnected
                        ? "\(headphone.activeModel.shortTag) · \(HeadphoneCompanionStore.formatDuration(headphone.todayCompanionSec))"
                        : "今日 \(HeadphoneCompanionStore.formatDuration(headphone.todayCompanionSec))",
                    tint: Palette.blue
                )
            }
            .buttonStyle(.strideRow(radius: 14))

            divider

            NavigationLink {
                WatchMotionStudioView()
            } label: {
                SettingRow(
                    icon: "applewatch",
                    title: "手表动作识别与计次",
                    value: watch.reachable
                        ? "已连接 · \(watchMotion.repCount) 次"
                        : (watchMotion.isRunning ? "识别中 · \(watchMotion.repCount) 次" : "10 动作模型"),
                    tint: Palette.green
                )
            }
            .buttonStyle(.strideRow(radius: 14))

            divider

            NavigationLink {
                PlaylistImportView()
            } label: {
                SettingRow(icon: "music.note.list", title: "歌单链接导入", value: "解析 BPM", tint: Palette.pink)
            }
            .buttonStyle(.strideRow(radius: 14))

            divider

            NavigationLink {
                LyricsView()
            } label: {
                SettingRow(icon: "text.alignleft", title: "LRC 歌词同步", value: "不限次数", tint: Palette.blue)
            }
            .buttonStyle(.strideRow(radius: 14))
        }
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 趋势数据 / 训练负荷 / 动作库（图 79）

    private var analyticsAndLibrarySection: some View {
        VStack(spacing: 0) {
            NavigationLink {
                TrainingAndRoutesDetailView()
            } label: {
                SettingRow(icon: "chart.bar.xaxis", title: "趋势数据", value: "\(store.state.sessions.count) 练", tint: Palette.text)
            }
            .buttonStyle(.strideRow(radius: 14))

            divider

            NavigationLink {
                RepCounterView()
            } label: {
                SettingRow(icon: "figure.strengthtraining.functional", title: "视觉动作计数", value: "相机", tint: Palette.lime)
            }
            .buttonStyle(.strideRow(radius: 14))

            divider

            NavigationLink {
                ExerciseLibraryView { _ in }
            } label: {
                SettingRow(icon: "books.vertical", title: "动作库", value: "\(store.state.exercises.count) 个动作", tint: Palette.text)
            }
            .buttonStyle(.strideRow(radius: 14))
        }
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 个人体能档案（图 79–80）

    private var trainingProfileSection: some View {
        let injuryText = profile.injuryAvoidAreas.isEmpty ? "无" : profile.injuryAvoidAreas.joined(separator: "、")
        let benchPR = store.personalBest(for: "杠铃卧推")
        let weightText = benchPR > 0 ? "卧推 \(Int(benchPR))kg" : "未设置"

        return VStack(spacing: 0) {
            Button { showHeartRateSheet = true } label: {
                SettingRow(icon: "heart.text.square", title: "心率区间", value: "\(profile.maxHeartRate) bpm", tint: Palette.coralHi)
            }
            .buttonStyle(.strideRow(radius: 14))

            divider

            NavigationLink { ProfileEditView() } label: {
                SettingRow(icon: "chart.line.uptrend.xyaxis", title: "健身经验", value: profile.experience.rawValue, tint: Palette.text)
            }
            .buttonStyle(.strideRow(radius: 14))

            divider

            NavigationLink { ProfileEditView() } label: {
                SettingRow(icon: "target", title: "健身目标", value: profile.goal.rawValue, tint: Palette.text)
            }
            .buttonStyle(.strideRow(radius: 14))

            divider

            Button { showInjurySheet = true } label: {
                SettingRow(icon: "bandage", title: "受伤区域与避免区域", value: injuryText, tint: Palette.amber)
            }
            .buttonStyle(.strideRow(radius: 14))

            divider

            NavigationLink { TrainingAndRoutesDetailView() } label: {
                SettingRow(icon: "dumbbell", title: "训练重量参考", value: weightText, tint: Palette.text)
            }
            .buttonStyle(.strideRow(radius: 14))

            divider

            Button { syncHealth() } label: {
                SettingRow(
                    icon: "heart.fill",
                    title: "数据同步",
                    value: syncing ? "同步中…" : (health.authorized ? "Apple 健康 · 已授权" : "Apple 健康"),
                    tint: Palette.red
                )
            }
            .buttonStyle(.strideRow(radius: 14))
        }
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - v1.2 数据备份与损坏隔离提示

    private var dataIssueMessage: String? {
        switch store.dataIssue {
        case .corruptFileQuarantined(let name):
            return "上次启动发现数据文件损坏，已隔离保存为 \(name)，原文件没有丢失。"
        case .fieldsClamped(let names):
            return "有几项身体数据超出合理范围，已按合理值修正（\(names.joined(separator: "、"))），你的训练记录都在。"
        case .corruptFileKept:
            return "数据文件损坏，隔离失败，已保留原文件，本次启动不会保存新数据。"
        case .none:
            return nil
        }
    }

    private var autoBackups: [URL] { store.autoBackupURLs() }

    private var backupSection: some View {
        VStack(spacing: 0) {
            if let message = dataIssueMessage {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.red)
                    Text(message)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button { store.dataIssue = nil } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Palette.textFaint)
                    }
                    .buttonStyle(.stridePress)
                    .accessibilityLabel("知道了")
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                divider
            }

            Button {
                do {
                    exportDocument = BackupFileDocument(data: try store.exportData())
                    showExporter = true
                } catch {
                    toast = error.localizedDescription
                }
            } label: {
                SettingRow(icon: "square.and.arrow.up", title: "导出备份", value: "JSON", tint: Palette.blue)
            }
            .buttonStyle(.strideRow(radius: 14))

            divider

            Button { showImporter = true } label: {
                SettingRow(icon: "square.and.arrow.down", title: "导入备份", value: "JSON", tint: Palette.green)
            }
            .buttonStyle(.strideRow(radius: 14))

            if !autoBackups.isEmpty {
                divider
                Button {
                    restoreCandidates = autoBackups
                    showRestoreDialog = true
                } label: {
                    SettingRow(icon: "arrow.counterclockwise", title: "恢复自动备份", value: "\(autoBackups.count) 个", tint: Palette.amber)
                }
                .buttonStyle(.strideRow(radius: 14))
            }
        }
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    private var aboutSection: some View {
        VStack(spacing: 0) {
            SettingRow(icon: "info.circle", title: "版本", value: appVersion, tint: Palette.textDim)
            divider
            SettingRow(icon: "lock.shield", title: "数据存储", value: "仅本机", tint: Palette.textDim)
            divider
            Button {
                store.resetTodayQuotas()
                toast = "今日额度已重置"
            } label: {
                SettingRow(icon: "arrow.counterclockwise", title: "重置今日额度", value: "", tint: Palette.textDim)
            }
            .buttonStyle(.strideRow(radius: 14))
        }
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    private var divider: some View {
        Rectangle()
            .fill(Palette.stroke)
            .frame(height: 0.5)
            .padding(.leading, 54)
    }

    private func restoreDisplayName(_ url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "state.backup-before-import-", with: "")
    }

    private func restoreBackup(_ url: URL) {
        do {
            try store.importData(Data(contentsOf: url))
            toast = "已恢复备份"
        } catch {
            toast = error.localizedDescription
        }
    }

    private func doImport() {
        guard let data = pendingImportData else { return }
        pendingImportData = nil
        do {
            try store.importData(data)
            toast = "备份已导入"
        } catch {
            toast = error.localizedDescription
        }
    }

    private func syncHealth() {
        syncing = true
        Task {
            if !health.authorized { await health.requestAuthorization() }
            let metrics = await health.todayMetrics()
            if metrics.steps > 0 || metrics.activeKcal > 0 {
                var snap = store.todaySnapshot
                snap.steps = max(snap.steps, metrics.steps)
                snap.activeKcal = max(snap.activeKcal, metrics.activeKcal)
                snap.restingHR = metrics.restingHR
                if metrics.weightKg > 0 { snap.weightKg = metrics.weightKg }
                if let idx = store.state.snapshots.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) {
                    store.state.snapshots[idx] = snap
                } else {
                    store.state.snapshots.append(snap)
                }
                store.saveNow()
                toast = "已同步今日健康数据"
            } else {
                toast = health.lastError ?? "没有拿到健康数据（模拟器常见）"
            }
            syncing = false
        }
    }
}

// MARK: - 伤病规避编辑器 & 最大心率编辑器

private struct InjuryAvoidEditorSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private let options = [
        "腕管综合征", "肩峰撞击", "腰椎下背不适", "膝关节髌腱",
        "肘关节网球肘", "踝关节旧伤", "颈椎紧张"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("勾选需要规避的部位，AI 教练在推荐动作和重量时会自动绕开高压动作。")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textDim)

                        ForEach(options, id: \.self) { area in
                            let on = store.state.profile.injuryAvoidAreas.contains(area)
                            Button {
                                if on {
                                    store.state.profile.injuryAvoidAreas.removeAll { $0 == area }
                                } else {
                                    store.state.profile.injuryAvoidAreas.append(area)
                                }
                            } label: {
                                HStack {
                                    Text(area)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Palette.text)
                                    Spacer()
                                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(on ? Palette.amber : Palette.textFaint)
                                        .symbolEffect(.bounce, value: on)
                                }
                                .padding(14)
                                .card(radius: 16, fill: Palette.card, stroke: on ? Palette.amber.opacity(0.45) : Palette.stroke)
                            }
                            .buttonStyle(.strideCard(radius: 16))
                        }
                    }
                    .sensoryFeedback(.selection, trigger: store.state.profile.injuryAvoidAreas.count)
                    .padding(Metrics.page)
                }
            }
            .navigationTitle("受伤与避免区域")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.foregroundStyle(Palette.amber)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct MaxHeartRateEditorSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let hr = Double(store.state.profile.maxHeartRate)
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                VStack(spacing: 14) {
                    Stepper("最大心率：\(store.state.profile.maxHeartRate) bpm", value: $store.state.profile.maxHeartRate, in: 140...220)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .padding(16)
                        .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)

                    VStack(spacing: 8) {
                        zoneRow("Z1 热身恢复 (50–60%)", "\(Int(hr * 0.5))–\(Int(hr * 0.6)) bpm", Palette.blue)
                        zoneRow("Z2 燃脂有氧 (60–70%)", "\(Int(hr * 0.6))–\(Int(hr * 0.7)) bpm", Palette.green)
                        zoneRow("Z3 耐力节奏 (70–80%)", "\(Int(hr * 0.7))–\(Int(hr * 0.8)) bpm", Palette.yellow)
                        zoneRow("Z4 乳酸阈值 (80–90%)", "\(Int(hr * 0.8))–\(Int(hr * 0.9)) bpm", Palette.amber)
                        zoneRow("Z5 无氧极限 (90–100%)", "\(Int(hr * 0.9))–\(Int(hr)) bpm", Palette.coralHi)
                    }
                    Spacer()
                }
                .padding(Metrics.page)
            }
            .navigationTitle("心率区间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.foregroundStyle(Palette.coralHi)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func zoneRow(_ name: String, _ range: String, _ color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(name).font(.system(size: 13.5, weight: .medium)).foregroundStyle(Palette.text)
            Spacer()
            Text(range).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(color)
        }
        .padding(13)
        .card(radius: 14, fill: Palette.card, stroke: Palette.stroke)
    }
}

// MARK: - 行

struct SettingRow: View {
    let icon: String
    let title: String
    var value: String = ""
    var tint: Color = Palette.text

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(tint.opacity(0.12)))

            Text(title)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(Palette.text)

            Spacer()

            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textFaint)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.textFaint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}
