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

    @State private var toast: String?
    @State private var syncing = false
    @State private var showExporter = false
    @State private var exportDocument: BackupFileDocument?
    @State private var showImporter = false
    @State private var showImportConfirm = false
    @State private var pendingImportData: Data?
    @State private var showRestoreDialog = false
    @State private var restoreCandidates: [URL] = []

    private var profile: Profile { store.state.profile }

    /// 版本号从 Bundle 读，构建脚本注入，不再写死
    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    profileCard
                    statsRow
                    accountSection
                    toolSection
                    backupSection
                    aboutSection
                }
                .padding(.horizontal, Metrics.page)
                .padding(.bottom, Metrics.floatingTabBottomInset + 16)
            }
        }
        .navigationTitle("自己")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Palette.bg, for: .navigationBar)
        .toast($toast)
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

    // MARK: - 数据备份

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
                    Button {
                        store.dataIssue = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Palette.textFaint)
                    }
                    .buttonStyle(.plain)
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
            .buttonStyle(.plain)

            divider

            Button {
                showImporter = true
            } label: {
                SettingRow(icon: "square.and.arrow.down", title: "导入备份", value: "JSON", tint: Palette.green)
            }
            .buttonStyle(.plain)

            if !autoBackups.isEmpty {
                divider

                Button {
                    restoreCandidates = autoBackups
                    showRestoreDialog = true
                } label: {
                    SettingRow(icon: "arrow.counterclockwise", title: "恢复自动备份", value: "\(autoBackups.count) 个", tint: Palette.amber)
                }
                .buttonStyle(.plain)
            }
        }
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
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

    // MARK: - 资料

    private var profileCard: some View {
        NavigationLink {
            ProfileEditView()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Palette.green.opacity(0.35), Palette.blue.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 62, height: 62)
                    Text(String(profile.nickname.prefix(1)).uppercased())
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(Palette.text)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.nickname)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Palette.text)
                    Text("\(profile.goal.rawValue) · 每周 \(profile.daysPerWeek) 练 · \(profile.experience.rawValue)")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textDim)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textFaint)
            }
            .padding(16)
            .card(radius: 24, fill: Palette.card, stroke: Palette.stroke)
        }
        .buttonStyle(.plain)
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(value: "\(store.state.sessions.count)", label: "训练")
            StatTile(value: "\(store.streak)", label: "连续")
            StatTile(value: "\(store.state.runs.count)", label: "轨迹")
        }
    }

    // MARK: - 账户 / 连接

    private var accountSection: some View {
        VStack(spacing: 0) {
            NavigationLink {
                AISettingsView()
            } label: {
                SettingRow(
                    icon: "sparkles",
                    title: "AI 服务",
                    value: ai.isConfigured ? ai.config.chatModel : "未配置",
                    tint: Palette.purple
                )
            }
            .buttonStyle(.plain)

            divider

            Button {
                syncHealth()
            } label: {
                SettingRow(
                    icon: "heart.fill",
                    title: "Apple 健康",
                    value: syncing ? "同步中…" : (health.authorized ? "已授权" : "未授权"),
                    tint: Palette.red
                )
            }
            .buttonStyle(.plain)

            divider

            Button {
                watch.activate()
                toast = watch.supported ? "手表桥接已启动" : "这台设备不支持 Watch 连接"
            } label: {
                SettingRow(
                    icon: "applewatch",
                    title: "Apple Watch",
                    value: watch.reachable ? "在线" : (watch.supported ? "已配对未连接" : "不可用"),
                    tint: Palette.green
                )
            }
            .buttonStyle(.plain)

            divider

            NavigationLink {
                PlaylistImportView()
            } label: {
                SettingRow(icon: "music.note.list", title: "歌单链接导入", value: "解析", tint: Palette.pink)
            }
            .buttonStyle(.plain)

            divider

            NavigationLink {
                LyricsView()
            } label: {
                SettingRow(icon: "text.alignleft", title: "歌词同步", value: "不限次数", tint: Palette.blue)
            }
            .buttonStyle(.plain)
        }
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    private var toolSection: some View {
        VStack(spacing: 0) {
            NavigationLink {
                PluginsView()
            } label: {
                SettingRow(icon: "square.grid.2x2", title: "插件市场", value: "4 个小工具", tint: Palette.amber)
            }
            .buttonStyle(.plain)

            divider

            NavigationLink {
                RepCounterView()
            } label: {
                SettingRow(icon: "figure.strengthtraining.functional", title: "视觉动作计数", value: "相机", tint: Palette.green)
            }
            .buttonStyle(.plain)

            divider

            NavigationLink {
                PlanEditorView()
            } label: {
                SettingRow(icon: "calendar", title: "训练计划", value: "\(profile.daysPerWeek) 天/周", tint: Palette.blue)
            }
            .buttonStyle(.plain)
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
            .buttonStyle(.plain)
        }
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    private var divider: some View {
        Rectangle()
            .fill(Palette.stroke)
            .frame(height: 0.5)
            .padding(.leading, 54)
    }

    private func syncHealth() {
        syncing = true
        Task {
            if !health.authorized {
                await health.requestAuthorization()
            }
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
