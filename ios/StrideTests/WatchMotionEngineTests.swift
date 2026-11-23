import XCTest
import Combine
@testable import Stride

final class WatchMotionEngineTests: XCTestCase {

    func testClassifierBundleLoadsAndIdentifiesAll11Classes() throws {
        let classifier = try XCTUnwrap(WatchExerciseClassifier.loadDefault(), "应能从主 Bundle 加载 watch_exercise_classifier_v1.json")
        XCTAssertEqual(classifier.payload.labels.count, 11)
        XCTAssertGreaterThanOrEqual(classifier.payload.testAccuracy ?? 0, 0.95)

        for exercise in WatchExerciseClass.allCases {
            let frames = WatchIMUWaveformSimulator.generateStream(for: exercise, reps: 2, sampleRate: 50, periodSec: 2.0)
            let window = Array(frames.prefix(100))
            let result = classifier.classify(frames: window)
            XCTAssertEqual(
                result.predicted,
                exercise,
                "模型应正确识别 \(exercise.nameZH)，实际预测为 \(result.predicted.nameZH)（置信度 \(result.confidence)）"
            )
            XCTAssertGreaterThan(result.confidence, 0.55, "\(exercise.nameZH) 预测置信度应显著高于随机阈值")
        }
    }

    func testAdaptiveRepCounterCountsRepsAccuratelyAndIgnoresIdle() {
        for exercise in [WatchExerciseClass.barbellBenchPress, .dumbbellBicepCurl, .barbellBackSquat, .lateralRaise] {
            let counter = AdaptiveRepCounter()
            let stream = WatchIMUWaveformSimulator.generateStream(for: exercise, reps: 5, sampleRate: 50, periodSec: 2.0)
            for frame in stream {
                counter.ingest(frame: frame, activeExercise: exercise, confidence: 0.95)
            }
            XCTAssertTrue(
                (4...6).contains(counter.repCount),
                "\(exercise.nameZH) 5 个周期流计次应接近 5（实测 \(counter.repCount)）"
            )
        }

        // 静息或日走动绝不应触发力量动作计次
        let idleCounter = AdaptiveRepCounter()
        let idleStream = WatchIMUWaveformSimulator.generateStream(for: .idle, reps: 4, sampleRate: 50, periodSec: 2.0)
        for frame in idleStream {
            idleCounter.ingest(frame: frame, activeExercise: .idle, confidence: 0.99)
        }
        XCTAssertEqual(idleCounter.repCount, 0, "静息状态下自动计次必须保持为 0")
    }

    func testUserCalibrationPrototypePersistsAndReloads() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let calURL = tmpDir.appendingPathComponent("watch_calibration.json")
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let url = try XCTUnwrap(
            Bundle(for: WatchExerciseClassifier.self).url(forResource: "watch_exercise_classifier_v1", withExtension: "json")
                ?? Bundle.main.url(forResource: "watch_exercise_classifier_v1", withExtension: "json")
        )
        let payload = try JSONDecoder().decode(WatchMLPModelPayload.self, from: Data(contentsOf: url))

        let writer = WatchExerciseClassifier(payload: payload, calibrationURL: calURL)
        let stream = WatchIMUWaveformSimulator.generateStream(for: .barbellDeadlift, reps: 3, sampleRate: 50, periodSec: 2.0)
        writer.saveCalibration(for: .barbellDeadlift, windows: [Array(stream.prefix(100)), Array(stream.suffix(100))])
        XCTAssertNotNil(writer.prototypes[WatchExerciseClass.barbellDeadlift.rawValue])

        let reader = WatchExerciseClassifier(payload: payload, calibrationURL: calURL)
        let loaded = try XCTUnwrap(reader.prototypes[WatchExerciseClass.barbellDeadlift.rawValue])
        XCTAssertEqual(loaded.sampleWindows, 2)
        XCTAssertEqual(loaded.normalizedFeatureMean.count, WatchMotionFeatureExtractor.featureCount)

        reader.clearCalibration(for: .barbellDeadlift)
        XCTAssertTrue(reader.prototypes.isEmpty)
    }

    @MainActor
    func testWatchMotionControllerForwardsWatchRepEvents() {
        let controller = WatchMotionSessionController(calibrationURL: FileManager.default.temporaryDirectory.appendingPathComponent("unused-\(UUID().uuidString).json"))
        var received: [WatchRepDetectedEvent] = []
        let bag = controller.repPublisher.sink { received.append($0) }

        controller.ingestWatchEvent(
            kind: "rep",
            exerciseId: WatchExerciseClass.pullUp.rawValue,
            repCount: 7,
            confidence: 0.94,
            tempoSec: 2.4
        )

        XCTAssertEqual(controller.currentExercise, .pullUp)
        XCTAssertEqual(controller.repCount, 7)
        XCTAssertEqual(controller.sourceMode, .watchBridge)
        XCTAssertEqual(received.last?.exercise, .pullUp)
        XCTAssertEqual(received.last?.repCount, 7)
        bag.cancel()
    }
}
