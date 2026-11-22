import Foundation
import UIKit
import ImageIO

// MARK: - 57 核心真人视频动作库模型与缓存

/// 来自 `exercises_catalog.json`（全员 720p CC0 真人循环视频 + 解剖肌群图 + 简体中文步骤）的标准化动作条目。
struct CatalogExercise: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let nameZH: String?
    let bodyPart: String
    let equipment: String
    let target: String
    let secondary: [String]
    let steps: [String]
    let tips: [String]?
    let gif: String
    let thumb: String
    let muscleImage: String?
    let difficulty: String?
    let video: String?
    let localThumb: String?

    static let cdnBase = "https://cdn.jsdelivr.net/gh/RepDB/exercise-dataset@main/"

    var videoURL: URL? {
        guard let video, !video.isEmpty else { return nil }
        if video.hasPrefix("http://") || video.hasPrefix("https://") {
            return URL(string: video)
        }
        return URL(string: Self.cdnBase + video)
    }

    var hasVideo: Bool { videoURL != nil }

    static func bundleThumbImage(named name: String?) -> UIImage? {
        guard let name, !name.isEmpty else { return nil }
        let bundles = [Bundle.main, Bundle(for: ExerciseCatalogStore.self)]
        for bundle in bundles {
            if let url = bundle.url(forResource: name, withExtension: "jpg")
                ?? bundle.url(forResource: name, withExtension: "jpg", subdirectory: "VideoThumbs"),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }
        return nil
    }

    var gifURL: URL? {
        guard !gif.isEmpty else { return nil }
        return URL(string: Self.cdnBase + gif)
    }

    var thumbURL: URL? {
        guard !thumb.isEmpty else { return nil }
        return URL(string: Self.cdnBase + thumb)
    }

    var startImageURL: URL? { thumbURL }

    var peakImageURL: URL? {
        guard !gif.isEmpty, gif != thumb else { return nil }
        return gifURL
    }

    var muscleImageURL: URL? {
        guard let muscleImage, !muscleImage.isEmpty else { return nil }
        return URL(string: Self.cdnBase + muscleImage)
    }

    var isAnimatedPair: Bool { peakImageURL != nil }

    var difficultyZH: String? {
        switch difficulty?.lowercased() {
        case "beginner": return "入门"
        case "intermediate": return "进阶"
        case "advanced": return "高阶"
        default: return nil
        }
    }

    /// 中文动作名称（优先使用全量中文字段 `nameZH`，再以关键词规则兜底）。
    var chineseAlias: String? {
        if let nameZH, !nameZH.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nameZH
        }
        let lower = name.lowercased()
        let rules: [(String, String)] = [
            ("barbell bench press", "杠铃平板卧推"),
            ("barbell incline bench press", "上斜杠铃卧推"),
            ("dumbbell bench press", "哑铃平板卧推"),
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
        if let alias = chineseAlias, !alias.isEmpty {
            return alias
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
        case "upper legs", "lower legs", "full body": return .legs
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
            case "dumbbell", "kettlebell", "plates": return .dumbbell
            case "cable", "rope", "battle rope": return .cable
            case "body weight", "assisted", "weighted", "pull up bar", "dip station", "rings", "suspension trainer", "flat bench":
                return .bodyweight
            default: return .machine
            }
        }()
        return Exercise(
            id: UUID(),
            name: chineseAlias ?? name,
            group: muscleGroup,
            equipment: equip,
            isTimed: bodyPart == "cardio" || name.lowercased().contains("plank") || name.lowercased().contains("hold"),
            cue: steps.first ?? "\(targetZH) · \(equipmentZH)"
        )
    }

    // MARK: - 中文字典映射

    static let bodyPartOrder: [String] = [
        "chest", "back", "shoulders", "upper arms", "lower arms",
        "upper legs", "lower legs", "waist", "full body", "cardio"
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
        case "full body": return "全身复合"
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
        case "plates", "plate": return "杠铃片"
        case "flat bench", "bench": return "训练凳"
        case "pull up bar": return "单杠"
        case "dip station", "dipBars": return "双杠"
        case "rings": return "体操吊环"
        case "suspension trainer": return "TRX 悬挂带"
        case "ab wheel": return "健腹轮"
        case "foam roller", "roller": return "泡沫轴/滚轴"
        case "wheel roller": return "健腹轮/滚轴"
        case "lacrosse ball", "lacrosse": return "筋膜球"
        case "stability ball": return "瑞士球"
        case "bosu ball": return "波速球"
        case "medicine ball": return "药球"
        case "slam ball": return "砸球"
        case "wall ball": return "墙球"
        case "plyo box": return "跳箱"
        case "sandbag": return "力量沙袋"
        case "sled": return "推拉雪橇车"
        case "battle rope": return "战绳"
        case "climbing rope": return "爬绳"
        case "jump rope": return "跳绳"
        case "rope": return "绳索/战绳"
        case "wrist roller": return "腕力卷轴"
        case "treadmill": return "跑步机"
        case "bicycle": return "自行车"
        case "stationary bike": return "动感单车"
        case "air bike": return "风阻单车"
        case "elliptical", "elliptical machine": return "椭圆机"
        case "stair climber", "stepmill machine": return "登山机"
        case "rower": return "划船机"
        case "ski erg", "skierg machine": return "滑雪机"
        case "sled machine": return "雪橇车"
        case "hammer": return "战锤"
        case "tire": return "轮胎"
        case "upper body ergometer": return "上肢风阻车"
        default: return raw
        }
    }

    static func targetName(_ raw: String) -> String {
        switch raw {
        case "pectorals", "pectoralis_major": return "胸大肌"
        case "lats", "latissimus_dorsi": return "背阔肌"
        case "upper back": return "上背肌群"
        case "rhomboids": return "菱形肌"
        case "traps", "trapezius": return "斜方肌"
        case "spine", "erector_spinae": return "竖脊肌"
        case "delts": return "三角肌"
        case "anterior_deltoid": return "三角肌前束"
        case "lateral_deltoid": return "三角肌中束"
        case "posterior_deltoid": return "三角肌后束"
        case "infraspinatus_teres_minor": return "冈下肌/肩袖"
        case "supraspinatus": return "冈上肌"
        case "biceps", "biceps_brachii": return "肱二头肌"
        case "brachialis": return "肱肌"
        case "brachioradialis": return "肱桡肌"
        case "triceps", "triceps_brachii": return "肱三头肌"
        case "forearms", "forearm_flexors", "forearm_extensors": return raw == "forearm_extensors" ? "前臂伸肌" : (raw == "forearm_flexors" ? "前臂屈肌" : "前臂肌群")
        case "quads", "quadriceps": return "股四头肌"
        case "hamstrings": return "腘绳肌"
        case "glutes", "gluteus_maximus": return "臀大肌"
        case "gluteus_medius": return "臀中肌"
        case "adductors": return "大腿内收肌"
        case "abductors": return "臀外展肌"
        case "hip_flexors": return "髂腰肌/屈髋肌"
        case "calves", "gastrocnemius": return "腓肠肌（小腿）"
        case "soleus": return "比目鱼肌"
        case "tibialis_anterior": return "胫骨前肌"
        case "abs", "rectus_abdominis": return "腹直肌"
        case "obliques": return "腹斜肌"
        case "transverse_abdominis": return "腹横肌"
        case "quadratus_lumborum": return "腰方肌"
        case "serratus anterior", "serratus_anterior": return "前锯肌"
        case "levator scapulae": return "肩胛提肌"
        case "full_body": return "全身肌群"
        case "it_band": return "髂胫束"
        case "plantar_fascia": return "足底筋膜"
        case "neck": return "颈部肌群"
        case "cardiovascular system": return "心肺耐力"
        default: return raw
        }
    }
}

// MARK: - 动作库数据加载与搜索

final class ExerciseCatalogStore {
    static let shared = ExerciseCatalogStore()

    let all: [CatalogExercise]

    var availableBodyParts: [String] {
        let present = Set(all.map(\.bodyPart))
        let ordered = CatalogExercise.bodyPartOrder.filter { present.contains($0) }
        let extra = present.subtracting(ordered).sorted()
        return ordered + extra
    }

    var availableEquipments: [String] {
        let present = Set(all.map(\.equipment))
        let preferred = CatalogExercise.equipmentQuickFilters.filter { present.contains($0) }
        let extra = present.subtracting(preferred).sorted {
            CatalogExercise.equipmentName($0) < CatalogExercise.equipmentName($1)
        }
        return preferred + extra
    }

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

    func filter(query: String, bodyPart: String?, equipment: String?, videoOnly: Bool = false) -> [CatalogExercise] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return all.filter { item in
            if videoOnly && !item.hasVideo {
                return false
            }
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
            if let tips = item.tips, tips.contains(where: { $0.localizedCaseInsensitiveContains(q) }) { return true }
            return false
        }
    }
}

// MARK: - 动作示范高清媒体磁盘缓存（查看过即离线可用）

enum ExerciseMediaCache {
    private static let cleanupOnce: Void = {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let legacyDir = base.appendingPathComponent("ExerciseMedia", isDirectory: true)
        if FileManager.default.fileExists(atPath: legacyDir.path) {
            DispatchQueue.global(qos: .utility).async {
                try? FileManager.default.removeItem(at: legacyDir)
            }
        }
    }()

    static var cacheDirectory: URL {
        _ = cleanupOnce
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("ExerciseMediaHD", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func cachedFileURL(for remoteURL: URL) -> URL {
        let comps = remoteURL.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        let safeName: String
        if comps.count >= 2 {
            safeName = comps.suffix(2).joined(separator: "_")
        } else {
            safeName = remoteURL.lastPathComponent.isEmpty ? UUID().uuidString : remoteURL.lastPathComponent
        }
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

    /// 针对列表缩略图使用 ImageIO 进行高速指定最大像素解码，避免 512px 原图在列表中占用过多内存。
    static func decodeDownsampled(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return UIImage(data: data)
        }
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        if let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) {
            return UIImage(cgImage: cg)
        }
        return UIImage(data: data)
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
