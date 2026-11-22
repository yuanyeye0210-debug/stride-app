import XCTest
@testable import Stride

final class ExerciseCatalogTests: XCTestCase {

    func testCatalogIs100PercentHDRealVideoExercises() {
        let store = ExerciseCatalogStore.shared
        XCTAssertEqual(store.all.count, 77, "核心真人视频动作库应包含 77 个动作")
        XCTAssertTrue(store.all.allSatisfy { $0.hasVideo }, "动作库中每个动作都必须具备 720p 真人视频，禁止静态充数条目")

        let allowedPrefixes = [
            "https://cdn.jsdelivr.net/gh/namnq/workout-free-videos@v2.0.0/media/video/",
            "https://cdn.jsdelivr.net/gh/yuanyeye0210-debug/stride-app@main/media/videos/"
        ]
        for item in store.all {
            let urlStr = item.videoURL?.absoluteString ?? ""
            let isValidURL = allowedPrefixes.contains { urlStr.hasPrefix($0) } && urlStr.hasSuffix(".mp4")
            XCTAssertTrue(isValidURL, "\(item.id) 视频 URL 不合法: \(urlStr)")
            XCTAssertFalse((item.localThumb ?? "").isEmpty, "\(item.id) 缺少内置封面名")
            XCTAssertNotNil(CatalogExercise.bundleThumbImage(named: item.localThumb), "\(item.id) 内置封面 \(item.localThumb ?? "") 未能从 Bundle 解码")
            XCTAssertFalse((item.nameZH ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(item.id) 缺少中文动作名")
            XCTAssertFalse(item.steps.isEmpty, "\(item.id) 应包含中文执行步骤")
        }
    }

    func testDynamicFiltersHaveNoEmptyTabsAndSupportChineseSearch() {
        let store = ExerciseCatalogStore.shared

        XCTAssertFalse(store.availableBodyParts.isEmpty)
        for part in store.availableBodyParts {
            let items = store.filter(query: "", bodyPart: part, equipment: nil)
            XCTAssertFalse(items.isEmpty, "部位筛选「\(part)」不应为空分类")
            XCTAssertTrue(items.allSatisfy { $0.bodyPart == part })
        }

        XCTAssertFalse(store.availableEquipments.isEmpty)
        for eq in store.availableEquipments {
            let items = store.filter(query: "", bodyPart: nil, equipment: eq)
            XCTAssertFalse(items.isEmpty, "器械筛选「\(eq)」不应为空分类")
            XCTAssertTrue(items.allSatisfy { $0.equipment == eq })
        }

        for kw in ["杠铃平板卧推", "卧推", "深蹲", "硬拉", "引体", "反手引体", "臀推", "划船", "推举", "平板支撑", "面拉", "弯举", "夹胸"] {
            let matched = store.filter(query: kw, bodyPart: nil, equipment: nil)
            XCTAssertFalse(matched.isEmpty, "精简动作库应支持中文关键词检索「\(kw)」")
        }

        let converted = store.filter(query: "卧推", bodyPart: nil, equipment: nil).first?.toExercise()
        XCTAssertNotNil(converted)
        XCTAssertFalse(converted?.name.isEmpty ?? true)
    }

    func testMediaCachePreservesMP4ExtensionAndHDDirectory() throws {
        let videoURL = try XCTUnwrap(URL(string: "https://cdn.jsdelivr.net/gh/namnq/workout-free-videos@v2.0.0/media/video/dumbbell-bench-press.mp4"))
        let flatURL = try XCTUnwrap(URL(string: "https://cdn.jsdelivr.net/gh/RepDB/exercise-dataset@main/images/flat/bench-press-start.webp"))
        let otherURL = try XCTUnwrap(URL(string: "https://cdn.jsdelivr.net/gh/RepDB/exercise-dataset@main/images/other/bench-press-start.webp"))

        let cachedVideo = ExerciseMediaCache.cachedFileURL(for: videoURL)
        let cachedFlat = ExerciseMediaCache.cachedFileURL(for: flatURL)
        let cachedOther = ExerciseMediaCache.cachedFileURL(for: otherURL)

        XCTAssertTrue(cachedVideo.path.contains("ExerciseMediaHD"), "缓存目录应指向 ExerciseMediaHD")
        XCTAssertEqual(cachedVideo.pathExtension.lowercased(), "mp4", "MP4 视频缓存路径必须保留 .mp4 扩展名以供 AVURLAsset 识别")
        XCTAssertNotEqual(cachedFlat.lastPathComponent, cachedOther.lastPathComponent, "不同子目录的同名文件缓存键不应碰撞")
    }
}
