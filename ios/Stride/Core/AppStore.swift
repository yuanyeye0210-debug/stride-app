import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor
final class AppStore: ObservableObject {

    @Published var state: AppState {
        didSet { scheduleSave() }
    }

    /// 启动时发现的数据问题（例如 state.json 损坏已被隔离）。平时为 nil。
    @Published var dataIssue: DataIssue?

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?
    private let calendar = Calendar.current

    /// 隔离失败（原损坏文件还在原地）时为 true：本次启动不保存，避免覆盖原文件。
    private var saveSuppressed = false

    // MARK: - 生命周期

    /// 测试传入临时文件；正式启动不传，仍写到 Application Support。
    init(fileURL: URL? = nil) {
        let url: URL
        if let fileURL {
            url = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Stride", isDirectory: true)
            url = base.appendingPathComponent("state.json")
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        self.fileURL = url
        self.dataIssue = nil

        // 分流：解不开才算损坏（隔离）；能解码但个别字段越界时加载并修正，
        // 不隔离、不丢记录——身高/体重是用户手填的，填错一个数不能丢全部历史。
        var loaded: AppState? = nil
        var clampedFields: [String]? = nil
        if let data = try? Data(contentsOf: url),
           let decoded = try? Self.decoder().decode(AppState.self, from: data) {
            if (try? Backup.validate(decoded)) != nil {
                loaded = decoded
            } else {
                let (fixed, names) = Backup.clamped(decoded)
                loaded = fixed
                clampedFields = names
            }
        }

        let fileExists = FileManager.default.fileExists(atPath: url.path)
        let preserveFile: Bool
        if let decoded = loaded {
            self.state = decoded
            if let names = clampedFields, !names.isEmpty {
                self.dataIssue = .fieldsClamped(names)
            }
            preserveFile = false
        } else if fileExists {
            // 文件在但读不出来：改名隔离，永不删除、永不覆盖。
            // 隔离成功后可以正常建一个新 state.json；隔离失败才保留原文件不动。
            let name = Backup.quarantineName()
            let dest = url.deletingLastPathComponent().appendingPathComponent(name)
            if (try? FileManager.default.moveItem(at: url, to: dest)) != nil {
                print("[Stride] state.json 无法读取，已隔离为 \(name)，没有删除原文件")
                self.dataIssue = .corruptFileQuarantined(quarantinedName: name)
                var fresh = AppState()
                fresh.seeded = true
                self.state = fresh
                preserveFile = false
            } else {
                print("[Stride] state.json 无法读取，隔离失败，已保留原文件，本次启动不保存")
                self.saveSuppressed = true
                self.dataIssue = .corruptFileKept
                var preserved = AppState()
                preserved.seeded = true
                self.state = preserved
                preserveFile = true
            }
        } else {
            self.state = AppState()
            preserveFile = false
        }

        if !preserveFile {
            var needsSave = false
            if let names = clampedFields, !names.isEmpty {
                needsSave = true // 尽快把修正后的字段写回去
            }
            if !state.seeded {
                SeedData.seed(&state)
                state.seeded = true
                needsSave = true
            }
            let beforeStamp = state.weekStamp
            let beforeLast = state.lastWeekPlan
            rollWeekIfNeeded(now: Date())
            if state.weekStamp != beforeStamp || state.lastWeekPlan != beforeLast {
                needsSave = true
            }
            if needsSave { saveNow() }
        }
    }

    static func encoder() -> JSONEncoder {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }

    static func decoder() -> JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }

    // MARK: - 持久化

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        // 显式保存取代待处理的防抖保存：否则防抖任务 350ms 后触发时，
        // 会把调用 saveNow() 时的旧 state 重新写回文件，覆盖其间别的
        // AppStore 实例已经修正并写回的值（例如越界字段被钳制后又变回越界）。
        saveTask?.cancel()
        saveTask = nil
        guard !saveSuppressed else {
            print("[Stride] save suppressed: corrupt file kept in place")
            return
        }
        do {
            let data = try Self.encoder().encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[Stride] save failed:", error)
        }
    }

    // MARK: - 备份：导出 / 导入

    /// 导出当前全部数据（带版本号的信封）。只编码，不写盘、不改 state。
    func exportData() throws -> Data {
        try Backup.encode(state)
    }

    static func exportFileName(date: Date = Date(), timeZone: TimeZone = .current) -> String {
        Backup.exportFileName(date: date, timeZone: timeZone)
    }

    /// 导入备份：先校验（失败直接抛，原数据不动），再自动备份当前数据，
    /// 最后整体替换。导入的是整体替换，不是合并。
    /// 导入的数据本身就是真实用户数据，强制 seeded = true，绝不能触发演示播种。
    func importData(_ data: Data) throws {
        var imported = try Backup.decode(data)
        imported.seeded = true
        _ = try backupCurrentStateBeforeImport()
        state = imported
        saveNow()
    }

    /// 把当前 state 写一份带时间戳的备份到 state.json 同目录，原子写入。
    @discardableResult
    func backupCurrentStateBeforeImport() throws -> URL {
        let dest = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent(Backup.backupBeforeImportName())
        try Backup.encode(state).write(to: dest, options: .atomic)
        return dest
    }

    /// 同目录下的导入前自动备份，按文件名倒序（时间戳命名，文件名即时间顺序）。
    func autoBackupURLs() -> [URL] {
        let dir = fileURL.deletingLastPathComponent()
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return [] }
        return names
            .filter { $0.hasPrefix("state.backup-before-import-") }
            .sorted(by: >)
            .map { dir.appendingPathComponent($0) }
    }

    // MARK: - 派生数据

    var todaySessions: [WorkoutSession] {
        state.sessions.filter { calendar.isDateInToday($0.date) }
    }

    var weekSessions: [WorkoutSession] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }
        return state.sessions
            .filter { $0.date >= start }
            .sorted { $0.date > $1.date }
    }

    var recentSessions: [WorkoutSession] {
        state.sessions.sorted { $0.date > $1.date }
    }

    var todayNutrition: (kcal: Double, p: Double, c: Double, f: Double) {
        nutrition(on: Date())
    }

    func nutrition(on date: Date) -> (kcal: Double, p: Double, c: Double, f: Double) {
        let dayFoods = foods(on: date)
        return (
            dayFoods.reduce(0) { $0 + $1.kcal },
            dayFoods.reduce(0) { $0 + $1.protein },
            dayFoods.reduce(0) { $0 + $1.carbs },
            dayFoods.reduce(0) { $0 + $1.fat }
        )
    }

    func fiber(on date: Date) -> Double {
        foods(on: date).reduce(0) { $0 + $1.fiber }
    }

    func foods(on date: Date) -> [FoodEntry] {
        state.foods
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    var todayFoods: [FoodEntry] {
        foods(on: Date())
    }

    /// 今日剩余可摄入热量（目标 - 已吃）
    var remainingKcalToday: Int {
        state.profile.kcalTarget - Int(todayNutrition.kcal.rounded())
    }

    func carbTarget(on date: Date) -> Int {
        let base = max(120, Int((Double(state.profile.kcalTarget) * 0.42 / 4.0).rounded()))
        let weekday = calendar.component(.weekday, from: date)
        return state.carbCycle.targetGrams(for: weekday, fallback: base)
    }

    var todaySnapshot: DailySnapshot {
        if let s = state.snapshots.first(where: { calendar.isDateInToday($0.date) }) { return s }
        return DailySnapshot(date: Date(), steps: 0, activeKcal: 0, exerciseMin: 0, restingHR: 0, weightKg: state.profile.weightKg)
    }

    var streak: Int {
        var count = 0
        var day = calendar.startOfDay(for: Date())
        let days = Set(state.sessions.map { calendar.startOfDay(for: $0.date) })
        while days.contains(day) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    var weeklyVolume: [WeekVolume] {
        var buckets: [Date: Double] = [:]
        for s in state.sessions {
            guard let start = calendar.dateInterval(of: .weekOfYear, for: s.date)?.start else { continue }
            buckets[start, default: 0] += s.totalVolume
        }
        return buckets
            .map { WeekVolume(week: $0.key, volume: $0.value) }
            .sorted { $0.week < $1.week }
    }

    var kcalSeries: [(day: Date, kcal: Int)] {
        state.snapshots
            .sorted { $0.date < $1.date }
            .map { (day: $0.date, kcal: $0.activeKcal) }
    }

    func personalBest(for exerciseName: String) -> Double {
        state.sessions
            .flatMap(\.exercises)
            .filter { $0.name == exerciseName }
            .map(\.topWeight)
            .max() ?? 0
    }

    func history(for exerciseName: String) -> [(date: Date, e1rm: Double)] {
        var result: [(Date, Double)] = []
        for s in state.sessions.sorted(by: { $0.date < $1.date }) {
            for ex in s.exercises where ex.name == exerciseName {
                if let best = ex.doneSets.max(by: { $0.weight < $1.weight }), best.weight > 0 {
                    result.append((s.date, ProgressiveEngine.e1RM(weight: best.weight, reps: best.reps)))
                }
            }
        }
        return result
    }

    // MARK: - 变更

    func addSession(_ session: WorkoutSession) {
        state.sessions.insert(session, at: 0)
        if let idx = state.snapshots.firstIndex(where: { calendar.isDateInToday($0.date) }) {
            state.snapshots[idx].exerciseMin += max(1, session.durationSec / 60)
            state.snapshots[idx].activeKcal += session.kcal
        } else {
            state.snapshots.append(
                DailySnapshot(
                    date: Date(),
                    steps: 0,
                    activeKcal: session.kcal,
                    exerciseMin: max(1, session.durationSec / 60),
                    restingHR: 0,
                    weightKg: state.profile.weightKg
                )
            )
        }
        triggerHaptic(.success)
    }

    func deleteSession(id: UUID) {
        state.sessions.removeAll { $0.id == id }
    }

    func addFood(_ entry: FoodEntry) {
        state.foods.insert(entry, at: 0)
        triggerHaptic(.light)
    }

    func deleteFood(id: UUID) {
        state.foods.removeAll { $0.id == id }
    }

    func addRun(_ run: RouteRun) {
        state.runs.insert(run, at: 0)
        // 为当前激活中的第一双跑鞋自动累加里程
        if let idx = state.shoes.firstIndex(where: \.isActive) {
            state.shoes[idx].loggedKm += run.distanceM / 1000.0
        }
        triggerHaptic(.success)
    }

    func recordWeight(_ kg: Double, on date: Date = Date()) {
        let clamped = min(max(kg, Backup.validWeightKg.lowerBound), Backup.validWeightKg.upperBound)
        state.profile.weightKg = clamped
        if let idx = state.snapshots.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            state.snapshots[idx].weightKg = clamped
        } else {
            state.snapshots.append(DailySnapshot(date: date, weightKg: clamped))
        }
        triggerHaptic(.light)
    }

    // MARK: - 饮水

    func todayWaterMl(now: Date = Date()) -> Int {
        let key = WaterLog.dayKey(now, calendar: calendar)
        return state.waterDays.first { $0.day == key }?.ml ?? 0
    }

    func addWater(delta: Int, now: Date = Date()) {
        let key = WaterLog.dayKey(now, calendar: calendar)
        let next = WaterLog.adjusted(todayWaterMl(now: now), delta: delta)
        if let index = state.waterDays.firstIndex(where: { $0.day == key }) {
            state.waterDays[index].ml = next
        } else {
            state.waterDays.append(WaterDay(day: key, ml: next))
        }
        triggerHaptic(.light)
    }

    // MARK: - 补剂管理

    func addSupplement(_ item: SupplementItem) {
        guard !state.supplements.contains(where: { $0.name == item.name }) else { return }
        state.supplements.append(item)
    }

    func removeSupplement(id: UUID) {
        state.supplements.removeAll { $0.id == id }
        for idx in state.supplementLogs.indices {
            state.supplementLogs[idx].itemIDs.removeAll { $0 == id }
        }
    }

    func takenSupplementIDs(on date: Date = Date()) -> Set<UUID> {
        let key = WaterLog.dayKey(date, calendar: calendar)
        let ids = state.supplementLogs.first { $0.day == key }?.itemIDs ?? []
        return Set(ids)
    }

    func toggleSupplement(_ id: UUID, on date: Date = Date()) {
        let key = WaterLog.dayKey(date, calendar: calendar)
        if let idx = state.supplementLogs.firstIndex(where: { $0.day == key }) {
            if let pos = state.supplementLogs[idx].itemIDs.firstIndex(of: id) {
                state.supplementLogs[idx].itemIDs.remove(at: pos)
            } else {
                state.supplementLogs[idx].itemIDs.append(id)
            }
        } else {
            state.supplementLogs.append(SupplementLog(day: key, itemIDs: [id]))
        }
        triggerHaptic(.light)
    }

    func takeAllSupplementsToday(on date: Date = Date()) {
        let key = WaterLog.dayKey(date, calendar: calendar)
        let allIDs = state.supplements.map(\.id)
        if let idx = state.supplementLogs.firstIndex(where: { $0.day == key }) {
            state.supplementLogs[idx].itemIDs = allIDs
        } else {
            state.supplementLogs.append(SupplementLog(day: key, itemIDs: allIDs))
        }
        triggerHaptic(.success)
    }

    // MARK: - 咖啡因管理

    func todayCaffeineEntries(now: Date = Date()) -> [CaffeineEntry] {
        state.caffeineEntries
            .filter { calendar.isDate($0.date, inSameDayAs: now) }
            .sorted { $0.date > $1.date }
    }

    func todayCaffeineMg(now: Date = Date()) -> Int {
        todayCaffeineEntries(now: now).reduce(0) { $0 + $1.mg }
    }

    func addCaffeine(title: String, mg: Int, at date: Date = Date()) {
        guard mg > 0 else { return }
        state.caffeineEntries.insert(CaffeineEntry(date: date, title: title, mg: mg), at: 0)
        triggerHaptic(.light)
    }

    func deleteCaffeine(id: UUID) {
        state.caffeineEntries.removeAll { $0.id == id }
    }

    // MARK: - 首页小组件配置

    var visibleHomeWidgets: [HomeWidgetKind] {
        let hidden = Set(state.hiddenHomeWidgets)
        var ordered = state.homeWidgets.filter { !hidden.contains($0) }
        for kind in HomeWidgetKind.defaultOrder where !state.homeWidgets.contains(kind) && !hidden.contains(kind) {
            ordered.append(kind)
        }
        return ordered
    }

    func isWidgetVisible(_ kind: HomeWidgetKind) -> Bool {
        !state.hiddenHomeWidgets.contains(kind)
    }

    func setWidgetVisible(_ kind: HomeWidgetKind, visible: Bool) {
        if visible {
            state.hiddenHomeWidgets.removeAll { $0 == kind }
            if !state.homeWidgets.contains(kind) {
                state.homeWidgets.append(kind)
            }
        } else if !state.hiddenHomeWidgets.contains(kind) {
            state.hiddenHomeWidgets.append(kind)
        }
    }

    func moveHomeWidgets(from offsets: IndexSet, to destination: Int) {
        var current = visibleHomeWidgets
        let moving = offsets.sorted().compactMap { current.indices.contains($0) ? current[$0] : nil }
        for index in offsets.sorted(by: >) where current.indices.contains(index) {
            current.remove(at: index)
        }
        let shift = offsets.filter { $0 < destination }.count
        let target = min(max(0, destination - shift), current.count)
        current.insert(contentsOf: moving, at: target)
        state.homeWidgets = current + state.hiddenHomeWidgets
    }

    func resetHomeWidgets() {
        state.homeWidgets = HomeWidgetKind.defaultOrder
        state.hiddenHomeWidgets = []
    }

    // MARK: - 本周计划 & 模板管理

    func rollWeekIfNeeded(now: Date, calendar: Calendar? = nil) {
        let cal = calendar ?? self.calendar
        let rolled = WeekPlanOps.roll(
            days: state.plan?.days ?? [],
            lastWeek: state.lastWeekPlan,
            stamp: state.weekStamp,
            now: now,
            calendar: cal
        )
        guard rolled.stamp != state.weekStamp || rolled.lastWeek != state.lastWeekPlan else { return }
        var next = state
        next.lastWeekPlan = rolled.lastWeek
        next.weekStamp = rolled.stamp
        state = next
    }

    func prepareWeekUndo() {
        state.planUndo = state.plan?.days
    }

    func reorderThisWeek(from offsets: IndexSet, to destination: Int) {
        guard var plan = state.plan else { return }
        var next = state
        if next.planUndo == nil {
            next.planUndo = plan.days
        }
        plan.days = WeekPlanOps.reorder(plan.days, from: offsets, to: destination)
        next.plan = plan
        state = next
    }

    @discardableResult
    func copyLastWeekToThisWeek() -> Bool {
        guard var plan = state.plan, let copied = WeekPlanOps.copied(from: state.lastWeekPlan) else { return false }
        var next = state
        next.planUndo = plan.days
        plan.days = copied
        next.plan = plan
        state = next
        return true
    }

    func clearThisWeek() {
        guard var plan = state.plan else { return }
        var next = state
        next.planUndo = plan.days
        plan.days = WeekPlanOps.cleared(plan.days)
        next.plan = plan
        state = next
    }

    func clearAllPlanAndOverrides() {
        clearThisWeek()
        state.dayOverrides = [:]
        state.planRepeatWeeks = 0
    }

    @discardableResult
    func restoreWeek() -> Bool {
        guard let undo = state.planUndo, var plan = state.plan else { return false }
        plan.days = undo
        var next = state
        next.plan = plan
        next.planUndo = nil
        state = next
        return true
    }

    func plannedDay(on date: Date) -> PlannedDay? {
        let key = WaterLog.dayKey(date, calendar: calendar)
        if let override = state.dayOverrides[key] {
            return override
        }
        let weekday = calendar.component(.weekday, from: date)
        return state.plan?.days.first { $0.weekday == weekday }
    }

    func hasDayOverride(on date: Date) -> Bool {
        let key = WaterLog.dayKey(date, calendar: calendar)
        return state.dayOverrides[key] != nil
    }

    func setDayOverride(_ day: PlannedDay, on date: Date) {
        let key = WaterLog.dayKey(date, calendar: calendar)
        var copy = day
        copy.weekday = calendar.component(.weekday, from: date)
        state.dayOverrides[key] = copy
    }

    func clearDayOverride(on date: Date) {
        let key = WaterLog.dayKey(date, calendar: calendar)
        state.dayOverrides.removeValue(forKey: key)
    }

    func applyWeekTemplate(_ template: WeekPlanTemplate) {
        if var plan = state.plan {
            state.planUndo = plan.days
            plan.days = template.days
            plan.generatedBy = template.title
            state.plan = plan
        } else {
            state.plan = TrainingPlan(
                goal: state.profile.goal,
                weeks: 4,
                days: template.days,
                generatedBy: template.title
            )
        }
        triggerHaptic(.success)
    }

    func applyTemplateToDay(_ template: WorkoutTemplate, on date: Date) {
        let weekday = calendar.component(.weekday, from: date)
        let planned = PlannedDay(
            weekday: weekday,
            title: template.title,
            focus: template.focus,
            exercises: template.exercises,
            rest: false
        )
        setDayOverride(planned, on: date)
        triggerHaptic(.success)
    }

    func addCustomTemplate(_ template: WorkoutTemplate) {
        state.customTemplates.insert(template, at: 0)
        triggerHaptic(.success)
    }

    func deleteCustomTemplate(id: String) {
        state.customTemplates.removeAll { $0.id == id }
        state.favoriteTemplateIDs.removeAll { $0 == id }
    }

    func isTemplateFavorite(_ id: String) -> Bool {
        state.favoriteTemplateIDs.contains(id)
    }

    func toggleTemplateFavorite(_ id: String) {
        if let idx = state.favoriteTemplateIDs.firstIndex(of: id) {
            state.favoriteTemplateIDs.remove(at: idx)
        } else {
            state.favoriteTemplateIDs.append(id)
        }
        triggerHaptic(.light)
    }

    // MARK: - 图片库本地照片管理

    var photosDirectoryURL: URL {
        let dir = fileURL.deletingLastPathComponent().appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func savePhotoMemory(image: UIImage, caption: String = "", category: String = "meal") {
        let fileName = "\(UUID().uuidString).jpg"
        let dest = photosDirectoryURL.appendingPathComponent(fileName)
        if let data = image.jpegData(compressionQuality: 0.78) {
            try? data.write(to: dest, options: .atomic)
            state.photoMemories.insert(
                PhotoMemory(date: Date(), fileName: fileName, caption: caption, categoryRaw: category),
                at: 0
            )
            triggerHaptic(.light)
        }
    }

    func loadPhotoImage(fileName: String) -> UIImage? {
        let url = photosDirectoryURL.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func deletePhotoMemory(id: UUID) {
        if let item = state.photoMemories.first(where: { $0.id == id }) {
            let url = photosDirectoryURL.appendingPathComponent(item.fileName)
            try? FileManager.default.removeItem(at: url)
        }
        state.photoMemories.removeAll { $0.id == id }
    }

    func clearPhotoCache() -> Int64 {
        let dir = photosDirectoryURL
        let bytes = localStorageBytes(in: dir)
        try? FileManager.default.removeItem(at: dir)
        state.photoMemories = []
        return bytes
    }

    func localStorageBytes(in folder: URL? = nil) -> Int64 {
        let root = folder ?? fileURL.deletingLastPathComponent()
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) {
                total += Int64(size)
            }
        }
        return total
    }

    // MARK: - 插件、跑鞋、隐私区、音乐收藏

    func isPluginInstalled(_ id: String) -> Bool {
        state.installedPluginIDs.contains(id)
    }

    func togglePluginInstalled(_ id: String) {
        if let idx = state.installedPluginIDs.firstIndex(of: id) {
            state.installedPluginIDs.remove(at: idx)
        } else {
            state.installedPluginIDs.append(id)
        }
        triggerHaptic(.light)
    }

    func markPluginInstalled(_ id: String) {
        if !state.installedPluginIDs.contains(id) {
            state.installedPluginIDs.append(id)
        }
    }

    func addShoe(name: String, brand: String, maxKm: Double = 600) {
        state.shoes.insert(ShoeGear(name: name, brand: brand, loggedKm: 0, maxKm: maxKm, isActive: true), at: 0)
        triggerHaptic(.light)
    }

    func deleteShoe(id: UUID) {
        state.shoes.removeAll { $0.id == id }
    }

    func addPrivacyZone(name: String, lat: Double, lon: Double, radiusM: Double = 300) {
        state.privacyZones.append(PrivacyZone(name: name, lat: lat, lon: lon, radiusM: radiusM))
    }

    func removePrivacyZone(id: UUID) {
        state.privacyZones.removeAll { $0.id == id }
    }

    func isMusicFavorite(_ id: String) -> Bool {
        state.favoriteMusicIDs.contains(id)
    }

    func toggleMusicFavorite(_ id: String) {
        if let idx = state.favoriteMusicIDs.firstIndex(of: id) {
            state.favoriteMusicIDs.remove(at: idx)
        } else {
            state.favoriteMusicIDs.append(id)
        }
        triggerHaptic(.light)
    }

    // MARK: - 触感与全局显示辅助

    enum HapticKind { case light, success }

    func triggerHaptic(_ kind: HapticKind) {
        guard state.hapticModeRaw != "off" else { return }
        if state.hapticModeRaw == "necessary" && kind == .light { return }
        switch kind {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    var preferredColorSchemeOverride: ColorScheme? {
        switch state.appearanceRaw {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    func formatWeight(_ kg: Double) -> String {
        if state.profile.preferredUnit == "lb" {
            let lb = kg * 2.20462
            return String(format: "%.1f lb", lb)
        }
        return kg == kg.rounded() ? "\(Int(kg)) kg" : String(format: "%.1f kg", kg)
    }

    func updateRun(_ run: RouteRun) {
        if let idx = state.runs.firstIndex(where: { $0.id == run.id }) {
            state.runs[idx] = run
        }
    }

    func appendChat(_ turn: ChatTurn) {
        state.chats.append(turn)
    }

    func clearChat() {
        state.chats = []
    }

    func setPlan(_ plan: TrainingPlan) {
        state.plan = plan
    }

    func resetTodayQuotas() {
        state.quotas.reset("food")
        saveNow()
    }

    // MARK: - 今天的训练建议

    var todaysPlannedDay: PlannedDay? {
        if let day = plannedDay(on: Date()), !day.rest {
            return day
        }
        return nil
    }

    func exercise(named name: String) -> Exercise? {
        state.exercises.first { $0.name == name }
    }
}
