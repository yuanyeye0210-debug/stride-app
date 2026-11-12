import XCTest
@testable import Stride

@MainActor
final class BackupTests: XCTestCase {

    private func sampleState() -> AppState {
        var state = AppState()
        state.seeded = true
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        state.sessions = [
            WorkoutSession(date: when, title: "往返训练", kind: .strength, durationSec: 1200, kcal: 80)
        ]
        state.foods = [
            FoodEntry(
                date: when.addingTimeInterval(60),
                meal: .lunch,
                items: [FoodItem(name: "米饭", grams: 200, kcal: 230, protein: 4, carbs: 50, fat: 1)]
            )
        ]
        state.runs = [
            RouteRun(
                date: when.addingTimeInterval(120),
                title: "往返夜跑",
                distanceM: 3200,
                durationSec: 1100,
                points: [GeoPoint(lat: 31.2, lon: 121.5)]
            )
        ]
        state.waterDays = [
            WaterDay(day: "2023-11-14", ml: 1000),
            WaterDay(day: "2023-11-15", ml: 500)
        ]
        state.waterGoalMl = 1800
        return state
    }

    // MARK: - Task A1: 信封与校验

    func testEnvelopeRoundTripKeepsCounts() throws {
        let state = sampleState()
        let data = try Backup.encode(state)
        let decoded = try Backup.decode(data)

        XCTAssertEqual(decoded.sessions.count, 1)
        XCTAssertEqual(decoded.foods.count, 1)
        XCTAssertEqual(decoded.runs.count, 1)
        XCTAssertEqual(decoded.waterDays.count, 2)
        XCTAssertEqual(decoded.waterDays.first { $0.day == "2023-11-14" }?.ml, 1000)
        XCTAssertEqual(decoded.waterGoalMl, 1800)
        XCTAssertEqual(decoded.sessions.first?.title, "往返训练")
    }

    func testDecodeAcceptsBareAppState() throws {
        let state = sampleState()
        let bare = try AppStore.encoder().encode(state)
        let decoded = try Backup.decode(bare)
        XCTAssertEqual(decoded.sessions.count, 1)
        XCTAssertEqual(decoded.foods.count, 1)
    }

    func testDecodeRejectsGarbage() {
        XCTAssertThrowsError(try Backup.decode(Data("not json".utf8))) { error in
            XCTAssertEqual(error as? BackupError, .invalidFile)
        }
    }

    func testDecodeRejectsUnsupportedVersion() throws {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try Backup.encode(sampleState())) as? [String: Any]
        )
        object["schemaVersion"] = 99
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try Backup.decode(data)) { error in
            XCTAssertEqual(error as? BackupError, .unsupportedVersion(99))
        }
    }

    func testValidateRejectsInsaneProfile() {
        var state = sampleState()
        state.profile.weightKg = 0
        XCTAssertThrowsError(try Backup.validate(state)) { error in
            guard case BackupError.validationFailed = error else {
                return XCTFail("expected validationFailed, got \(error)")
            }
        }

        var tall = sampleState()
        tall.profile.heightCm = 400
        XCTAssertThrowsError(try Backup.validate(tall))

        var noGoal = sampleState()
        noGoal.waterGoalMl = 0
        XCTAssertThrowsError(try Backup.validate(noGoal))
    }

    func testValidateAcceptsSampleState() throws {
        try Backup.validate(sampleState())
    }

    // MARK: - Task A2: 导出（由 AppStore.exportData 覆盖，见下）

    func testExportDataDecodesBackToSameCounts() throws {
        let url = temporaryStateURL()
        let store = AppStore(fileURL: url)
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        store.addSession(WorkoutSession(date: when, title: "导出训练", durationSec: 600, kcal: 50))
        store.addFood(FoodEntry(date: when, meal: .lunch, items: [
            FoodItem(name: "米饭", grams: 200, kcal: 230, protein: 4, carbs: 50, fat: 1)
        ]))
        store.addRun(RouteRun(date: when, title: "导出夜跑", distanceM: 3000, durationSec: 1000, points: []))

        let decoded = try Backup.decode(store.exportData())
        XCTAssertEqual(decoded.sessions.filter { $0.title == "导出训练" }.count, 1)
        XCTAssertEqual(decoded.foods.count, store.state.foods.count)
        XCTAssertEqual(decoded.runs.filter { $0.title == "导出夜跑" }.count, 1)
    }

    func testExportFileNameFormat() {
        let date = Date(timeIntervalSince1970: 1_699_950_000)
        let utc = TimeZone(secondsFromGMT: 0)!
        XCTAssertEqual(AppStore.exportFileName(date: date, timeZone: utc), "stride-backup-2023-11-14.json")
    }

    // MARK: - Task A3: 导入（先备份当前数据，再整体替换）

    func testImportReplacesStateButKeepsBackup() throws {
        let url = temporaryStateURL()
        let store = AppStore(fileURL: url)
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        store.addSession(WorkoutSession(date: when, title: "旧训练", durationSec: 600, kcal: 50))
        store.saveNow()

        var incoming = AppState()
        incoming.seeded = true
        incoming.sessions = [
            WorkoutSession(date: when, title: "新训练一", durationSec: 600, kcal: 50),
            WorkoutSession(date: when, title: "新训练二", durationSec: 600, kcal: 50)
        ]
        let backupData = try Backup.encode(incoming)

        try store.importData(backupData)

        XCTAssertEqual(store.state.sessions.count, 2)
        XCTAssertTrue(store.state.sessions.contains { $0.title == "新训练一" })
        XCTAssertTrue(store.state.sessions.contains { $0.title == "新训练二" })

        let dir = url.deletingLastPathComponent()
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        let backupName = try XCTUnwrap(names.first { $0.hasPrefix("state.backup-before-import-") })
        let backupState = try Backup.decode(Data(contentsOf: dir.appendingPathComponent(backupName)))
        XCTAssertTrue(backupState.sessions.contains { $0.title == "旧训练" })
    }

    func testImportRejectsGarbageWithoutTouchingState() throws {
        let url = temporaryStateURL()
        let store = AppStore(fileURL: url)
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        store.addSession(WorkoutSession(date: when, title: "别动我", durationSec: 600, kcal: 50))
        store.saveNow()
        let before = try Data(contentsOf: url)

        XCTAssertThrowsError(try store.importData(Data("garbage".utf8)))
        XCTAssertEqual(store.state.sessions.filter { $0.title == "别动我" }.count, 1)
        XCTAssertEqual(try Data(contentsOf: url), before)
    }

    // MARK: - Task A4: 损坏文件隔离

    func testCorruptFileIsQuarantinedNotDeleted() throws {
        let url = temporaryStateURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = Data("keep-real-records".utf8)
        try original.write(to: url)

        let store = AppStore(fileURL: url)

        let dir = url.deletingLastPathComponent()
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        let quarantined = try XCTUnwrap(names.first { $0.hasPrefix("state.corrupt-") })
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(quarantined)), original)
        // 新 state.json 是合法 JSON、能解码，而不是原地留着坏文件。
        let fresh = try Backup.decode(Data(contentsOf: url))
        XCTAssertTrue(fresh.sessions.isEmpty)
        XCTAssertNotNil(store.dataIssue)
        XCTAssertTrue(store.state.sessions.isEmpty)
    }

    // MARK: - 评审修复 C1：越界字段加载并修正，不隔离

    func testOutOfRangeProfileLoadsAndClampsInsteadOfQuarantine() throws {
        let url = temporaryStateURL()
        let store = AppStore(fileURL: url)
        store.state.profile.weightKg = 0
        store.state.profile.heightCm = 400
        store.saveNow()
        let sessionCount = store.state.sessions.count
        XCTAssertGreaterThan(sessionCount, 0)

        let loaded = AppStore(fileURL: url)

        XCTAssertEqual(loaded.state.profile.weightKg, 20, accuracy: 0.01)
        XCTAssertEqual(loaded.state.profile.heightCm, 250, accuracy: 0.01)
        XCTAssertEqual(loaded.state.sessions.count, sessionCount)
        XCTAssertEqual(loaded.dataIssue, .fieldsClamped(["体重", "身高"]))
        let dir = url.deletingLastPathComponent()
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(names.filter { $0.hasPrefix("state.corrupt-") }.isEmpty)
        // 修正后的值已写回文件。
        let reloaded = AppStore(fileURL: url)
        XCTAssertEqual(reloaded.state.profile.weightKg, 20, accuracy: 0.01)
        XCTAssertNil(reloaded.dataIssue)
    }

    func testClampProfileRanges() {
        var profile = Profile()
        profile.weightKg = 0
        profile.heightCm = 99
        profile.dailyKcalGoal = 0
        let clamped = Backup.clampProfile(profile)
        XCTAssertEqual(clamped.weightKg, 20, accuracy: 0.01)
        XCTAssertEqual(clamped.heightCm, 100, accuracy: 0.01)
        XCTAssertEqual(clamped.dailyKcalGoal, 2200)
    }

    // MARK: - 评审修复 I2：导入强制 seeded，避免演示播种

    func testImportForcesSeededTrue() throws {
        let url = temporaryStateURL()
        let store = AppStore(fileURL: url)
        var incoming = AppState()
        incoming.seeded = false
        incoming.sessions = []
        try store.importData(try Backup.encode(incoming))

        XCTAssertTrue(store.state.seeded)
        let reloaded = AppStore(fileURL: url)
        XCTAssertTrue(reloaded.state.sessions.isEmpty)
    }

    // MARK: - 评审修复 I1：自动备份可列出、可恢复

    func testAutoBackupsAreListedAfterImport() throws {
        let url = temporaryStateURL()
        let store = AppStore(fileURL: url)
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        store.addSession(WorkoutSession(date: when, title: "旧训练", durationSec: 600, kcal: 50))
        store.saveNow()

        var incoming = AppState()
        incoming.seeded = true
        incoming.sessions = [WorkoutSession(date: when, title: "新训练", durationSec: 600, kcal: 50)]
        try store.importData(try Backup.encode(incoming))

        let backups = store.autoBackupURLs()
        XCTAssertFalse(backups.isEmpty)
        let backupState = try Backup.decode(Data(contentsOf: backups[0]))
        XCTAssertTrue(backupState.sessions.contains { $0.title == "旧训练" })
    }

    // MARK: - Helpers

    private func temporaryStateURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("state.json")
    }
}
