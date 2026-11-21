import SwiftUI
import UniformTypeIdentifiers

private struct SettingsExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { .init(regularFileWithContents: data) }
}

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var watch: WatchSession
    @Environment(\.dismiss) private var dismiss

    @State private var syncingHealth = false
    @State private var showExporter = false
    @State private var exportDoc: SettingsExportDocument?
    @State private var showICloudInfo = false
    @State private var showStorageSheet = false
    @State private var showScienceSheet = false
    @State private var showPrivacySheet = false
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        appleHealthHeroCard
                        devicesSection
                        generalSection
                        trainingDataSection
                        scienceAndPrivacySection
                    }
                    .padding(.horizontal, Metrics.page)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Palette.text)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                }
            }
            .fileExporter(
                isPresented: $showExporter,
                document: exportDoc,
                contentType: .json,
                defaultFilename: AppStore.exportFileName()
            ) { result in
                if case .failure(let err) = result {
                    toast = err.localizedDescription
                } else {
                    toast = "数据已导出"
                }
            }
            .alert("iCloud 同步说明", isPresented: $showICloudInfo) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text("当前版本采用免签名本机部署（SideStore 免费证书无法开启 iCloud 容器权限）。所有训练、饮食、体重与照片数据均完整保存在本机，可使用「导出训练数据」定期备份 JSON。")
            }
            .sheet(isPresented: $showStorageSheet) {
                StorageDataSheet()
            }
            .sheet(isPresented: $showScienceSheet) {
                ScienceReferencesSheet()
            }
            .sheet(isPresented: $showPrivacySheet) {
                PrivacyControlSheet()
            }
            .toast($toast)
        }
        .preferredColorScheme(store.preferredColorSchemeOverride ?? .dark)
    }

    // MARK: - 顶部纯白 Apple Health 卡片（图 81）

    private var appleHealthHeroCard: some View {
        Button {
            syncHealthNow()
        } label: {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 58, height: 58)
                        .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            LinearGradient(colors: [Color(hex: 0xFF5A87), Color(hex: 0xFF2D55)], startPoint: .top, endPoint: .bottom)
                        )
                }
                .padding(.top, 10)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("简化健身追踪")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: 0x7A7A82))
                        Text("与 Apple Health 同步")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(hex: 0x111113))
                    }
                    Spacer()
                    if syncingHealth {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: health.authorized ? "checkmark" : "arrow.triangle.2.circlepath")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(hex: 0x111113))
                    }
                }
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 外设与视觉识别

    private var devicesSection: some View {
        VStack(spacing: 0) {
            Button {
                watch.activate()
                toast = watch.supported ? "Watch 桥接已唤醒" : "当前设备不支持 Apple Watch 连接"
            } label: {
                SettingRow(
                    icon: "applewatch",
                    title: "Apple Watch",
                    value: watch.reachable ? "● 已连接" : (watch.supported ? "未连接" : "不可用"),
                    tint: Palette.green
                )
            }
            .buttonStyle(.plain)

            rowDivider

            NavigationLink {
                RepCounterView()
            } label: {
                SettingRow(icon: "figure.strengthtraining.functional", title: "视觉动作计数", value: "相机识别", tint: Palette.lime)
            }
            .buttonStyle(.plain)
        }
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 通用偏好（语言 / 外观 / 单位 / 触感 / 提醒，图 82）

    private var generalSection: some View {
        VStack(spacing: 0) {
            Menu {
                Button("简体中文") { store.state.languageCode = "zh-Hans"; toast = "当前语言：简体中文" }
            } label: {
                SettingRow(icon: "globe", title: "语言", value: "中文", tint: Palette.text)
            }

            rowDivider

            Menu {
                Button("深色（默认）") { store.state.appearanceRaw = "dark" }
                Button("跟随系统") { store.state.appearanceRaw = "system" }
                Button("浅色") { store.state.appearanceRaw = "light" }
            } label: {
                SettingRow(icon: "circle.lefthalf.filled", title: "显示与外观", value: appearanceLabel, tint: Palette.text)
            }

            rowDivider

            Menu {
                Button("千克 (kg)") { store.state.profile.preferredUnit = "kg" }
                Button("磅 (lb)") { store.state.profile.preferredUnit = "lb" }
            } label: {
                SettingRow(icon: "scalemass", title: "常用单位", value: store.state.profile.preferredUnit, tint: Palette.text)
            }

            rowDivider

            Menu {
                Button("关闭") { store.state.hapticModeRaw = "off" }
                Button("仅必要") { store.state.hapticModeRaw = "necessary" }
                Button("全部反馈") { store.state.hapticModeRaw = "all" }
            } label: {
                SettingRow(icon: "iphone.radiowaves.left.and.right", title: "震动（触感反馈）", value: hapticLabel, tint: Palette.blue)
            }

            rowDivider

            HStack(spacing: 12) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.12)))
                Text("训练与饮水提醒")
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(Palette.text)
                Spacer()
                Toggle("", isOn: $store.state.remindersEnabled)
                    .labelsHidden()
                    .tint(Palette.green)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 训练与数据（导出 / iCloud 说明 / 存储清理）

    private var trainingDataSection: some View {
        VStack(spacing: 0) {
            NavigationLink {
                PlanEditorView()
            } label: {
                SettingRow(icon: "figure.run", title: "训练设置", value: "周计划", tint: Palette.text)
            }
            .buttonStyle(.plain)

            rowDivider

            Button {
                do {
                    exportDoc = SettingsExportDocument(data: try store.exportData())
                    showExporter = true
                } catch {
                    toast = error.localizedDescription
                }
            } label: {
                SettingRow(icon: "square.and.arrow.up", title: "导出训练数据", value: "JSON", tint: Palette.blue)
            }
            .buttonStyle(.plain)

            rowDivider

            Button {
                showICloudInfo = true
            } label: {
                SettingRow(icon: "icloud.fill", title: "iCloud 同步", value: "仅本机", tint: Palette.blue)
            }
            .buttonStyle(.plain)

            rowDivider

            Button {
                showStorageSheet = true
            } label: {
                SettingRow(icon: "externaldrive", title: "存储空间和数据", value: storageSummary, tint: Palette.text)
            }
            .buttonStyle(.plain)
        }
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 隐私与科学依据（图 83–84）

    private var scienceAndPrivacySection: some View {
        VStack(spacing: 0) {
            Button {
                showPrivacySheet = true
            } label: {
                SettingRow(icon: "lock.shield", title: "隐私控制", value: "本机优先", tint: Palette.text)
            }
            .buttonStyle(.plain)

            rowDivider

            Button {
                showScienceSheet = true
            } label: {
                SettingRow(icon: "function", title: "营养、健康与医学计算依据", value: "查看公式", tint: Palette.green)
            }
            .buttonStyle(.plain)
        }
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Palette.stroke)
            .frame(height: 0.5)
            .padding(.leading, 54)
    }

    private var appearanceLabel: String {
        switch store.state.appearanceRaw {
        case "light": return "浅色"
        case "system": return "跟随系统"
        default: return "深色"
        }
    }

    private var hapticLabel: String {
        switch store.state.hapticModeRaw {
        case "off": return "关闭"
        case "all": return "全部"
        default: return "仅必要"
        }
    }

    private var storageSummary: String {
        let kb = Double(store.localStorageBytes()) / 1024.0
        return kb >= 1024 ? String(format: "%.1f MB", kb / 1024.0) : String(format: "%.0f KB", max(1, kb))
    }

    private func syncHealthNow() {
        syncingHealth = true
        Task {
            if !health.authorized { await health.requestAuthorization() }
            let m = await health.todayMetrics()
            if m.steps > 0 || m.activeKcal > 0 {
                toast = "已同步 Apple 健康：\(m.steps) 步 / \(m.activeKcal) kcal"
            } else {
                toast = health.lastError ?? "未获取到健康数据（免费自签或模拟器常见）"
            }
            syncingHealth = false
        }
    }
}

// MARK: - 存储空间管理 / 隐私控制 / 科学依据弹窗

private struct StorageDataSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var clearedMsg: String?

    var body: some View {
        let totalBytes = store.localStorageBytes()
        let photoBytes = store.localStorageBytes(in: store.photosDirectoryURL)

        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        StatTile(value: formatBytes(totalBytes), label: "总占用空间", tint: Palette.blue)
                        StatTile(value: formatBytes(photoBytes), label: "图片库照片", tint: Palette.amber)
                    }

                    Text("训练、饮食、计划、插件设置均以原子写入方式保存在本机 Application Support/Stride/ 目录。")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.textDim)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let clearedMsg {
                        Text(clearedMsg)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.green)
                    }

                    Spacer()

                    Button {
                        let freed = store.clearPhotoCache()
                        clearedMsg = "已清理照片缓存（释放 \(formatBytes(freed))），训练与饮食文字记录不受影响。"
                    } label: {
                        Text("清理图片库缓存照片")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .card(radius: 18, fill: Palette.card, stroke: Palette.red.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                }
                .padding(Metrics.page)
            }
            .navigationTitle("存储空间和数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func formatBytes(_ b: Int64) -> String {
        let kb = Double(b) / 1024.0
        return kb >= 1024 ? String(format: "%.1f MB", kb / 1024.0) : String(format: "%.0f KB", max(1, kb))
    }
}

private struct PrivacyControlSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        privacyItem("纯本机数据架构", "你的训练记录、身体围度、餐饮照片、GPS 足迹均只保存在本地设备，步迹没有远端账号服务器。")
                        privacyItem("AI 钥匙串直连", "仅当你手动在「AI 服务」填写了 API 地址与 Key 时，请求才会直接发往你配置的接口端点，密钥存于系统 Keychain。")
                        privacyItem("拍照与视觉动作", "「视觉动作计数」完全通过系统 Vision 在端侧分析关节角度，不采集不上传任何视频帧。")
                    }
                    .padding(Metrics.page)
                }
            }
            .navigationTitle("隐私控制")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func privacyItem(_ title: String, _ desc: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.text)
            Text(desc).font(.system(size: 13)).foregroundStyle(Palette.textDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .card(radius: 16, fill: Palette.card, stroke: Palette.stroke)
    }
}

private struct ScienceReferencesSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let refs: [(String, String)] = [
        ("基础代谢 BMR", "采用 Mifflin-St Jeor (1990) 方程，结合活动系数 1.45 推算日总消耗 TDEE。"),
        ("最大力量 1RM", "采用 Epley、Brzycki、Lombardi 等 7 项经典力量举经验回归方程进行多模型估算。"),
        ("急慢性负荷 ACWR", "参考运动医学 Gabbett (2016) 模型：近 7 天平均训练负荷 / 近 28 天平均基线，0.8–1.3 为理想甜区。"),
        ("跑步能力 VDOT", "依据 Jack Daniels 《丹尼尔斯经典跑步训练法》估算跑力值与 E/M/T/I/R 五档配速区间。"),
        ("咖啡因代谢模型", "按人体平均 5 小时半衰期指数衰减估算体内残余浓度，并结合预计入睡时间推算 7–10 小时前饮用窗口。"),
        ("体脂率估算", "采用美国海军围度法（Hodgdon & Beckett, 1984）对腰围、颈围、臀围与身高做对数回归估算。")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(refs, id: \.0) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.0).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.green)
                                Text(item.1).font(.system(size: 13)).foregroundStyle(Palette.textDim)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .card(radius: 16, fill: Palette.card, stroke: Palette.stroke)
                        }
                    }
                    .padding(Metrics.page)
                }
            }
            .navigationTitle("计算与科学依据")
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
