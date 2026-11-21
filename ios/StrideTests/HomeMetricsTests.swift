import XCTest
@testable import Stride

@MainActor
final class HomeMetricsTests: XCTestCase {

    private func temporaryStateURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("state.json")
    }

    // MARK: - 肌肉恢复

    func testMuscleRecoveryDropsAfterRecentSessionAndRecoversAfter72Hours() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let chestEx = LoggedExercise(
            exerciseID: UUID(),
            name: "杠铃卧推",
            group: .chest,
            sets: Array(repeating: SetEntry(weight: 60, reps: 10, done: true), count: 8)
        )
        let recent = WorkoutSession(
            date: now.addingTimeInterval(-3600), // 1 小时前刚练完胸 8 组
            title: "胸推",
            exercises: [chestEx],
            durationSec: 3600
        )

        let items = MuscleRecoveryCalculator.assess(sessions: [recent], now: now)
        let chest = items.first { $0.group == .chest }
        let shoulders = items.first { $0.group == .shoulders }

        XCTAssertNotNil(chest)
        XCTAssertLessThan(chest?.percent ?? 100, 40)
        XCTAssertEqual(shoulders?.percent, 100)
        XCTAssertFalse(chest?.isRecommended ?? true)

        // 72 小时之后应恢复满 100%
        let later = now.addingTimeInterval(73 * 3600)
        let recovered = MuscleRecoveryCalculator.assess(sessions: [recent], now: later)
        XCTAssertTrue(recovered.allSatisfy { $0.percent == 100 })
    }

    func testMuscleRecoveryPrefersPlannedFocusWhenRecovered() {
        let items = MuscleRecoveryCalculator.assess(
            sessions: [],
            weeklySets: [.chest: 10, .shoulders: 10, .back: 10, .legs: 0],
            plannedFocus: .back
        )
        XCTAssertEqual(items.first(where: \.isRecommended)?.group, .back)
    }

    // MARK: - 咖啡因代谢与窗口

    func testCaffeineHalfLifeAndOptimalWindow() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let fiveHoursAgo = now.addingTimeInterval(-5 * 3600)
        let entries = [CaffeineEntry(date: fiveHoursAgo, title: "冷萃", mg: 200)]

        let active = CaffeineCalculator.activeMg(entries: entries, at: now)
        XCTAssertEqual(active, 100)

        let window = CaffeineCalculator.optimalWindowText(sleepHour: 23, sleepMinute: 5)
        XCTAssertEqual(window.morningLabel, "11时")
        XCTAssertEqual(window.windowLabel, "13时–16时")
        XCTAssertEqual(CaffeineCalculator.formattedSleepTime(hour: 23, minute: 5), "23:05")
    }

    // MARK: - 本月训练时长

    func testMonthlyTrainingStatsFiltersOtherMonthsAndAvoidsDoubleCountingRuns() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_700_500_000) // 2023-11-20
        let lastMonth = cal.date(byAdding: .month, value: -1, to: now)!

        let s1 = WorkoutSession(date: now.addingTimeInterval(-3600), title: "力量", kind: .strength, durationSec: 3600)
        let sRun = WorkoutSession(date: now, title: "户外跑", kind: .run, durationSec: 1800)
        let rDup = RouteRun(date: now.addingTimeInterval(30), title: "户外跑", distanceM: 5000, durationSec: 1800)
        let rExtra = RouteRun(date: now.addingTimeInterval(-7200), title: "晨跑", distanceM: 5000, durationSec: 1800)
        let sOld = WorkoutSession(date: lastMonth, title: "上月训练", kind: .strength, durationSec: 7200)

        let result = MonthlyTrainingCalculator.stats(
            sessions: [s1, sRun, sOld],
            runs: [rDup, rExtra],
            now: now,
            calendar: cal
        )
        // 3600 + 1800 + 1800(rExtra) = 7200s = 2.0h
        XCTAssertEqual(result.hours, 2.0, accuracy: 0.01)
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - 补剂 / 咖啡因 / 首页小组件持久化

    func testSupplementsCaffeineAndWidgetsRoundTrip() {
        let url = temporaryStateURL()
        let store = AppStore(fileURL: url)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let creatine = SupplementItem(name: "肌酸", dosage: "5 g")
        store.addSupplement(creatine)
        store.addSupplement(creatine) // 重复名称不重复加入
        XCTAssertEqual(store.state.supplements.count, 1)

        store.toggleSupplement(creatine.id, on: now)
        XCTAssertTrue(store.takenSupplementIDs(on: now).contains(creatine.id))

        store.addCaffeine(title: "美式咖啡", mg: 150, at: now)
        XCTAssertEqual(store.todayCaffeineMg(now: now), 150)

        store.setWidgetVisible(.caffeine, visible: false)
        XCTAssertFalse(store.visibleHomeWidgets.contains(.caffeine))
        store.saveNow()

        let reloaded = AppStore(fileURL: url)
        XCTAssertEqual(reloaded.state.supplements.count, 1)
        XCTAssertTrue(reloaded.takenSupplementIDs(on: now).contains(creatine.id))
        XCTAssertEqual(reloaded.todayCaffeineMg(now: now), 150)
        XCTAssertFalse(reloaded.visibleHomeWidgets.contains(.caffeine))

        reloaded.resetHomeWidgets()
        XCTAssertEqual(reloaded.visibleHomeWidgets, HomeWidgetKind.defaultOrder)
    }

    // MARK: - v1.2 旧版 JSON 兼容加载

    func testLegacyV12StateWithoutPhase1FieldsStillDecodes() throws {
        let url = temporaryStateURL()
        let store = AppStore(fileURL: url)
        store.addSession(WorkoutSession(title: "旧记录"))
        store.saveNow()

        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        for key in [
            "supplements", "supplementLogs", "caffeineEntries", "caffeineLimitMg",
            "sleepTargetHour", "sleepTargetMinute", "homeWidgets", "hiddenHomeWidgets"
        ] {
            object.removeValue(forKey: key)
        }
        if var profile = object["profile"] as? [String: Any] {
            profile.removeValue(forKey: "maxHeartRate")
            profile.removeValue(forKey: "injuryAvoidAreas")
            profile.removeValue(forKey: "preferredUnit")
            object["profile"] = profile
        }
        try JSONSerialization.data(withJSONObject: object).write(to: url)

        let loaded = AppStore(fileURL: url)
        XCTAssertTrue(loaded.state.sessions.contains { $0.title == "旧记录" })
        XCTAssertEqual(loaded.state.caffeineLimitMg, 400)
        XCTAssertEqual(loaded.state.sleepTargetHour, 23)
        XCTAssertEqual(loaded.state.sleepTargetMinute, 5)
        XCTAssertEqual(loaded.visibleHomeWidgets, HomeWidgetKind.defaultOrder)
        XCTAssertEqual(loaded.state.profile.preferredUnit, "kg")
    }
}
