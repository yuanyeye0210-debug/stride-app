import XCTest
@testable import Stride

final class ExerciseCatalogTests: XCTestCase {

    func testCatalogLoadsAll708RepDBExercisesWithHDURLs() {
        let store = ExerciseCatalogStore.shared
        XCTAssertEqual(store.all.count, 708, "应完整加载 RepDB 708 个高清动作库条目")

        for item in store.all {
            XCTAssertNotNil(item.thumbURL, "\(item.id) 缺少起始缩略图 URL")
            XCTAssertNotNil(item.startImageURL, "\(item.id) 缺少 startImageURL")
            XCTAssertNotNil(item.gifURL, "\(item.id) 缺少 gifURL")
            XCTAssertTrue(item.thumbURL?.absoluteString.contains("RepDB/exercise-dataset") ?? false)
            XCTAssertFalse((item.nameZH ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(item.id) 缺少中文动作名")
            XCTAssertFalse(item.steps.isEmpty, "\(item.id) 应包含中文执行步骤")
        }

        let dualFrameCount = store.all.filter { $0.isAnimatedPair }.count
        XCTAssertGreaterThanOrEqual(dualFrameCount, 500, "RepDB 双帧动作数应不少于 500 个")
    }

    func testChineseAndBodyPartFiltering() {
        let store = ExerciseCatalogStore.shared

        let chestBarbell = store.filter(query: "", bodyPart: "chest", equipment: "barbell")
        XCTAssertFalse(chestBarbell.isEmpty)
        XCTAssertTrue(chestBarbell.allSatisfy { $0.bodyPart == "chest" && $0.equipment == "barbell" })

        for kw in ["卧推", "深蹲", "硬拉"] {
            let matched = store.filter(query: kw, bodyPart: nil, equipment: nil)
            XCTAssertFalse(matched.isEmpty, "应支持中文关键词检索「\(kw)」")
        }

        let converted = store.filter(query: "卧推", bodyPart: nil, equipment: nil).first?.toExercise()
        XCTAssertNotNil(converted)
        XCTAssertFalse(converted?.name.isEmpty ?? true)
    }

    func testMediaCacheDirectoryAndCollisionFreeKeys() throws {
        let urlA = try XCTUnwrap(URL(string: "https://cdn.jsdelivr.net/gh/RepDB/exercise-dataset@main/images/flat/bench-press-start.webp"))
        let urlB = try XCTUnwrap(URL(string: "https://cdn.jsdelivr.net/gh/RepDB/exercise-dataset@main/images/other/bench-press-start.webp"))

        let cachedA = ExerciseMediaCache.cachedFileURL(for: urlA)
        let cachedB = ExerciseMediaCache.cachedFileURL(for: urlB)

        XCTAssertTrue(cachedA.path.contains("ExerciseMediaHD"), "缓存目录应指向 ExerciseMediaHD")
        XCTAssertNotEqual(cachedA.lastPathComponent, cachedB.lastPathComponent, "不同子目录的同名文件缓存键不应碰撞")
    }
}
