import SwiftUI
import MapKit
import Combine

enum RunCenterSubTab: String, CaseIterable, Identifiable {
    case home = "主页"
    case mine = "我的"

    var id: String { rawValue }
}

struct RunCenterView: View {
    @EnvironmentObject private var store: AppStore

    @State private var subTab: RunCenterSubTab = .home
    @State private var selectedCategory: SportCategory? = nil
    @State private var searchQuery: String = ""
    @State private var showGPSRun = false
    @State private var activeSportTimer: SportPreset? = nil
    @State private var toast: String?
    @Namespace private var catFilterNS

    var body: some View {
        ZStack(alignment: .top) {
            Palette.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部留白给 HomeTopSegmentBar，再接二级吸顶 Tab（主页 | 我的）
                subTabBar
                    .padding(.top, 60)

                Group {
                    switch subTab {
                    case .home:
                        sportsListView
                    case .mine:
                        runMineView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.snappy(duration: 0.24), value: subTab)
            }
        }
        .sensoryFeedback(.selection, trigger: subTab)
        .sheet(isPresented: $showGPSRun) {
            RunCaptureView()
        }
        .sheet(item: $activeSportTimer) { sport in
            IndoorSportTimerSheet(sport: sport) { msg in
                toast = msg
            }
            .strideSheetDetents([.medium, .large])
        }
        .toast($toast)
    }

    // MARK: - 二级吸顶 Tab

    private var subTabBar: some View {
        HStack(spacing: 36) {
            ForEach(RunCenterSubTab.allCases) { item in
                let active = subTab == item
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        subTab = item
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(item.rawValue)
                            .font(.system(size: 15, weight: active ? .bold : .medium))
                            .foregroundStyle(active ? Palette.text : Palette.textDim)
                        Capsule()
                            .fill(active ? Palette.lime : Color.clear)
                            .frame(width: 28, height: 3)
                            .animation(.snappy(duration: 0.22), value: active)
                    }
                    .padding(.top, 8)
                }
                .buttonStyle(.stridePress)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Palette.bg.opacity(0.9))
    }

    // MARK: - 45 项全品类运动列表（新增分类磁吸筛选与实时搜索）

    private var sportsListView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // 搜索与分类筛选胶囊栏
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Palette.textDim)
                    TextField("搜索 45 项运动（如 跑步、游泳、羽毛球）", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Palette.text)
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Palette.textFaint)
                        }
                        .buttonStyle(.stridePress)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .card(radius: 14, fill: Palette.card, stroke: Palette.stroke)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryFilterChip(title: "全部", category: nil)
                        ForEach(SportCategory.allCases) { cat in
                            categoryFilterChip(title: cat.rawValue, category: cat)
                        }
                    }
                }
                .sensoryFeedback(.selection, trigger: selectedCategory)

                let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

                if selectedCategory == nil && query.isEmpty {
                    // 核心跑步 5 项（无分类头）
                    VStack(spacing: 10) {
                        ForEach(SportsCatalog.items(in: .featuredRun)) { sport in
                            sportLaunchCard(sport)
                        }
                    }

                    // 其余 5 个分组：户外 11、室内有氧 10、球类 13、格斗 3、身心 3
                    ForEach([SportCategory.outdoor, .indoorCardio, .ballSports, .combat, .mindBody]) { category in
                        let list = SportsCatalog.items(in: category)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 7) {
                                Image(systemName: category.headerIcon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Palette.lime)
                                Text(category.rawValue)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Palette.text)
                                Text("\(list.count)")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(Palette.textFaint)
                            }
                            .padding(.top, 4)

                            ForEach(list) { sport in
                                sportLaunchCard(sport)
                            }
                        }
                    }
                } else {
                    let filtered = SportsCatalog.all.filter { item in
                        let catMatch = selectedCategory == nil || item.category == selectedCategory
                        let qMatch = query.isEmpty || item.name.localizedCaseInsensitiveContains(query)
                        return catMatch && qMatch
                    }
                    if filtered.isEmpty {
                        EmptyHint(icon: "figure.run", title: "没有找到对应运动", message: "试试切换上方分类标签或清空搜索词。")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(filtered) { sport in
                                sportLaunchCard(sport)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.page)
            .padding(.top, 10)
            .padding(.bottom, Metrics.floatingTabBottomInset + 16)
        }
    }

    private func categoryFilterChip(title: String, category: SportCategory?) -> some View {
        let active = selectedCategory == category
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                selectedCategory = category
            }
        } label: {
            Text(title)
                .font(.system(size: 12.5, weight: active ? .bold : .medium))
                .foregroundStyle(active ? Color.black : Palette.textDim)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background {
                    if active {
                        Capsule()
                            .fill(Palette.lime)
                            .matchedGeometryEffect(id: "runSportCategoryChip", in: catFilterNS)
                    } else {
                        Capsule().fill(Palette.card)
                    }
                }
        }
        .buttonStyle(.stridePress)
    }

    private func sportLaunchCard(_ sport: SportPreset) -> some View {
        Button {
            if sport.usesGPS && (sport.category == .featuredRun || sport.id == "out.walk" || sport.id == "out.cycle" || sport.id == "out.hike") {
                showGPSRun = true
            } else {
                activeSportTimer = sport
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: sport.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Palette.lime)
                    .frame(width: 34)

                Text(sport.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.text)

                Spacer()

                Circle()
                    .fill(Palette.lime)
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Color.black)
                            .offset(x: 1)
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .luxuryCard(radius: 20, accent: Palette.lime, glowCorner: .topTrailing, fill: Color(hex: 0x13151D))
        }
        .buttonStyle(.strideCard(radius: 20))
        .strideScrollDepth(minScale: 0.96, minOpacity: 0.85)
    }

    // MARK: - 「我的」子视图（领地、图层、12 周报告、隐私区，图 19）

    private var runMineView: some View {
        let territory = TerritoryCalculator.summary(runs: store.state.runs)

        return ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                NavigationLink {
                    TerritoryDetailView()
                } label: {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(Color.white.opacity(0.92))
                            .frame(width: 48, height: 48)
                            .overlay {
                                Text(String(store.state.profile.nickname.prefix(1)).uppercased())
                                    .font(.system(size: 20, weight: .heavy))
                                    .foregroundStyle(Color.black)
                            }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.state.profile.nickname)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Palette.text)
                            Text(String(format: "领地 %d 格 · %.2f km²", territory.cellCount, territory.areaKm2))
                                .font(.system(size: 12.5))
                                .foregroundStyle(Palette.textDim)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.textFaint)
                    }
                    .padding(16)
                    .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
                }
                .buttonStyle(.strideCard(radius: 22))

                // 分组 1：领地与报告
                VStack(spacing: 0) {
                    NavigationLink {
                        TerritoryMapView()
                    } label: {
                        SettingRow(icon: "map", title: "领地地图", value: "\(territory.cellCount) 格", tint: Palette.lime)
                    }
                    .buttonStyle(.strideRow(radius: 14))
                    runDivider

                    Menu {
                        Button("标准") { store.state.runMapStyleRaw = "standard" }
                        Button("混合卫星") { store.state.runMapStyleRaw = "hybrid" }
                        Button("极简暗黑") { store.state.runMapStyleRaw = "dark" }
                    } label: {
                        SettingRow(icon: "square.2.layers.3d", title: "底图图层", value: mapStyleTitle, tint: Palette.text)
                    }
                    runDivider

                    NavigationLink {
                        TerritoryDetailView()
                    } label: {
                        SettingRow(icon: "flag.fill", title: "我的领地", value: String(format: "%.2f km²", territory.areaKm2), tint: Palette.text)
                    }
                    .buttonStyle(.strideRow(radius: 14))
                    runDivider

                    NavigationLink {
                        RunTwelveWeekReportView()
                    } label: {
                        SettingRow(icon: "chart.xyaxis.line", title: "跑步报告", value: "最近 12 周", tint: Palette.text)
                    }
                    .buttonStyle(.strideRow(radius: 14))
                }
                .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)

                // 分组 2：隐私与定位
                VStack(spacing: 0) {
                    NavigationLink {
                        PrivacyZonesEditorView()
                    } label: {
                        SettingRow(icon: "eye.slash", title: "隐私区", value: "\(store.state.privacyZones.count) 个", tint: Palette.text)
                    }
                    .buttonStyle(.strideRow(radius: 14))
                    runDivider

                    NavigationLink {
                        RunLocationPrivacyInfoView()
                    } label: {
                        SettingRow(icon: "location", title: "位置与隐私", value: "仅本机", tint: Palette.text)
                    }
                    .buttonStyle(.strideRow(radius: 14))
                }
                .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
            }
            .padding(.horizontal, Metrics.page)
            .padding(.top, 10)
            .padding(.bottom, Metrics.floatingTabBottomInset + 16)
        }
    }

    private var mapStyleTitle: String {
        switch store.state.runMapStyleRaw {
        case "hybrid": return "卫星"
        case "dark": return "暗黑"
        default: return "标准"
        }
    }

    private var runDivider: some View {
        Rectangle()
            .fill(Palette.stroke)
            .frame(height: 0.5)
            .padding(.leading, 54)
    }
}

// MARK: - 领地网格计算器

enum TerritoryCalculator {
    /// 将经纬度离散到约 120m × 120m 领地网格，统计本地覆盖格数与等效面积（km²）
    static func summary(runs: [RouteRun], privacyZones: [PrivacyZone] = []) -> (cellCount: Int, areaKm2: Double) {
        var cells = Set<String>()
        for run in runs {
            for pt in filteredPoints(run.points, privacyZones: privacyZones) {
                let latIdx = Int(floor(pt.lat / 0.0011))
                let lonIdx = Int(floor(pt.lon / 0.0012))
                cells.insert("\(latIdx)_\(lonIdx)")
            }
        }
        let area = Double(cells.count) * 0.0144
        return (cells.count, (area * 100).rounded() / 100)
    }

    static func filteredPoints(_ points: [GeoPoint], privacyZones: [PrivacyZone]) -> [GeoPoint] {
        guard !privacyZones.isEmpty else { return points }
        return points.filter { pt in
            let loc = CLLocation(latitude: pt.lat, longitude: pt.lon)
            return !privacyZones.contains { zone in
                let center = CLLocation(latitude: zone.lat, longitude: zone.lon)
                return loc.distance(from: center) <= zone.radiusM
            }
        }
    }
}

// MARK: - 室内/专项运动计时记录 Sheet（覆盖非 GPS 的 35+ 种运动）

private struct IndoorSportTimerSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let sport: SportPreset
    var onSaved: (String) -> Void

    @State private var elapsedSec = 0
    @State private var running = false
    @State private var manualMinutes: Int = 30
    @State private var intensity: WorkoutIntensity = .moderate

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var effectiveSeconds: Int {
        elapsedSec > 0 ? elapsedSec : manualMinutes * 60
    }

    private var estimatedKcal: Int {
        let hours = Double(effectiveSeconds) / 3600.0
        return max(10, Int((sport.met * store.state.profile.weightKg * hours).rounded()))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                VStack(spacing: 18) {
                    VStack(spacing: 10) {
                        Image(systemName: sport.icon)
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(Palette.lime)
                        Text(sport.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Palette.text)

                        Text(PluginMath.formatDuration(Double(elapsedSec)))
                            .font(.system(size: 46, weight: .heavy, design: .rounded))
                            .foregroundStyle(Palette.text)
                            .monospacedDigit()
                            .numericRoll(value: elapsedSec)

                        HStack(spacing: 12) {
                            Button {
                                running.toggle()
                            } label: {
                                Label {
                                    Text(running ? "暂停" : (elapsedSec > 0 ? "继续" : "开始计时"))
                                } icon: {
                                    Image(systemName: running ? "pause.fill" : "play.fill")
                                        .symbolEffect(.bounce, value: running)
                                }
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.black)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 11)
                                .background(Capsule().fill(Palette.lime))
                            }
                            .buttonStyle(StridePressButtonStyle(scale: 0.95, pressedOpacity: 0.9, haptic: .medium))

                            if elapsedSec > 0 {
                                Button("清零") {
                                    running = false
                                    elapsedSec = 0
                                }
                                .buttonStyle(.stridePress)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Palette.textDim)
                            }
                        }
                        .animation(.snappy(duration: 0.2), value: running)
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity)
                    .card(radius: 24, fill: Palette.card, stroke: Palette.stroke)

                    VStack(spacing: 12) {
                        Stepper("或手动填写时长：\(manualMinutes) 分钟", value: $manualMinutes, in: 5...240, step: 5)
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.text)

                        HStack {
                            Text("耗能强度")
                                .font(.system(size: 14))
                                .foregroundStyle(Palette.text)
                            Spacer()
                            Picker("", selection: $intensity) {
                                ForEach(WorkoutIntensity.allCases) { item in
                                    Text(item.rawValue).tag(item)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(intensity.color)
                        }

                        HStack {
                            Text("估算热量消耗")
                                .font(.system(size: 14))
                                .foregroundStyle(Palette.textDim)
                            Spacer()
                            Text("\(estimatedKcal) kcal")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Palette.lime)
                        }
                    }
                    .padding(16)
                    .card(radius: 20, fill: Palette.card, stroke: Palette.stroke)

                    Spacer()

                    PrimaryButton(title: "保存本次\(sport.name)", tint: Palette.lime) {
                        let kind: SessionKind = sport.category == .mindBody ? .mobility : (sport.id == "out.cycle" || sport.id == "in.cycle" ? .ride : .run)
                        let session = WorkoutSession(
                            date: Date(),
                            title: sport.name,
                            kind: kind,
                            exercises: [],
                            durationSec: effectiveSeconds,
                            kcal: estimatedKcal,
                            sportLabel: sport.name,
                            intensityRaw: intensity.rawValue
                        )
                        store.addSession(session)
                        onSaved("已记录 \(sport.name) · \(effectiveSeconds / 60) 分钟")
                        dismiss()
                    }
                }
                .padding(Metrics.page)
            }
            .navigationTitle(sport.category.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
            .onReceive(ticker) { _ in
                if running { elapsedSec += 1 }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - 「我的」子页面（领地地图、报告、隐私区）

private struct TerritoryMapView: View {
    @EnvironmentObject private var store: AppStore

    private var mapStyle: MapStyle {
        switch store.state.runMapStyleRaw {
        case "hybrid": return .hybrid
        case "dark": return .standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false)
        default: return .standard
        }
    }

    var body: some View {
        ZStack {
            Map {
                ForEach(store.state.runs) { run in
                    let pts = TerritoryCalculator.filteredPoints(run.points, privacyZones: store.state.privacyZones)
                    if pts.count > 1 {
                        MapPolyline(coordinates: pts.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) })
                            .stroke(Palette.lime, lineWidth: 4)
                    }
                }
                ForEach(store.state.privacyZones) { zone in
                    MapCircle(center: CLLocationCoordinate2D(latitude: zone.lat, longitude: zone.lon), radius: zone.radiusM)
                        .foregroundStyle(Palette.red.opacity(0.2))
                        .stroke(Palette.red, lineWidth: 1.5)
                }
            }
            .mapStyle(mapStyle)
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationTitle("领地地图")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TerritoryDetailView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        let info = TerritoryCalculator.summary(runs: store.state.runs, privacyZones: store.state.privacyZones)
        let totalKm = store.state.runs.reduce(0.0) { $0 + $1.distanceM / 1000.0 }
        ZStack {
            Palette.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        StatTile(value: "\(info.cellCount)", label: "点亮领地格", tint: Palette.lime)
                        StatTile(value: String(format: "%.2f", info.areaKm2), label: "面积 km²", tint: Palette.green)
                        StatTile(value: String(format: "%.1f", totalKm), label: "总跑量 km", tint: Palette.blue)
                    }
                    Text("按约 120m × 120m 网格把你的历史跑步轨迹离散为本机领地格，隐私区内轨迹会自动屏蔽。")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.textDim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Metrics.page)
            }
        }
        .navigationTitle("我的领地")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RunTwelveWeekReportView: View {
    @EnvironmentObject private var store: AppStore

    private struct WeekKmPoint: Identifiable {
        let id: Int
        let label: String
        let km: Double
    }

    var body: some View {
        let cal = Calendar.current
        let weeklyKm: [WeekKmPoint] = (0..<12).reversed().enumerated().map { idx, wOffset in
            let weekStart = cal.date(byAdding: .weekOfYear, value: -wOffset, to: cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()) ?? Date()
            let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) ?? Date()
            let km = store.state.runs.filter { $0.date >= weekStart && $0.date < weekEnd }.reduce(0.0) { $0 + $1.distanceM / 1000.0 }
            let f = DateFormatter(); f.dateFormat = "M/d"
            return WeekKmPoint(id: idx, label: f.string(from: weekStart), km: km)
        }

        return ZStack {
            Palette.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("最近 12 周跑量")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Palette.text)

                    InteractiveBarChartScrubber(
                        items: weeklyKm,
                        valueProvider: \.km,
                        labelProvider: \.label,
                        valueTextProvider: { String(format: "%.2f km", $0.km) },
                        barColor: Palette.lime,
                        height: 150
                    )
                    .padding(16)
                    .luxuryCard(radius: 22, accent: Palette.lime)
                }
                .padding(Metrics.page)
            }
        }
        .navigationTitle("跑步报告")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacyZonesEditorView: View {
    @EnvironmentObject private var store: AppStore
    @State private var name = "家附近"
    @State private var radius = 300.0

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("添加轨迹隐私区")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.text)
                        TextField("名称（如 家、公司）", text: $name)
                            .textFieldStyle(.plain)
                            .foregroundStyle(Palette.text)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.cardSoft))
                        Stepper("屏蔽半径：\(Int(radius)) 米", value: $radius, in: 100...1000, step: 50)
                            .foregroundStyle(Palette.text)
                        PrimaryButton(title: "以最近一次起点设为隐私区", tint: Palette.lime) {
                            let pt = store.state.runs.first?.points.first ?? GeoPoint(lat: 31.2304, lon: 121.4737)
                            store.addPrivacyZone(name: name.isEmpty ? "隐私区" : name, lat: pt.lat, lon: pt.lon, radiusM: radius)
                        }
                    }
                    .padding(16)
                    .card(radius: 20, fill: Palette.card, stroke: Palette.stroke)

                    ForEach(store.state.privacyZones) { zone in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(zone.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.text)
                                Text("半径 \(Int(zone.radiusM)) 米").font(.system(size: 12)).foregroundStyle(Palette.textDim)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                store.removePrivacyZone(id: zone.id)
                            } label: {
                                Image(systemName: "trash").foregroundStyle(Palette.red)
                            }
                            .buttonStyle(.stridePress)
                        }
                        .padding(14)
                        .card(radius: 16, fill: Palette.card, stroke: Palette.stroke)
                    }
                }
                .padding(Metrics.page)
            }
        }
        .navigationTitle("隐私区")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RunLocationPrivacyInfoView: View {
    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Text("位置数据仅保存在本机")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.text)
                Text("跑步 GPS 点位、领地格计算和隐私区过滤全部在你的 iPhone 本地完成，不会上传到任何服务器。")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textDim)
                Spacer()
            }
            .padding(Metrics.page)
        }
        .navigationTitle("位置与隐私")
        .navigationBarTitleDisplayMode(.inline)
    }
}
