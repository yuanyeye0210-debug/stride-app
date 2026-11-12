import XCTest
@testable import Stride

@MainActor
final class PersistenceTests: XCTestCase {

    private func temporaryStateURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("state.json")
    }

    func testSaveLoadRoundTripKeepsWorkoutFoodAndRun() throws {
        let url = temporaryStateURL()
        let store = AppStore(fileURL: url)
        let when = Date(timeIntervalSince1970: 1_700_000_000)

        let session = WorkoutSession(date: when, title: "往返训练", kind: .strength, durationSec: 1200, kcal: 80)
        store.addSession(session)
        let food = FoodEntry(
            date: when.addingTimeInterval(60),
            meal: .lunch,
            items: [FoodItem(name: "米饭", grams: 200, kcal: 230, protein: 4, carbs: 50, fat: 1)]
        )
        store.addFood(food)
        let run = RouteRun(
            date: when.addingTimeInterval(120),
            title: "往返夜跑",
            distanceM: 3200,
            durationSec: 1100,
            points: [GeoPoint(lat: 31.2, lon: 121.5)]
        )
        store.addRun(run)
        store.saveNow()

        let loaded = AppStore(fileURL: url)
        let loadedSession = try XCTUnwrap(loaded.state.sessions.first { $0.id == session.id })
        XCTAssertEqual(loadedSession.title, "往返训练")
        XCTAssertEqual(loadedSession.date.timeIntervalSince1970, when.timeIntervalSince1970, accuracy: 1)

        let loadedFood = try XCTUnwrap(loaded.state.foods.first { $0.id == food.id })
        XCTAssertEqual(loadedFood.items.first?.name, "米饭")
        XCTAssertEqual(loadedFood.kcal, 230, accuracy: 0.01)

        let loadedRun = try XCTUnwrap(loaded.state.runs.first { $0.id == run.id })
        XCTAssertEqual(loadedRun.title, "往返夜跑")
        XCTAssertEqual(loadedRun.distanceM, 3200, accuracy: 0.01)

        XCTAssertEqual(loaded.state.sessions.count, store.state.sessions.count)
        XCTAssertEqual(loaded.state.foods.count, store.state.foods.count)
        XCTAssertEqual(loaded.state.runs.count, store.state.runs.count)
        XCTAssertTrue(loaded.state.seeded)
    }

    func testWorkoutRoundTripKeepsSetsAndDates() throws {
        let url = temporaryStateURL()
        let store = AppStore(fileURL: url)
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        let session = WorkoutSession(
            date: when,
            title: "卧推日",
            kind: .strength,
            exercises: [
                LoggedExercise(
                    exerciseID: UUID(),
                    name: "杠铃卧推",
                    sets: [
                        SetEntry(weight: 60, reps: 10, done: true),
                        SetEntry(weight: 62.5, reps: 8, done: true)
                    ]
                )
            ],
            durationSec: 3600,
            kcal: 400
        )
        store.addSession(session)
        store.saveNow()

        let loaded = AppStore(fileURL: url)
        let back = try XCTUnwrap(loaded.state.sessions.first { $0.id == session.id })
        XCTAssertEqual(back.title, "卧推日")
        XCTAssertEqual(back.date.timeIntervalSince1970, when.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(back.exercises.first?.sets.count, 2)
        XCTAssertEqual(back.exercises.first?.sets[1].weight ?? 0, 62.5, accuracy: 0.01)
        XCTAssertEqual(back.exercises.first?.sets[1].reps ?? 0, 8)
    }

    func testFoodRoundTripKeepsItemsAndMeal() throws {
        let url = temporaryStateURL()
        let store = AppStore(fileURL: url)
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        let food = FoodEntry(
            date: when,
            meal: .dinner,
            items: [
                FoodItem(name: "鸡胸肉", grams: 180, kcal: 297, protein: 56, carbs: 0, fat: 6),
                FoodItem(name: "糙米饭", grams: 200, kcal: 232, protein: 5, carbs: 48, fat: 2)
            ],
            recognizedByAI: true
        )
        store.addFood(food)
        store.saveNow()

        let loaded = AppStore(fileURL: url)
        let back = try XCTUnwrap(loaded.state.foods.first { $0.id == food.id })
        XCTAssertEqual(back.meal, .dinner)
        XCTAssertEqual(back.items.count, 2)
        XCTAssertEqual(back.items.first?.name, "鸡胸肉")
        XCTAssertEqual(back.kcal, 529, accuracy: 0.01)
        XCTAssertTrue(back.recognizedByAI)
    }

    func testRunRoundTripKeepsPointsAndStyle() throws {
        let url = temporaryStateURL()
        let store = AppStore(fileURL: url)
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        var run = RouteRun(
            date: when,
            title: "夜跑",
            distanceM: 5000,
            durationSec: 1800,
            points: [
                GeoPoint(lat: 31.2, lon: 121.5),
                GeoPoint(lat: 31.21, lon: 121.51),
                GeoPoint(lat: 31.22, lon: 121.52)
            ]
        )
        run.styleRaw = RouteArtStyle.dots.rawValue
        store.addRun(run)
        store.saveNow()

        let loaded = AppStore(fileURL: url)
        let back = try XCTUnwrap(loaded.state.runs.first { $0.id == run.id })
        XCTAssertEqual(back.title, "夜跑")
        XCTAssertEqual(back.points.count, 3)
        XCTAssertEqual(back.points[1].lat, 31.21, accuracy: 0.0001)
        XCTAssertEqual(back.style, .dots)
        XCTAssertEqual(back.paceSecPerKm, 360)
    }

    // 行为已变（v1.2 Task A4）：损坏文件不再原地保留，而是改名隔离，
    // 原字节保留在隔离文件里，种子数据仍不覆盖用户文件。
    // 隔离的完整断言见 BackupTests.testCorruptFileIsQuarantinedNotDeleted。
    func testUnreadableFileIsQuarantinedNotSeededOver() throws {
        let url = temporaryStateURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = Data("keep-real-records".utf8)
        try original.write(to: url)

        let store = AppStore(fileURL: url)

        let dir = url.deletingLastPathComponent()
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        let quarantined = try XCTUnwrap(names.first { $0.hasPrefix("state.corrupt-") })
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(quarantined)), original)
        XCTAssertNotNil(store.dataIssue)
        XCTAssertTrue(store.state.sessions.isEmpty)
    }
}
