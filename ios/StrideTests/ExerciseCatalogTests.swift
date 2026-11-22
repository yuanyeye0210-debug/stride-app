import XCTest
@testable import Stride

final class ExerciseCatalogTests: XCTestCase {

    func testCatalogLoadsAllExercisesWith57HDVideosAndPosters() {
        let store = ExerciseCatalogStore.shared
        XCTAssertGreaterThanOrEqual(store.all.count, 708, "融合后动作库条目数应不少于 708")

        let videoItems = store.all.filter { $0.hasVideo }
        XCTAssertEqual(videoItems.count, 57, "应完整包含 57 个 720p 高清循环视频动作")

        for item in videoItems {
            let urlStr = item.videoURL?.absoluteString ?? ""
            XCTAssertTrue(urlStr.hasPrefix("https://cdn.jsdelivr.net/gh/namnq/workout-free-videos@v2.0.0/media/video/") && urlStr.hasSuffix(".mp4"), "\(item.id) 视频 URL 不合法: \(urlStr)")
            XCTAssertFalse((item.localThumb ?? "").isEmpty, "\(item.id) 缺少内置封面名")
            XCTAssertNotNil(CatalogExercise.bundleThumbImage(named: item.localThumb), "\(item.id) 内置封面 \(item.localThumb ?? "") 未能从 Bundle 解码")
            XCTAssertFalse((item.nameZH ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(item.id) 缺少中文动作名")
            XCTAssertFalse(item.steps.isEmpty, "\(item.id) 应包含中文执行步骤")
        }

        for item in store.all {
            XCTAssertFalse((item.nameZH ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(item.id) 缺少中文动作名")
            XCTAssertFalse(item.steps.isEmpty, "\(item.id) 应包含中文执行步骤")
        }

        let dualFrameCount = store.all.filter { $0.isAnimatedPair }.count
        XCTAssertGreaterThanOrEqual(dualFrameCount, 500, "RepDB 双帧动作数应不少于 500 个")
    }

    func testChineseAndVideoOnlyFiltering() {
        let store = ExerciseCatalogStore.shared

        XCTAssertEqual(store.filter(query: "", bodyPart: nil, equipment: nil, videoOnly: true).count, 57)

        let chestBarbell = store.filter(query: "", bodyPart: "chest", equipment: "barbell")
        XCTAssertFalse(chestBarbell.isEmpty)
        XCTAssertTrue(chestBarbell.allSatisfy { $0.bodyPart == "chest" && $0.equipment == "barbell" })

        for kw in ["卧推", "深蹲", "硬拉", "引体", "臀推"] {
            let matched = store.filter(query: kw, bodyPart: nil, equipment: nil, videoOnly: true)
            XCTAssertFalse(matched.isEmpty, "高清视频模式下应支持中文关键词检索「\(kw)」")
        }

        let converted = store.filter(query: "卧推", bodyPart: nil, equipment: nil, videoOnly: true).first?.toExercise()
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
