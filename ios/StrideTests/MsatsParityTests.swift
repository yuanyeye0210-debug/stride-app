import XCTest
@testable import Stride

final class MsatsParityTests: XCTestCase {

    func testSetTypeBackwardCompatibleDecodingAndCycling() throws {
        // 旧版 JSON 缺少 setType 和 supersetGroupID 字段时，必须无损解码为默认值。
        let legacySetJSON = """
        {
          "weight": 80,
          "reps": 8,
          "seconds": 0,
          "done": true
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SetEntry.self, from: legacySetJSON)
        XCTAssertEqual(decoded.setType, .normal)
        XCTAssertEqual(decoded.weight, 80)
        XCTAssertTrue(decoded.done)

        // 验证组别循环顺序：常规 -> 热身(W) -> 递减(D) -> 力竭(F) -> 常规
        XCTAssertEqual(SetType.normal.next, .warmup)
        XCTAssertEqual(SetType.warmup.shortBadge, "W")
        XCTAssertEqual(SetType.warmup.next, .drop)
        XCTAssertEqual(SetType.drop.shortBadge, "D")
        XCTAssertEqual(SetType.drop.next, .failure)
        XCTAssertEqual(SetType.failure.shortBadge, "F")
        XCTAssertEqual(SetType.failure.next, .normal)
    }

    func testChatTurnWithAttachedPlanAndCoachPlanDetection() throws {
        XCTAssertTrue(CoachEngine.wantsGeneratedPlan(for: "帮我生成下周训练课表"))
        XCTAssertTrue(CoachEngine.wantsGeneratedPlan(for: "给我排一份4天分化计划"))
        XCTAssertFalse(CoachEngine.wantsGeneratedPlan(for: "今天练什么"))

        let plan = PlanGenerator.generate(goal: .recomp, days: 4, experience: .intermediate)
        let turn = ChatTurn(role: .coach, text: "已为你生成 4 天计划", attachedPlan: plan)
        let data = try JSONEncoder().encode(turn)
        let decoded = try JSONDecoder().decode(ChatTurn.self, from: data)
        XCTAssertEqual(decoded.attachedPlan?.days.count, 7)
    }

    func testBuiltInBarcodeLookupReturnsExpectedNutrition() async throws {
        let item = try await BarcodeFoodLookup.lookup(barcode: "6948939611524")
        XCTAssertEqual(item.name, "即食低脂鸡胸肉")
        XCTAssertEqual(item.protein, 24.5, accuracy: 0.01)
    }
}
