import XCTest
import UIKit
@testable import Stride

@MainActor
final class VisualEffectsAndFeaturesTests: XCTestCase {

    private func makeTempStore() -> AppStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StrideVisualTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return AppStore(fileURL: dir.appendingPathComponent("state.json"))
    }

    func testRecordSleepClampsAndPersistsInTodaySnapshot() {
        let store = makeTempStore()
        store.recordSleep(minutes: 465)
        XCTAssertEqual(store.todaySnapshot.sleepMinutes, 465)

        store.recordSleep(minutes: 15) // 下界钳位至 60
        XCTAssertEqual(store.todaySnapshot.sleepMinutes, 60)

        store.recordSleep(minutes: 1400) // 上界钳位至 960
        XCTAssertEqual(store.todaySnapshot.sleepMinutes, 960)
    }

    func testMoveHomeWidgetReordersVisibleListSafely() {
        let store = makeTempStore()
        store.resetHomeWidgets()
        let initial = store.visibleHomeWidgets
        guard initial.count >= 2 else {
            XCTFail("默认可见小组件应至少有 2 个")
            return
        }
        let first = initial[0]
        let second = initial[1]

        store.moveHomeWidget(first, by: 1)
        let afterMoveDown = store.visibleHomeWidgets
        XCTAssertEqual(afterMoveDown[0], second)
        XCTAssertEqual(afterMoveDown[1], first)

        store.moveHomeWidget(first, by: -1)
        XCTAssertEqual(store.visibleHomeWidgets[0], first)
    }

    func testSaveLoadAndClearAvatarImage() {
        let store = makeTempStore()
        XCTAssertNil(store.loadAvatarImage())
        let rev0 = store.avatarRevision

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        let img = renderer.image { ctx in
            UIColor.systemGreen.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }

        store.saveAvatarImage(img)
        XCTAssertEqual(store.avatarRevision, rev0 + 1)
        XCTAssertNotNil(store.loadAvatarImage())

        store.clearAvatarImage()
        XCTAssertEqual(store.avatarRevision, rev0 + 2)
        XCTAssertNil(store.loadAvatarImage())
    }

    func testTactileRulerMathClampAndDrag() {
        let snapped = TactileRulerMath.clampAndSnap(74.84, range: 35...180, step: 0.1)
        XCTAssertEqual(snapped, 74.8, accuracy: 0.001)

        // 向左拖动 (-100pt, 每 10pt = 0.1kg) -> 增加 1.0kg
        let dragged = TactileRulerMath.valueForDrag(
            startValue: 70.0,
            translationX: -100,
            pointsPerStep: 10,
            step: 0.1,
            range: 35...180
        )
        XCTAssertEqual(dragged, 71.0, accuracy: 0.001)
    }

    func testTapTempoCalculatorComputesExpectedBPM() {
        // 间隔 0.3333 秒 => 180 BPM
        let timestamps: [TimeInterval] = [10.0, 10.3333, 10.6666, 11.0]
        let bpm = TapTempoCalculator.computeBPM(timestamps: timestamps, range: 120...220)
        XCTAssertEqual(bpm, 180)
        XCTAssertNil(TapTempoCalculator.computeBPM(timestamps: [1.0]))
    }

    func testAmbientAudioSynthesizeLoopBufferForAllScenes() {
        for scene in AmbientScene.allCases {
            let buffer = AmbientAudioEngine.synthesizeLoopBuffer(scene: scene, sampleRate: 22050, seconds: 0.5)
            XCTAssertNotNil(buffer, "\(scene.rawValue) 离线声场缓冲不应为空")
            XCTAssertEqual(buffer?.frameLength, 11025)
        }
    }

    func testPodcastCatalogIntegrityAndSpeedCycle() {
        XCTAssertEqual(PodcastSpeechPlayer.catalog.count, 3)
        for ep in PodcastSpeechPlayer.catalog {
            XCTAssertFalse(ep.title.isEmpty)
            XCTAssertGreaterThanOrEqual(ep.segments.count, 4)
        }

        let player = PodcastSpeechPlayer.shared
        player.playbackSpeedMultiplier = 1.0
        player.cycleSpeed()
        XCTAssertEqual(player.playbackSpeedMultiplier, 1.25, accuracy: 0.01)
        player.cycleSpeed()
        XCTAssertEqual(player.playbackSpeedMultiplier, 1.5, accuracy: 0.01)
        player.cycleSpeed()
        XCTAssertEqual(player.playbackSpeedMultiplier, 1.0, accuracy: 0.01)
    }

    func testRepairedV2ExerciseVideosInCatalog() {
        let all = ExerciseCatalogStore.shared.all
        XCTAssertEqual(all.count, 77)

        let v2IDs = ["incline-dumbbell-press", "cable-lateral-raise", "leg-extension"]
        for id in v2IDs {
            guard let item = all.first(where: { $0.id == id }) else {
                XCTFail("缺少动作 \(id)")
                continue
            }
            XCTAssertTrue(
                item.video?.hasSuffix("\(id)-v2.mp4") == true,
                "\(id) 必须指向修复后的 -v2.mp4 URL，实际为 \(item.video ?? "nil")"
            )
        }
    }
}
