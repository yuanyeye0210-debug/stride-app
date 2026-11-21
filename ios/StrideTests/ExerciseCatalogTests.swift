import XCTest
@testable import Stride

final class ExerciseCatalogTests: XCTestCase {

    func testCatalogLoadsAll1324ExercisesWithValidURLs() {
        let store = ExerciseCatalogStore.shared
        XCTAssertEqual(store.all.count, 1324, "应完整加载 1,324 个动作库条目")

        let sample = store.all.first
        XCTAssertNotNil(sample)
        XCTAssertNotNil(sample?.gifURL)
        XCTAssertNotNil(sample?.thumbURL)
        XCTAssertFalse(sample?.steps.isEmpty ?? true, "动作条目应包含中文执行步骤")
    }

    func testChineseAndBodyPartFiltering() {
        let store = ExerciseCatalogStore.shared

        let chestBarbell = store.filter(query: "", bodyPart: "chest", equipment: "barbell")
        XCTAssertFalse(chestBarbell.isEmpty)
        XCTAssertTrue(chestBarbell.allSatisfy { $0.bodyPart == "chest" && $0.equipment == "barbell" })

        let benchByZH = store.filter(query: "卧推", bodyPart: nil, equipment: nil)
        XCTAssertFalse(benchByZH.isEmpty, "应支持中文关键词检索卧推动作")

        let squatConverted = benchByZH.first?.toExercise()
        XCTAssertNotNil(squatConverted)
        XCTAssertFalse(squatConverted?.name.isEmpty ?? true)
    }
}
