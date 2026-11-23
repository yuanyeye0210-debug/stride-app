import Foundation
import Combine
import CoreMotion
import HealthKit
import WatchConnectivity
import WatchKit

/// Apple Watch 端 6 轴传感器动作识别与自动计次管理器。
/// 通过共享的 `WatchMotionEngine` 完成推理与周期计次，并经由 `WCSession` 实时回传至 iPhone。
@MainActor
final class WatchWorkoutMotionManager: NSObject, ObservableObject {
    static let shared = WatchWorkoutMotionManager()

    @Published var isRunning = false
    @Published var currentExercise: WatchExerciseClass = .idle
    @Published var confidence: Double = 0
    @Published var repCount: Int = 0
    @Published var activeWorkoutTitle: String = "自由力量训练"
    @Published var setProgressText: String = "进行中"
    @Published var restSecondsLeft: Int = 0
    @Published var phoneConnected = false

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private let motionManager = CMMotionManager()
    private let classifier = WatchExerciseClassifier.loadDefault()
    private let counter = AdaptiveRepCounter()

    private var windowBuffer: [IMUFrame] = []
    private var frameIndex = 0
    private var lastDispatchedExercise: WatchExerciseClass = .idle

    override private init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func startTraining() {
        stopTraining()
        counter.reset()
        windowBuffer.removeAll()
        frameIndex = 0
        repCount = 0
        isRunning = true

        startHealthWorkoutSession()
        startIMUUpdates()
    }

    func stopTraining() {
        isRunning = false
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        workoutSession?.end()
        workoutSession = nil
    }

    func completeCurrentSet() {
        sendToPhone(["kind": "setComplete", "repCount": repCount, "at": Date().timeIntervalSince1970])
        WKInterfaceDevice.current().play(.success)
        counter.reset()
        repCount = 0
    }

    private func startHealthWorkoutSession() {
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor
        guard let session = try? HKWorkoutSession(healthStore: healthStore, configuration: config) else {
            return
        }
        workoutSession = session
        session.startActivity(with: Date())
    }

    private func startIMUUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let frame = IMUFrame(
                timestamp: motion.timestamp,
                ax: motion.gravity.x + motion.userAcceleration.x,
                ay: motion.gravity.y + motion.userAcceleration.y,
                az: motion.gravity.z + motion.userAcceleration.z,
                gx: motion.rotationRate.x,
                gy: motion.rotationRate.y,
                gz: motion.rotationRate.z
            )
            self.process(frame: frame)
        }
    }

    private func process(frame: IMUFrame) {
        windowBuffer.append(frame)
        if windowBuffer.count > 100 {
            windowBuffer.removeFirst(windowBuffer.count - 100)
        }

        frameIndex += 1
        if windowBuffer.count == 100 && (frameIndex % 15 == 0 || currentExercise == .idle),
           let classifier {
            let result = classifier.classify(frames: windowBuffer)
            currentExercise = result.predicted
            confidence = result.confidence
            if result.predicted != lastDispatchedExercise {
                lastDispatchedExercise = result.predicted
                sendToPhone([
                    "kind": "exerciseChanged",
                    "exerciseId": result.predicted.rawValue,
                    "confidence": result.confidence
                ])
            }
        }

        if let repEvent = counter.ingest(
            frame: frame,
            activeExercise: currentExercise,
            confidence: confidence
        ) {
            repCount = repEvent.repCount
            WKInterfaceDevice.current().play(.click)
            sendToPhone([
                "kind": "rep",
                "exerciseId": repEvent.exercise.rawValue,
                "repCount": repEvent.repCount,
                "confidence": repEvent.confidence,
                "tempoSec": repEvent.tempoSec
            ])
        }
    }

    private func sendToPhone(_ payload: [String: Any]) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            try? WCSession.default.updateApplicationContext(payload)
        }
    }
}

extension WatchWorkoutMotionManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let reachable = session.isReachable
        Task { @MainActor in self.phoneConnected = reachable }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.phoneConnected = reachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncoming(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleIncoming(applicationContext)
    }

    nonisolated private func handleIncoming(_ payload: [String: Any]) {
        let kind = payload["kind"] as? String ?? ""
        let title = payload["title"] as? String
        let setIndex = payload["setIndex"] as? Int
        let totalSets = payload["totalSets"] as? Int
        let seconds = payload["seconds"] as? Int
        Task { @MainActor in
            switch kind {
            case "workout":
                if let title { self.activeWorkoutTitle = title }
                if let setIndex, let totalSets {
                    self.setProgressText = "第 \(setIndex)/\(totalSets) 组"
                }
            case "restStart":
                self.restSecondsLeft = seconds ?? 90
                WKInterfaceDevice.current().play(.notification)
            case "restEnd":
                self.restSecondsLeft = 0
            default:
                break
            }
        }
    }
}
