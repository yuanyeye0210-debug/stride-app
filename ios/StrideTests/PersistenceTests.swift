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
        let loadedSession = loaded.state.sessions.first { $0.id == session.id }
        XCTAssertEqual(loadedSession?.title, "往返训练")
        XCTAssertEqual(loadedSession?.date.timeIntervalSince1970, when.timeIntervalSince1970, accuracy: 1)

        let loadedFood = loaded.state.foods.first { $0.id == food.id }
        XCTAssertEqual(loadedFood?.items.first?.name, "米饭")
        XCTAssertEqual(loadedFood?.kcal, 230, accuracy: 0.01)

        let loadedRun = loaded.state.runs.first { $0.id == run.id }
        XCTAssertEqual(loadedRun?.title, "往返夜跑")
        XCTAssertEqual(loadedRun?.distanceM, 3200, accuracy: 0.01)

        XCTAssertEqual(loaded.state.sessions.count, store.state.sessions.count)
        XCTAssertEqual(loaded.state.foods.count, store.state.foods.count)
        XCTAssertEqual(loaded.state.runs.count, store.state.runs.count)
        XCTAssertTrue(loaded.state.seeded)
    }

    func testUnreadableFileIsNotReplacedBySeed() throws {
        let url = temporaryStateURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = Data("keep-real-records".utf8)
        try original.write(to: url)

        _ = AppStore(fileURL: url)

        XCTAssertEqual(try Data(contentsOf: url), original)
    }
}
