import XCTest
@testable import Stride

@MainActor
final class FullFeaturesTests: XCTestCase {

    private func temporaryStateURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("state.json")
    }

    // MARK: - Phase 2: 模板库、耗能等级、单日覆写

    func testTemplateCatalogIntegrityAndStoreOperations() {
        XCTAssertEqual(TemplateCatalog.categories.count, 16)
        XCTAssertFalse(TemplateCatalog.weekPlans.isEmpty)
        XCTAssertEqual(TemplateCatalog.runPrograms.count, 6)
        XCTAssertGreaterThanOrEqual(TemplateCatalog.singleWorkouts.count, 18)

        for week in TemplateCatalog.weekPlans {
            XCTAssertEqual(week.days.count, 7)
            let weekdays = Set(week.days.map(\.weekday))
            XCTAssertEqual(weekdays.count, 7)
        }

        let url = temporaryStateURL()
        let store = AppStore(fileURL: url)
        let tpl = TemplateCatalog.singleWorkouts[0]

        store.toggleTemplateFavorite(tpl.id)
        XCTAssertTrue(store.isTemplateFavorite(tpl.id))

        let today = Date()
        store.applyTemplateToDay(tpl, on: today)
        XCTAssertTrue(store.hasDayOverride(on: today))
        XCTAssertEqual(store.plannedDay(on: today)?.title, tpl.title)

        store.clearDayOverride(on: today)
        XCTAssertFalse(store.hasDayOverride(on: today))

        let custom = WorkoutTemplate(
            id: "custom.test",
            posterWords: ["TEST"],
            accentRaw: "silver",
            title: "测试自定义模板",
            level: "进阶",
            estimatedMinutes: 45,
            categories: ["分化训练"],
            focus: .chest,
            exercises: [PlannedExercise(name: "杠铃卧推", sets: 4, reps: "8")],
            isCustom: true
        )
        store.addCustomTemplate(custom)
        store.saveNow()

        let reloaded = AppStore(fileURL: url)
        XCTAssertTrue(reloaded.state.favoriteTemplateIDs.contains(tpl.id))
        XCTAssertTrue(reloaded.state.customTemplates.contains { $0.id == "custom.test" })
    }

    func testWorkoutIntensityInference() {
        let hardEx = LoggedExercise(
            exerciseID: UUID(),
            name: "深蹲",
            sets: [SetEntry(weight: 100, reps: 5, rpe: 9.5, done: true)]
        )
        let maxSession = WorkoutSession(title: "极限蹲", exercises: [hardEx])
        XCTAssertEqual(maxSession.inferredIntensity, .maxEffort)

        let easyEx = LoggedExercise(
            exerciseID: UUID(),
            name: "拉伸",
            sets: [SetEntry(weight: 0, reps: 10, rpe: 6.0, done: true)]
        )
        let easySession = WorkoutSession(title: "恢复", exercises: [easyEx])
        XCTAssertEqual(easySession.inferredIntensity, .easy)
    }

    // MARK: - Phase 3: 亮点洞察、体重、碳循环

    func testInsightsEngineAndCarbCycleRoundTrip() {
        let url = temporaryStateURL()
        let store = AppStore(fileURL: url)

        store.recordWeight(74.5)
        XCTAssertEqual(store.state.profile.weightKg, 74.5, accuracy: 0.01)

        store.state.carbCycle.enabled = true
        store.state.carbCycle.highDays = [2] // 周一
        store.state.carbCycle.highCarbG = 300
        store.state.carbCycle.lowCarbG = 140
        store.saveNow()

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        // 2023-11-13 是周一 (weekday == 2)
        let monday = Date(timeIntervalSince1970: 1_699_876_800)
        let sunday = cal.date(byAdding: .day, value: 6, to: monday)!

        let reloaded = AppStore(fileURL: url)
        XCTAssertTrue(reloaded.state.carbCycle.enabled)
        XCTAssertEqual(reloaded.state.carbCycle.targetGrams(for: 2, fallback: 200), 300)
        XCTAssertEqual(reloaded.state.carbCycle.targetGrams(for: 1, fallback: 200), 140)
        XCTAssertEqual(cal.component(.weekday, from: sunday), 1)

        let insights = InsightsEngine.generate(state: reloaded.state)
        XCTAssertEqual(insights.count, 21)
    }

    // MARK: - Phase 4: 45 项运动、62 款插件、领地隐私过滤与跑鞋里程

    func testSportsAndPluginsCatalogCountsAndUniqueIDs() {
        XCTAssertEqual(SportsCatalog.all.count, 45)
        XCTAssertEqual(SportsCatalog.items(in: .featuredRun).count, 5)
        XCTAssertEqual(SportsCatalog.items(in: .outdoor).count, 11)
        XCTAssertEqual(SportsCatalog.items(in: .indoorCardio).count, 10)
        XCTAssertEqual(SportsCatalog.items(in: .ballSports).count, 13)
        XCTAssertEqual(SportsCatalog.items(in: .combat).count, 3)
        XCTAssertEqual(SportsCatalog.items(in: .mindBody).count, 3)

        XCTAssertEqual(PluginsCatalog.all.count, 62)
        XCTAssertEqual(Set(PluginsCatalog.all.map(\.id)).count, 62)
    }

    func testPluginMathFormulas() {
        let seven = PluginMath.seven1RMFormulas(weight: 100, reps: 5)
        XCTAssertEqual(seven.count, 7)
        XCTAssertGreaterThan(seven[0].kg, 110)

        let plates = PluginMath.platesPerSide(targetKg: 100, barKg: 20)
        XCTAssertEqual(plates, [25, 15])

        let dots = PluginMath.dotsScore(bodyweightKg: 75, totalKg: 500, male: true)
        XCTAssertGreaterThan(dots, 300)

        let bf = PluginMath.navyBodyFat(male: true, heightCm: 178, waistCm: 82, neckCm: 38)
        XCTAssertTrue((8...30).contains(bf))

        let tenK = PluginMath.riegelPredict(knownMeters: 5000, knownSeconds: 1500, targetMeters: 10000)
        XCTAssertGreaterThan(tenK, 3000)
        XCTAssertLessThan(tenK, 3300)
    }

    func testTerritoryPrivacyFilterAndShoeMileageAccumulation() {
        let url = temporaryStateURL()
        let store = AppStore(fileURL: url)
        store.addShoe(name: "Pegasus 41", brand: "Nike", maxKm: 600)

        let homePt = GeoPoint(lat: 31.2304, lon: 121.4737)
        let farPt = GeoPoint(lat: 31.2500, lon: 121.4900)
        let run = RouteRun(
            title: "测试跑",
            distanceM: 5000,
            durationSec: 1600,
            points: [homePt, farPt]
        )
        store.addRun(run)

        XCTAssertEqual(store.state.shoes.first?.loggedKm ?? 0, 5.0, accuracy: 0.01)

        let zones = [PrivacyZone(name: "家", lat: homePt.lat, lon: homePt.lon, radiusM: 300)]
        let filtered = TerritoryCalculator.filteredPoints(run.points, privacyZones: zones)
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.lat ?? 0, farPt.lat, accuracy: 0.0001)
    }

    // MARK: - Phase 5: 向后兼容无新字段状态与伤病上下文

    func testLegacyJSONWithoutPhase2To5FieldsLoadsCleanly() throws {
        let url = temporaryStateURL()
        let store = AppStore(fileURL: url)
        store.saveNow()

        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        for key in [
            "customTemplates", "favoriteTemplateIDs", "dayOverrides", "planRepeatWeeks", "calendarShowEffort",
            "photoMemories", "carbCycle", "quickFoodTemplates", "fiberGoalG",
            "installedPluginIDs", "shoes", "privacyZones", "runMapStyleRaw", "favoriteMusicIDs",
            "hapticModeRaw", "appearanceRaw", "languageCode", "remindersEnabled", "showWidgetGuideCard"
        ] {
            object.removeValue(forKey: key)
        }
        try JSONSerialization.data(withJSONObject: object).write(to: url)

        let loaded = AppStore(fileURL: url)
        XCTAssertEqual(loaded.state.fiberGoalG, 25, accuracy: 0.01)
        XCTAssertEqual(loaded.state.quickFoodTemplates.count, 3)
        XCTAssertEqual(loaded.state.hapticModeRaw, "necessary")
        XCTAssertTrue(loaded.state.calendarShowEffort)

        loaded.state.profile.injuryAvoidAreas = ["腕管综合征"]
        let ctx = CoachEngine.context(store: loaded)
        XCTAssertTrue(ctx.contains("腕管综合征"))
    }
}
