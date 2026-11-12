import XCTest
@testable import Stride

@MainActor
final class WaterAndWeekTests: XCTestCase {

    private func temporaryStateURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("state.json")
    }

    private func calendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "zh_CN")
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    func testWaterMathAndRelaunch() {
        XCTAssertEqual(WaterLog.adjusted(0, delta: -500), 0)
        XCTAssertEqual(WaterLog.adjusted(1800, delta: 500), 2300)
        XCTAssertEqual(WaterLog.cups(0), 0)
        XCTAssertEqual(WaterLog.cups(500), 2)
        XCTAssertEqual(WaterLog.cups(1000), 5)
        XCTAssertEqual(WaterLog.percent(0, goal: 1800), 0)
        XCTAssertEqual(WaterLog.percent(1000, goal: 1800), 56)
        XCTAssertEqual(WaterLog.percent(1800, goal: 1800), 100)
        XCTAssertEqual(WaterLog.grouped(1800), "1,800")

        let url = temporaryStateURL()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = AppStore(fileURL: url)
        store.addWater(delta: 500, now: now)
        store.addWater(delta: 500, now: now)
        store.addWater(delta: -5000, now: now)
        store.addWater(delta: 500, now: now)
        store.saveNow()

        let loaded = AppStore(fileURL: url)
        XCTAssertEqual(loaded.todayWaterMl(now: now), 500)
        XCTAssertEqual(loaded.state.waterGoalMl, 1800)
    }

    func testLegacyFileWithoutWaterStillLoads() throws {
        let url = temporaryStateURL()
        let store = AppStore(fileURL: url)
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        store.addSession(WorkoutSession(date: when, title: "旧记录"))
        store.saveNow()

        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        object.removeValue(forKey: "waterDays")
        object.removeValue(forKey: "waterGoalMl")
        object.removeValue(forKey: "lastWeekPlan")
        object.removeValue(forKey: "planUndo")
        object.removeValue(forKey: "weekStamp")
        try JSONSerialization.data(withJSONObject: object).write(to: url)

        let loaded = AppStore(fileURL: url)
        XCTAssertTrue(loaded.state.sessions.contains { $0.title == "旧记录" })
        XCTAssertEqual(loaded.todayWaterMl(), 0)
        XCTAssertEqual(loaded.state.waterGoalMl, 1800)
        XCTAssertTrue(loaded.state.lastWeekPlan.isEmpty)
    }

    func testReorderCopyClearRestoreAndRoll() {
        let days = (1...7).map { PlannedDay(weekday: $0, title: "D\($0)", focus: nil, exercises: [], rest: $0 == 1) }
        let moved = WeekPlanOps.reorder(days, from: IndexSet(integer: 0), to: 2)
        XCTAssertEqual(moved.map(\.title), ["D2", "D1", "D3", "D4", "D5", "D6", "D7"])
        XCTAssertEqual(moved.map(\.weekday), [1, 2, 3, 4, 5, 6, 7])

        let cleared = WeekPlanOps.cleared(days)
        XCTAssertTrue(cleared.allSatisfy { $0.rest && $0.exercises.isEmpty && $0.title == "恢复" })

        let cal = calendar()
        let earlier = Date(timeIntervalSince1970: 1_700_000_000)
        let later = cal.date(byAdding: .day, value: 14, to: earlier)!
        let firstStamp = WeekPlanOps.stamp(for: earlier, calendar: cal)
        let nextStamp = WeekPlanOps.stamp(for: later, calendar: cal)
        XCTAssertNotEqual(firstStamp, nextStamp)

        let fresh = WeekPlanOps.roll(days: days, lastWeek: [], stamp: 0, now: later, calendar: cal)
        XCTAssertTrue(fresh.lastWeek.isEmpty)
        XCTAssertEqual(fresh.stamp, nextStamp)

        let rolled = WeekPlanOps.roll(days: days, lastWeek: [], stamp: firstStamp, now: later, calendar: cal)
        XCTAssertEqual(rolled.lastWeek.map(\.title), days.map(\.title))
        XCTAssertEqual(rolled.stamp, nextStamp)

        let url = temporaryStateURL()
        let store = AppStore(fileURL: url)
        store.state.plan = TrainingPlan(days: days)
        store.state.weekStamp = firstStamp
        store.state.lastWeekPlan = []
        store.rollWeekIfNeeded(now: later, calendar: cal)
        XCTAssertEqual(store.state.lastWeekPlan.map(\.title), days.map(\.title))

        store.state.lastWeekPlan = [PlannedDay(weekday: 3, title: "上周推", focus: nil)]
        XCTAssertTrue(store.copyLastWeekToThisWeek())
        XCTAssertEqual(store.state.plan?.days.map(\.title), ["上周推"])
        store.clearThisWeek()
        XCTAssertEqual(store.state.plan?.days.map(\.title), ["恢复"])
        XCTAssertTrue(store.state.plan?.days.allSatisfy(\.rest) == true)
        XCTAssertTrue(store.restoreWeek())
        XCTAssertEqual(store.state.plan?.days.map(\.title), ["上周推"])
        XCTAssertFalse(store.restoreWeek())

        store.state.weekStamp = WeekPlanOps.stamp(for: Date(), calendar: .current)
        store.saveNow()
        let loaded = AppStore(fileURL: url)
        XCTAssertEqual(loaded.state.plan?.days.map(\.title), ["上周推"])
        XCTAssertEqual(loaded.state.lastWeekPlan.map(\.title), ["上周推"])
        XCTAssertNil(loaded.state.planUndo)
    }
}
