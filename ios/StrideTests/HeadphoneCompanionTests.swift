import XCTest
@testable import Stride

final class HeadphoneCompanionTests: XCTestCase {

    func testHeadPostureEngineCalibratesTimesOutCoolsDownAndResets() {
        let engine = HeadPostureEngine(angleThresholdDeg: 20, timeoutSeconds: 10, cooldownSeconds: 15)
        // 先以轻微前倾 5° 校准为正坐 0°
        engine.calibrate(currentDownwardPitchDeg: 5.0)
        XCTAssertEqual(engine.baselinePitchDeg, 5.0)

        // 模拟 0°（原 5°）保持 20 秒 -> 不触发低头
        var t: TimeInterval = 0
        for _ in 0..<40 {
            t += 0.5
            let out = engine.step(downwardPitchDeg: 5.0, timestamp: t)
            XCTAssertFalse(out.shouldTriggerAlert)
            XCTAssertEqual(out.alertLevel, .upright)
        }

        // 模拟低头到 +32°（相对 +27° >= 20° 阈值），持续推进超过 10 秒 -> 触发一次提醒
        var alertCount = 0
        for _ in 0..<26 {
            t += 0.5
            let out = engine.step(downwardPitchDeg: 32.0, timestamp: t)
            if out.shouldTriggerAlert { alertCount += 1 }
        }
        XCTAssertEqual(alertCount, 1, "连续低头超过 10 秒并在 15 秒冷却内应只提醒 1 次")
        XCTAssertGreaterThanOrEqual(engine.continuousHeadDownSec, 10.0)

        // 再持续 18 秒低头 -> 冷却结束，应再次提醒
        var secondAlerts = 0
        for _ in 0..<36 {
            t += 0.5
            let out = engine.step(downwardPitchDeg: 32.0, timestamp: t)
            if out.shouldTriggerAlert { secondAlerts += 1 }
        }
        XCTAssertGreaterThanOrEqual(secondAlerts, 1, "冷却结束后若仍持续低头应再次提醒")

        // 抬头回正至 5°（相对 0°）稳定 3 秒 -> 低头计时归零，恢复 upright
        var lastOut: HeadPostureStepOutput?
        for _ in 0..<10 {
            t += 0.3
            lastOut = engine.step(downwardPitchDeg: 5.0, timestamp: t)
        }
        XCTAssertEqual(lastOut?.alertLevel, .upright)
        XCTAssertEqual(engine.continuousHeadDownSec, 0, accuracy: 0.001)
    }

    func testHeadGestureDetectorDistinguishesNodAndShakeAndAvoidsSingleTilt() {
        let detector = HeadGestureDetector()

        // 1. 单个轻微抬头不应触发
        for i in 0..<25 {
            let t = Double(i) * 0.02
            let g = detector.ingest(timestamp: t, pitchRateX: 0.6 * sin(4 * t), yawRateY: 0.05)
            XCTAssertNil(g)
        }

        // 2. 明显快速点头 2 下（X 轴高能量正负多次反转，Y 轴平稳）
        detector.reset()
        var nodDetected = false
        for i in 0..<60 {
            let t = 10.0 + Double(i) * 0.02
            let rateX = 2.6 * sin(2.0 * .pi * 2.2 * Double(i) * 0.02)
            if let g = detector.ingest(timestamp: t, pitchRateX: rateX, yawRateY: 0.1) {
                XCTAssertEqual(g, .nod)
                nodDetected = true
            }
        }
        XCTAssertTrue(nodDetected, "明显双击点头应识别为 .nod")

        // 3. 明显快速摇头 2 下（Y 轴高能量正负多次反转，X 轴平稳）
        detector.reset()
        var shakeDetected = false
        for i in 0..<60 {
            let t = 20.0 + Double(i) * 0.02
            let rateY = 2.8 * sin(2.0 * .pi * 2.3 * Double(i) * 0.02)
            if let g = detector.ingest(timestamp: t, pitchRateX: 0.08, yawRateY: rateY) {
                XCTAssertEqual(g, .shake)
                shakeDetected = true
            }
        }
        XCTAssertTrue(shakeDetected, "明显双击摇头应识别为 .shake")
    }

    func testHeadphoneCompanionStoreTracksDailyTotalModelBreakdownAndPersists() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = tmpDir.appendingPathComponent("headphone_companion.json")
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        let store = HeadphoneCompanionStore(fileURL: storeURL)
        XCTAssertEqual(store.state.shakeAction, .smartDual, "默认摇头应绑定智能双场景")

        store.addCompanionTime(125, model: .airPodsMax, at: yesterday)
        store.addCompanionTime(95, model: .airPodsPro2, at: now)
        store.addCompanionTime(45, model: .airPodsMax, at: now)
        store.recordHeadDownAlert(at: now)
        store.update { s in
            s.headDownTimeoutSec = 180
            s.shakeAction = .nextTrack
            s.airPodsMaxColor = .blue
        }

        let reloaded = HeadphoneCompanionStore(fileURL: storeURL)
        XCTAssertEqual(reloaded.todaySeconds(now: now), 140, accuracy: 0.1)
        XCTAssertEqual(reloaded.state.totalSeconds, 265, accuracy: 0.1)
        XCTAssertEqual(reloaded.companionSeconds(for: .airPodsMax), 170, accuracy: 0.1)
        XCTAssertEqual(reloaded.companionSeconds(for: .airPodsPro2), 95, accuracy: 0.1)
        XCTAssertEqual(reloaded.todayAlerts(now: now), 1)
        XCTAssertEqual(reloaded.streakDays(now: now), 2)
        XCTAssertEqual(reloaded.recent7Days(now: now).count, 7)
        XCTAssertEqual(reloaded.state.headDownTimeoutSec, 180, accuracy: 0.1)
        XCTAssertEqual(reloaded.state.shakeAction, .nextTrack)
        XCTAssertEqual(reloaded.state.airPodsMaxColor, .blue)
    }

    func testHeadphoneModelDetectionRecognizesAll6SupportedLineups() {
        XCTAssertEqual(HeadphoneModelKind.detect(fromPortName: "YG's AirPods Pro"), .airPodsPro2)
        XCTAssertEqual(HeadphoneModelKind.detect(fromPortName: "AirPods 4 (ANC)"), .airPods4)
        XCTAssertEqual(HeadphoneModelKind.detect(fromPortName: "AirPods Max - Midnight"), .airPodsMax)
        XCTAssertEqual(HeadphoneModelKind.detect(fromPortName: "AirPods (第2代)"), .airPods2)
        XCTAssertEqual(HeadphoneModelKind.detect(fromPortName: "Beats Fit Pro"), .beatsFitPro)
        XCTAssertEqual(HeadphoneModelKind.detect(fromPortName: "Beats Studio Pro"), .beatsStudioPro)
        XCTAssertFalse(HeadphoneModelKind.airPods2.supportsSpatialMotion)
        XCTAssertTrue(HeadphoneModelKind.airPodsPro2.supportsSpatialMotion)
    }
}
