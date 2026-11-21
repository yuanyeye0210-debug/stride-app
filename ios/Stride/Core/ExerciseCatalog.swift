import Foundation
import UIKit

// MARK: - 1,324 动作全量视频动作库模型与缓存

/// 来自 `exercises_catalog.json` 的标准化动作条目（含示范动图、缩略图与简体中文步骤）。
struct CatalogExercise: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let bodyPart: String
    let equipment: String
    let target: String
    let secondary: [String]
    let steps: [String]
    let gif: String
    let thumb: String

    static let cdnBase = "https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/"

    var gifURL: URL? {
        guard !gif.isEmpty else { return nil }
        return URL(string: Self.cdnBase + gif)
    }

    var thumbURL: URL? {
        guard !thumb.isEmpty else { return nil }
        return URL(string: Self.cdnBase + thumb)
    }

    /// 常见核心动作中文别称（便于国内用户直接搜中文动作名）。
    var chineseAlias: String? {
        let lower = name.lowercased()
        let rules: [(String, String)] = [
            ("barbell bench press", "杠铃平板卧推"),
            ("barbell incline bench press", "上斜杠铃卧推"),
            ("dumbbell bench press", "哑铃卧推"),
            ("dumbbell incline bench press", "上斜哑铃卧推"),
            ("barbell full squat", "杠铃深蹲"),
            ("barbell squat", "杠铃深蹲"),
            ("barbell deadlift", "杠铃传统硬拉"),
            ("romanian deadlift", "罗马尼亚硬拉"),
            ("pull-up", "引体向上"),
            ("chin-up", "反手引体向上"),
            ("lat pulldown", "高位下拉"),
            ("barbell bent over row", "俯身杠铃划船"),
            ("dumbbell biceps curl", "哑铃二头弯举"),
            ("barbell curl", "杠铃弯举"),
            ("dumbbell lateral raise", "哑铃侧平举"),
            ("overhead press", "站姿推举"),
            ("push-up", "俯卧撑"),
            ("plank", "平板支撑"),
            ("hip thrust", "杠铃臀推"),
            ("leg press", "器械腿举"),
            ("calf raise", "站姿提踵"),
            ("triceps pushdown", "绳索三头下压"),
            ("face pull", "绳索面拉")
        ]
        for (pattern, alias) in rules where lower.contains(pattern) {
            return alias
        }
        return nil
    }

    var displayTitle: String {
        if let alias = chineseAlias {
            return "\(alias) · \(name)"
        }
        return name
    }

    var bodyPartZH: String { Self.bodyPartName(bodyPart) }
    var equipmentZH: String { Self.equipmentName(equipment) }
    var targetZH: String { Self.targetName(target) }

    /// 映射到 Stride 本地训练记录使用的 `MuscleGroup`。
    var muscleGroup: MuscleGroup {
        switch bodyPart {
        case "chest": return .chest
        case "back", "neck": return .back
        case "shoulders": return .shoulders
        case "upper arms", "lower arms": return .arms
        case "upper legs", "lower legs": return .legs
        case "waist": return .core
        case "cardio": return .cardio
        default: return .chest
        }
    }

    /// 转换为 `SessionView` 可直接加入训练课表的 `Exercise`。
    func toExercise() -> Exercise {
        let equip: Equipment = {
            switch equipment {
            case "barbell", "olympic barbell", "ez barbell", "trap bar": return .barbell
            case "dumbbell": return .dumbbell
            case "cable", "rope": return .cable
            case "body weight", "assisted", "weighted": return .bodyweight
            case "kettlebell": return .kettlebell
            default: return .machine
            }
        }()
        return Exercise(
            id: UUID(),
            name: chineseAlias ?? name,
            group: muscleGroup,
            equipment: equip,
            isTimed: bodyPart == "cardio" || name.lowercased().contains("plank"),
            cue: steps.first ?? "\(targetZH) · \(equipmentZH)"
        )
    }

    // MARK: - 中文字典映射

    static let bodyPartOrder: [String] = [
        "chest", "back", "shoulders", "upper arms", "lower arms",
        "upper legs", "lower legs", "waist", "cardio", "neck"
    ]

    static func bodyPartName(_ raw: String) -> String {
        switch raw {
        case "chest": return "胸部"
        case "back": return "背部"
        case "shoulders": return "肩部"
        case "upper arms": return "上臂"
        case "lower arms": return "前臂"
        case "upper legs": return "臀腿"
        case "lower legs": return "小腿"
        case "waist": return "核心腰腹"
        case "cardio": return "心肺有氧"
        case "neck": return "颈部"
        default: return raw
        }
    }

    static let equipmentQuickFilters: [String] = [
        "barbell", "dumbbell", "cable", "body weight",
        "leverage machine", "smith machine", "kettlebell", "band"
    ]

    static func equipmentName(_ raw: String) -> String {
        switch raw {
        case "barbell": return "杠铃"
        case "olympic barbell": return "奥杆"
        case "ez barbell": return "曲杆"
        case "trap bar": return "六角杠"
        case "dumbbell": return "哑铃"
        case "cable": return "绳索"
        case "body weight": return "徒手自重"
        case "leverage machine": return "固定器械"
        case "smith machine": return "史密斯机"
        case "kettlebell": return "壶铃"
        case "band", "resistance band": return "弹力带"
        case "assisted": return "辅助器械"
        case "weighted": return "负重片"
        case "stability ball": return "瑞士球"
        case "bosu ball": return "波速球"
        case "medicine ball": return "药球"
        case "rope": return "绳索/战绳"
        case "wheel roller", "roller": return "健腹轮/滚轴"
        case "stationary bike": return "动感单车"
        case "elliptical machine": return "椭圆机"
        case "stepmill machine": return "登山机"
        case "skierg machine": return "滑雪机"
        case "sled machine": return "雪橇车"
        case "hammer": return "战锤"
        case "tire": return "轮胎"
        case "upper body ergometer": return "上肢风阻车"
        default: return raw
        }
    }

    static func targetName(_ raw: String) -> String {
        switch raw {
        case "pectorals": return "胸大肌"
        case "lats": return "背阔肌"
        case "upper back": return "上背肌群"
        case "traps": return "斜方肌"
        case "spine": return "竖脊肌"
        case "delts": return "三角肌"
        case "biceps": return "肱二头肌"
        case "triceps": return "肱三头肌"
        case "forearms": return "前臂肌群"
        case "quads": return "股四头肌"
        case "hamstrings": return "腘绳肌"
        case "glutes": return "臀大肌"
        case "adductors": return "内收肌"
        case "abductors": return "外展肌"
        case "calves": return "小腿肌群"
        case "abs": return "腹直肌/核心"
        case "serratus anterior": return "前锯肌"
        case "levator scapulae": return "肩胛提肌"
        case "cardiovascular system": return "心肺耐力"
        default: return raw
        }
    }
}

// MARK: - 动作库数据加载与搜索

final class ExerciseCatalogStore {
    static let shared = ExerciseCatalogStore()

    let all: [CatalogExercise]

    init(bundle: Bundle = .main) {
        self.all = Self.loadCatalog(bundle: bundle)
    }

    static func loadCatalog(bundle: Bundle = .main) -> [CatalogExercise] {
        let candidateBundles = [bundle, Bundle(for: ExerciseCatalogStore.self), .main]
        for b in candidateBundles {
            if let url = b.url(forResource: "exercises_catalog", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let items = try? JSONDecoder().decode([CatalogExercise].self, from: data),
               !items.isEmpty {
                return items
            }
        }
        return []
    }

    func filter(query: String, bodyPart: String?, equipment: String?) -> [CatalogExercise] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return all.filter { item in
            if let bodyPart, !bodyPart.isEmpty, item.bodyPart != bodyPart {
                return false
            }
            if let equipment, !equipment.isEmpty, item.equipment != equipment {
                return false
            }
            guard !q.isEmpty else { return true }
            if item.name.localizedCaseInsensitiveContains(q) { return true }
            if let alias = item.chineseAlias, alias.localizedCaseInsensitiveContains(q) { return true }
            if item.bodyPartZH.localizedCaseInsensitiveContains(q) { return true }
            if item.equipmentZH.localizedCaseInsensitiveContains(q) { return true }
            if item.targetZH.localizedCaseInsensitiveContains(q) { return true }
            if item.steps.contains(where: { $0.localizedCaseInsensitiveContains(q) }) { return true }
            return false
        }
    }
}

// MARK: - 动作示范媒体磁盘缓存（查看过即离线可用）

enum ExerciseMediaCache {
    static var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("ExerciseMedia", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func cachedFileURL(for remoteURL: URL) -> URL {
        let safeName = remoteURL.lastPathComponent.isEmpty ? UUID().uuidString : remoteURL.lastPathComponent
        return cacheDirectory.appendingPathComponent(safeName)
    }

    static func isCached(for remoteURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: cachedFileURL(for: remoteURL).path)
    }

    static func loadData(from remoteURL: URL) async throws -> (data: Data, fromCache: Bool) {
        let localURL = cachedFileURL(for: remoteURL)
        if let localData = try? Data(contentsOf: localURL), !localData.isEmpty {
            return (localData, true)
        }

        var req = URLRequest(url: remoteURL)
        req.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard !data.isEmpty else { throw URLError(.cannotDecodeRawData) }
        try? data.write(to: localURL, options: .atomic)
        return (data, false)
    }

    static func totalCachedBytes() -> Int64 {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        return files.reduce(0) { sum, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return sum + Int64(size)
        }
    }

    static func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }
}
