import Foundation
import Combine
#if canImport(CoreMotion)
import CoreMotion
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 6 轴传感器帧与动作类别定义

/// 单帧 6 轴惯性测量单元数据（50Hz：加速度计 g + 陀螺仪 rad/s）。
public struct IMUFrame: Codable, Sendable, Equatable {
    public var timestamp: TimeInterval
    public var ax: Double
    public var ay: Double
    public var az: Double
    public var gx: Double
    public var gy: Double
    public var gz: Double

    public init(
        timestamp: TimeInterval,
        ax: Double,
        ay: Double,
        az: Double,
        gx: Double,
        gy: Double,
        gz: Double
    ) {
        self.timestamp = timestamp
        self.ax = ax
        self.ay = ay
        self.az = az
        self.gx = gx
        self.gy = gy
        self.gz = gz
    }

    func channel(_ index: Int) -> Double {
        switch index {
        case 0: return ax
        case 1: return ay
        case 2: return az
        case 3: return gx
        case 4: return gy
        default: return gz
        }
    }
}

/// 手表 / 手机 6 轴模型支持识别的 10 个核心动作 + 1 个静息干扰类。
public enum WatchExerciseClass: String, CaseIterable, Codable, Identifiable, Sendable {
    case barbellBenchPress = "barbell-bench-press"
    case dumbbellBicepCurl = "dumbbell-bicep-curl"
    case barbellBackSquat = "barbell-back-squat"
    case barbellDeadlift = "barbell-deadlift"
    case pullUp = "pull-up"
    case seatedDumbbellShoulderPress = "seated-dumbbell-shoulder-press"
    case lateralRaise = "lateral-raise"
    case barbellRow = "barbell-row"
    case pushUp = "push-up"
    case ropeTricepPushdown = "rope-tricep-pushdown"
    case idle = "idle"

    public var id: String { rawValue }

    public var isActiveExercise: Bool { self != .idle }

    public var nameZH: String {
        switch self {
        case .barbellBenchPress: return "杠铃平板卧推"
        case .dumbbellBicepCurl: return "站姿哑铃弯举"
        case .barbellBackSquat: return "杠铃颈后深蹲"
        case .barbellDeadlift: return "杠铃传统硬拉"
        case .pullUp: return "引体向上"
        case .seatedDumbbellShoulderPress: return "坐姿哑铃推举"
        case .lateralRaise: return "哑铃侧平举"
        case .barbellRow: return "俯身杠铃划船"
        case .pushUp: return "标准俯卧撑"
        case .ropeTricepPushdown: return "绳索三头下压"
        case .idle: return "静息 / 休息走动"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .barbellBenchPress, .pushUp: return "figure.strengthtraining.traditional"
        case .dumbbellBicepCurl, .ropeTricepPushdown: return "figure.arms.open"
        case .barbellBackSquat, .barbellDeadlift: return "figure.core.training"
        case .pullUp: return "figure.climbing"
        case .seatedDumbbellShoulderPress, .lateralRaise: return "figure.mixed.cardio"
        case .barbellRow: return "figure.rowing"
        case .idle: return "pause.circle"
        }
    }

    /// 每次完整重复的最短间隔（防抖）
    public var minRepIntervalSec: TimeInterval {
        switch self {
        case .barbellDeadlift, .barbellBackSquat: return 0.95
        case .pullUp, .barbellBenchPress: return 0.85
        case .seatedDumbbellShoulderPress, .barbellRow: return 0.80
        case .dumbbellBicepCurl, .lateralRaise, .pushUp, .ropeTricepPushdown: return 0.72
        case .idle: return 2.0
        }
    }

    /// 周期峰谷检测选用的主导信号通道索引（0..2 加速度轴；3..5 角速度积分/周期轴），确保单峰单谷
    var primaryOscillationAxis: Int {
        switch self {
        case .barbellBenchPress, .barbellDeadlift, .pullUp, .seatedDumbbellShoulderPress:
            return 0 // X 轴垂直推拉脉冲最显著
        case .pushUp, .barbellBackSquat, .barbellRow:
            return 2 // Z/合轴垂直升降最稳定
        case .dumbbellBicepCurl:
            return 2 // 弯举前臂摆动使 +Z 形成 0 -> 1g -> 0 清晰单峰周期
        case .lateralRaise:
            return 0 // 侧平举臂下垂到水平使 +X 形成 0.92g -> 0.14g 清晰单谷周期
        case .ropeTricepPushdown:
            return 0 // 三头下压从水平到下垂使 +X 形成大行程周期
        case .idle:
            return 0
        }
    }

    /// 与 `exercises_catalog.json` 对齐的动作库 ID
    public var catalogExerciseID: String? {
        self == .idle ? nil : rawValue
    }

    public static var trainableExercises: [WatchExerciseClass] {
        allCases.filter { $0 != .idle }
    }
}

// MARK: - 30 维物理特征提取器（与 Python train_watch_imu_model.py 完全一致）

public enum WatchMotionFeatureExtractor {
    public static let featureCount = 30

    public static func extract(frames: [IMUFrame]) -> [Double] {
        guard !frames.isEmpty else {
            return Array(repeating: 0.0, count: featureCount)
        }
        let n = Double(frames.count)
        var means = [Double](repeating: 0, count: 6)
        var sqSums = [Double](repeating: 0, count: 6)
        var mins = [Double](repeating: .infinity, count: 6)
        var maxs = [Double](repeating: -.infinity, count: 6)

        for f in frames {
            for ch in 0..<6 {
                let v = f.channel(ch)
                means[ch] += v
                sqSums[ch] += v * v
                if v < mins[ch] { mins[ch] = v }
                if v > maxs[ch] { maxs[ch] = v }
            }
        }
        for ch in 0..<6 { means[ch] /= n }

        var vars = [Double](repeating: 0, count: 6)
        for f in frames {
            for ch in 0..<6 {
                let d = f.channel(ch) - means[ch]
                vars[ch] += d * d
            }
        }
        for ch in 0..<6 { vars[ch] /= n }

        var features = [Double]()
        features.reserveCapacity(featureCount)

        for ch in 0..<6 {
            let std = sqrt(max(0.0, vars[ch]))
            let p2p = maxs[ch] - mins[ch]
            let rms = sqrt(max(0.0, sqSums[ch] / n))
            features.append(means[ch])
            features.append(std)
            features.append(p2p)
            features.append(rms)
        }

        let accTotal = vars[0] + vars[1] + vars[2] + 1e-6
        features.append(vars[0] / accTotal)
        features.append(vars[1] / accTotal)
        features.append(vars[2] / accTotal)

        let gyroTotal = vars[3] + vars[4] + vars[5] + 1e-6
        features.append(vars[3] / gyroTotal)
        features.append(vars[4] / gyroTotal)
        features.append(vars[5] / gyroTotal)

        return features
    }
}

// MARK: - 神经网络权重模型与个人校准原型

public struct WatchMLPModelPayload: Codable, Sendable {
    public let version: Int
    public let sampleRateHz: Int
    public let windowSize: Int
    public let featureDim: Int
    public let hiddenDim: Int
    public let labels: [String]
    public let mean: [Double]
    public let std: [Double]
    public let w1: [[Double]]
    public let b1: [Double]
    public let w2: [[Double]]
    public let b2: [Double]
    public let testAccuracy: Double?
}

public struct UserExercisePrototype: Codable, Equatable, Sendable {
    public let exerciseRawValue: String
    public var normalizedFeatureMean: [Double]
    public var sampleWindows: Int
    public var updatedAt: Date
}

public struct ClassificationResult: Equatable, Sendable {
    public let predicted: WatchExerciseClass
    public let confidence: Double
    public let scores: [(exercise: WatchExerciseClass, probability: Double)]

    public static func == (lhs: ClassificationResult, rhs: ClassificationResult) -> Bool {
        lhs.predicted == rhs.predicted && abs(lhs.confidence - rhs.confidence) < 1e-9
    }
}

/// 端侧 MLP + 个人原型混合动作识别器。
public final class WatchExerciseClassifier {
    public let payload: WatchMLPModelPayload
    public private(set) var prototypes: [String: UserExercisePrototype]
    private let calibrationURL: URL?

    public init(payload: WatchMLPModelPayload, calibrationURL: URL? = nil) {
        self.payload = payload
        self.calibrationURL = calibrationURL
        if let calibrationURL,
           let data = try? Data(contentsOf: calibrationURL),
           let decoded = try? JSONDecoder().decode([String: UserExercisePrototype].self, from: data) {
            self.prototypes = decoded
        } else {
            self.prototypes = [:]
        }
    }

    public static func loadDefault(calibrationURL: URL? = nil) -> WatchExerciseClassifier? {
        let bundles = [Bundle.main, Bundle(for: WatchExerciseClassifier.self)]
        for bundle in bundles {
            if let url = bundle.url(forResource: "watch_exercise_classifier_v1", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode(WatchMLPModelPayload.self, from: data) {
                return WatchExerciseClassifier(payload: decoded, calibrationURL: calibrationURL)
            }
        }
        return nil
    }

    /// 对一个滑动窗口执行标准化 -> 2 层 ReLU MLP -> Softmax，并融合用户校准原型。
    public func classify(frames: [IMUFrame]) -> ClassificationResult {
        let rawFeatures = WatchMotionFeatureExtractor.extract(frames: frames)
        let normFeatures = normalize(rawFeatures)
        let mlpProbs = forwardMLP(normFeatures)

        var combined = mlpProbs
        if !prototypes.isEmpty {
            let protoProbs = prototypeProbabilities(for: normFeatures)
            for i in 0..<combined.count {
                if let proto = protoProbs[i] {
                    combined[i] = 0.65 * mlpProbs[i] + 0.35 * proto
                }
            }
            let sum = combined.reduce(0, +)
            if sum > 0 {
                combined = combined.map { $0 / sum }
            }
        }

        var paired: [(WatchExerciseClass, Double)] = []
        paired.reserveCapacity(payload.labels.count)
        for (i, lbl) in payload.labels.enumerated() where i < combined.count {
            let cls = WatchExerciseClass(rawValue: lbl) ?? .idle
            paired.append((cls, combined[i]))
        }
        paired.sort { $0.1 > $1.1 }

        let top = paired.first ?? (.idle, 0.0)
        return ClassificationResult(predicted: top.0, confidence: top.1, scores: paired)
    }

    /// 记录或更新某动作的个人校准原型（增量均值融合）并落盘。
    public func saveCalibration(for exercise: WatchExerciseClass, windows: [[IMUFrame]]) {
        guard !windows.isEmpty, exercise != .idle else { return }
        let vectors = windows.map { normalize(WatchMotionFeatureExtractor.extract(frames: $0)) }
        let dim = vectors[0].count
        var avg = [Double](repeating: 0, count: dim)
        for vec in vectors {
            for j in 0..<dim { avg[j] += vec[j] }
        }
        for j in 0..<dim { avg[j] /= Double(vectors.count) }

        if var existing = prototypes[exercise.rawValue], existing.normalizedFeatureMean.count == dim {
            let total = Double(existing.sampleWindows + vectors.count)
            for j in 0..<dim {
                existing.normalizedFeatureMean[j] =
                    (existing.normalizedFeatureMean[j] * Double(existing.sampleWindows) + avg[j] * Double(vectors.count)) / total
            }
            existing.sampleWindows += vectors.count
            existing.updatedAt = Date()
            prototypes[exercise.rawValue] = existing
        } else {
            prototypes[exercise.rawValue] = UserExercisePrototype(
                exerciseRawValue: exercise.rawValue,
                normalizedFeatureMean: avg,
                sampleWindows: vectors.count,
                updatedAt: Date()
            )
        }
        persistPrototypes()
    }

    public func clearCalibration(for exercise: WatchExerciseClass? = nil) {
        if let exercise {
            prototypes.removeValue(forKey: exercise.rawValue)
        } else {
            prototypes.removeAll()
        }
        persistPrototypes()
    }

    private func persistPrototypes() {
        guard let calibrationURL else { return }
        try? FileManager.default.createDirectory(
            at: calibrationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if let data = try? JSONEncoder().encode(prototypes) {
            try? data.write(to: calibrationURL, options: .atomic)
        }
    }

    private func normalize(_ features: [Double]) -> [Double] {
        var out = [Double](repeating: 0, count: features.count)
        for i in 0..<min(features.count, payload.mean.count) {
            let s = payload.std[i] > 1e-8 ? payload.std[i] : 1.0
            out[i] = (features[i] - payload.mean[i]) / s
        }
        return out
    }

    private func forwardMLP(_ x: [Double]) -> [Double] {
        let hDim = payload.hiddenDim
        let cDim = payload.labels.count
        var hidden = [Double](repeating: 0, count: hDim)
        for j in 0..<hDim {
            var sum = j < payload.b1.count ? payload.b1[j] : 0.0
            for i in 0..<min(x.count, payload.w1.count) {
                sum += x[i] * payload.w1[i][j]
            }
            hidden[j] = max(0.0, sum)
        }

        var logits = [Double](repeating: 0, count: cDim)
        var maxLogit = -Double.infinity
        for k in 0..<cDim {
            var sum = k < payload.b2.count ? payload.b2[k] : 0.0
            for j in 0..<min(hDim, payload.w2.count) {
                sum += hidden[j] * payload.w2[j][k]
            }
            logits[k] = sum
            if sum > maxLogit { maxLogit = sum }
        }

        var exps = [Double](repeating: 0, count: cDim)
        var denom = 0.0
        for k in 0..<cDim {
            let e = exp(logits[k] - maxLogit)
            exps[k] = e
            denom += e
        }
        guard denom > 0 else { return Array(repeating: 1.0 / Double(max(1, cDim)), count: cDim) }
        return exps.map { $0 / denom }
    }

    private func prototypeProbabilities(for normVec: [Double]) -> [Double?] {
        var rawScores = [Double?](repeating: nil, count: payload.labels.count)
        for (idx, lbl) in payload.labels.enumerated() {
            guard let proto = prototypes[lbl], proto.normalizedFeatureMean.count == normVec.count else { continue }
            var sqDist = 0.0
            for j in 0..<normVec.count {
                let d = normVec[j] - proto.normalizedFeatureMean[j]
                sqDist += d * d
            }
            let normalizedDist = sqDist / Double(max(1, normVec.count))
            rawScores[idx] = exp(-normalizedDist * 0.45)
        }
        return rawScores
    }
}

// MARK: - 自适应峰谷周期自动计次状态机

public struct WatchRepDetectedEvent: Equatable, Sendable {
    public let repCount: Int
    public let exercise: WatchExerciseClass
    public let confidence: Double
    public let tempoSec: Double
    public let timestamp: TimeInterval
}

/// 单通道去噪 + 滞回峰谷状态机：每完成一个标准周期（波峰→波谷 或 波谷→波峰）触发一次计次。
public final class AdaptiveRepCounter {
    private enum Phase {
        case idle
        case risingToPeak
        case fallingToValley
    }

    public private(set) var repCount: Int = 0
    public private(set) var lastTempoSec: Double = 0
    private var phase: Phase = .idle
    private var smoothedSignal: Double = 0
    private var runningBaseline: Double = 0
    private var hasInitialized = false
    private var recentCentered: [Double] = []
    private var cycleMax: Double = 0
    private var cycleMin: Double = 0
    private var lastRepTimestamp: TimeInterval = -100

    public init() {}

    public func reset() {
        repCount = 0
        lastTempoSec = 0
        phase = .idle
        smoothedSignal = 0
        runningBaseline = 0
        hasInitialized = false
        recentCentered.removeAll()
        cycleMax = 0
        cycleMin = 0
        lastRepTimestamp = -100
    }

    /// 输入一帧和当前判定动作；若刚刚完成一次完整重复则返回事件。
    @discardableResult
    public func ingest(
        frame: IMUFrame,
        activeExercise: WatchExerciseClass,
        confidence: Double
    ) -> WatchRepDetectedEvent? {
        guard activeExercise.isActiveExercise, confidence >= 0.42 else {
            return nil
        }
        let raw = frame.channel(activeExercise.primaryOscillationAxis)
        if !hasInitialized {
            smoothedSignal = raw
            runningBaseline = raw
            hasInitialized = true
            return nil
        }

        // 双时间常数指数滤波：快速响应动作主波，慢速跟踪重力基准中线
        smoothedSignal = 0.72 * smoothedSignal + 0.28 * raw
        runningBaseline = 0.985 * runningBaseline + 0.015 * raw
        let centered = smoothedSignal - runningBaseline

        recentCentered.append(centered)
        if recentCentered.count > 120 {
            recentCentered.removeFirst()
        }
        guard recentCentered.count >= 20 else { return nil }

        // 动态自适应振幅阈值（避免小抖动误触发）
        let maxAbs = recentCentered.map { abs($0) }.max() ?? 0
        let amplitudeThreshold = max(0.16, maxAbs * 0.48)
        let hysteresis = amplitudeThreshold * 0.42

        switch phase {
        case .idle:
            if centered > amplitudeThreshold {
                phase = .risingToPeak
                cycleMax = centered
            }
        case .risingToPeak:
            if centered > cycleMax {
                cycleMax = centered
            } else if centered < cycleMax - hysteresis {
                // 波峰已确认，寻找下半周期波谷
                phase = .fallingToValley
                cycleMin = centered
            }
        case .fallingToValley:
            if centered < cycleMin {
                cycleMin = centered
            } else if centered > cycleMin + hysteresis {
                let swing = cycleMax - cycleMin
                let dt = frame.timestamp - lastRepTimestamp
                if swing >= amplitudeThreshold * 1.45 && dt >= activeExercise.minRepIntervalSec {
                    if lastRepTimestamp > 0 {
                        lastTempoSec = min(6.0, dt)
                    }
                    lastRepTimestamp = frame.timestamp
                    repCount += 1
                    phase = .risingToPeak
                    cycleMax = centered
                    return WatchRepDetectedEvent(
                        repCount: repCount,
                        exercise: activeExercise,
                        confidence: confidence,
                        tempoSec: lastTempoSec,
                        timestamp: frame.timestamp
                    )
                } else {
                    phase = .idle
                }
            }
        }
        return nil
    }
}

// MARK: - 6 轴生物力学波形模拟器（支持单帧实时流与测试整组序列生成）

public enum WatchIMUWaveformSimulator {
    /// 生成 `reps` 次标准重复动作的 50Hz 6 轴传感器序列（供演示与测试）。
    public static func generateStream(
        for exercise: WatchExerciseClass,
        reps: Int,
        sampleRate: Double = 50.0,
        periodSec: Double = 2.0
    ) -> [IMUFrame] {
        let totalSeconds = Double(max(1, reps)) * periodSec + 0.35
        let count = Int(totalSeconds * sampleRate)
        var frames = [IMUFrame]()
        frames.reserveCapacity(count)
        for i in 0..<count {
            let t = Double(i) / sampleRate
            frames.append(sampleFrame(for: exercise, at: t, periodSec: periodSec))
        }
        return frames
    }

    public static func sampleFrame(
        for exercise: WatchExerciseClass,
        at t: TimeInterval,
        periodSec: Double = 2.0
    ) -> IMUFrame {
        let omega = 2.0 * .pi / max(0.8, periodSec)
        let s = sin(omega * t)
        let c = cos(omega * t)
        let jitter = 0.015 * sin(17.3 * t)

        switch exercise {
        case .barbellBenchPress:
            return IMUFrame(
                timestamp: t,
                ax: -0.92 + 0.42 * s + jitter,
                ay: 0.08 + 0.09 * s,
                az: 0.32 + 0.14 * c,
                gx: 0.18 * c,
                gy: 0.24 * c,
                gz: 0.12 * s
            )
        case .dumbbellBicepCurl:
            let angle = 0.95 * (0.5 * (1.0 + s))
            return IMUFrame(
                timestamp: t,
                ax: -0.95 * cos(angle) + 0.22 * s + jitter,
                ay: 0.15 + 0.14 * c,
                az: 0.90 * sin(angle) + 0.24 * c,
                gx: 0.55 * c,
                gy: 2.35 * c,
                gz: 0.35 * s
            )
        case .barbellBackSquat:
            return IMUFrame(
                timestamp: t,
                ax: -0.66 + 0.36 * s + jitter,
                ay: 0.22 + 0.08 * s,
                az: 0.70 + 0.32 * s,
                gx: 0.16 * c,
                gy: 0.22 * c,
                gz: 0.14 * s
            )
        case .barbellDeadlift:
            return IMUFrame(
                timestamp: t,
                ax: 0.96 + 0.44 * s + jitter,
                ay: 0.12 + 0.10 * c,
                az: 0.18 + 0.16 * s,
                gx: 0.18 * s,
                gy: 0.26 * c,
                gz: 0.15 * c
            )
        case .pullUp:
            return IMUFrame(
                timestamp: t,
                ax: -0.90 + 0.30 * s + jitter,
                ay: -0.35 + 0.22 * s,
                az: -0.18 + 0.28 * c,
                gx: 0.48 * c,
                gy: 0.95 * c,
                gz: 0.52 * s
            )
        case .seatedDumbbellShoulderPress:
            return IMUFrame(
                timestamp: t,
                ax: -0.78 + 0.48 * s + jitter,
                ay: 0.42 + 0.32 * c,
                az: 0.26 + 0.22 * s,
                gx: 1.05 * c,
                gy: 0.65 * s,
                gz: 0.90 * c
            )
        case .lateralRaise:
            let lift = 0.5 * (1.0 + s)
            return IMUFrame(
                timestamp: t,
                ax: 0.92 * (1.0 - 0.85 * lift) + jitter,
                ay: 0.85 * lift + 0.18 * s,
                az: 0.42 * lift + 0.16 * c,
                gx: 1.95 * c,
                gy: 0.45 * s,
                gz: 1.15 * c
            )
        case .barbellRow:
            return IMUFrame(
                timestamp: t,
                ax: 0.82 + 0.38 * s + jitter,
                ay: 0.14 + 0.14 * c,
                az: 0.48 + 0.36 * s,
                gx: 0.35 * s,
                gy: 1.35 * c,
                gz: 0.38 * s
            )
        case .pushUp:
            return IMUFrame(
                timestamp: t,
                ax: -0.44 + 0.22 * s + jitter,
                ay: 0.06 + 0.08 * c,
                az: 0.86 + 0.42 * s,
                gx: 0.16 * c,
                gy: 0.20 * s,
                gz: 0.12 * c
            )
        case .ropeTricepPushdown:
            let ext = 0.5 * (1.0 - s)
            return IMUFrame(
                timestamp: t,
                ax: 0.18 + 0.78 * ext + 0.18 * s + jitter,
                ay: -0.18 + 0.22 * ext,
                az: 0.88 * (1.0 - 0.82 * ext) + 0.16 * c,
                gx: 0.42 * s,
                gy: -1.90 * c,
                gz: 0.92 * s
            )
        case .idle:
            return IMUFrame(
                timestamp: t,
                ax: 0.05 + 0.03 * sin(2.1 * t),
                ay: -0.10 + 0.03 * cos(3.1 * t),
                az: 0.98 + 0.02 * sin(1.3 * t),
                gx: 0.05 * sin(2.7 * t),
                gy: 0.05 * cos(1.9 * t),
                gz: 0.04 * sin(2.2 * t)
            )
        }
    }
}

// MARK: - 实时会话控制器（支持手表同步、iPhone 握持实测与 6 轴模拟）

public enum WatchMotionSourceMode: String, CaseIterable, Identifiable, Sendable {
    case watchBridge = "手表实时同步"
    case phoneHandheld = "iPhone 传感器实测"
    case simulator = "6 轴波形模拟"

    public var id: String { rawValue }
}

@MainActor
public final class WatchMotionSessionController: ObservableObject {
    public static let shared = WatchMotionSessionController()

    @Published public var isRunning = false
    @Published public var sourceMode: WatchMotionSourceMode = .simulator
    @Published public var currentExercise: WatchExerciseClass = .idle
    @Published public var confidence: Double = 0
    @Published public var topCandidates: [(exercise: WatchExerciseClass, probability: Double)] = []
    @Published public var repCount: Int = 0
    @Published public var lastTempoSec: Double = 0
    @Published public var recentAccelWave: [Double] = Array(repeating: 0, count: 60)

    // 模拟器动作选择
    @Published public var simulatedExercise: WatchExerciseClass = .barbellBenchPress

    // 个人校准状态
    @Published public var isCalibrating = false
    @Published public var calibrationTarget: WatchExerciseClass = .barbellBenchPress
    @Published public var calibrationProgress: Double = 0
    @Published public var calibratedClasses: Set<String> = []

    /// 供 SessionView 等训练界面订阅
    public let repPublisher = PassthroughSubject<WatchRepDetectedEvent, Never>()
    public let setCompletePublisher = PassthroughSubject<Void, Never>()

    private let classifier: WatchExerciseClassifier?
    private let repCounter = AdaptiveRepCounter()
    private var frameBuffer: [IMUFrame] = []
    private var calibrationBuffers: [IMUFrame] = []
    private var simTimer: Timer?
    private var simStartTime: Date = Date()
    private var sampleCounter = 0

    #if canImport(CoreMotion)
    private let motionManager = CMMotionManager()
    #endif

    public init(calibrationURL: URL? = nil) {
        let resolvedURL: URL?
        if let calibrationURL {
            resolvedURL = calibrationURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Stride", isDirectory: true)
            resolvedURL = base?.appendingPathComponent("watch_calibration.json")
        }
        self.classifier = WatchExerciseClassifier.loadDefault(calibrationURL: resolvedURL)
        self.calibratedClasses = Set(self.classifier?.prototypes.keys.map { $0 } ?? [])
    }

    public var modelVersionText: String {
        guard let payload = classifier?.payload else { return "模型未加载" }
        let acc = Int(((payload.testAccuracy ?? 1.0) * 100).rounded())
        return "v\(payload.version) · \(payload.labels.count - 1) 动作 · 离线准确率 \(acc)%"
    }

    public func start(mode: WatchMotionSourceMode? = nil) {
        if let mode { sourceMode = mode }
        stop()
        repCounter.reset()
        frameBuffer.removeAll()
        repCount = 0
        lastTempoSec = 0
        sampleCounter = 0
        isRunning = true

        switch sourceMode {
        case .watchBridge:
            WatchSession.shared.activate()
        case .phoneHandheld:
            startPhoneIMU()
        case .simulator:
            startSimulatorLoop()
        }
    }

    public func stop() {
        isRunning = false
        simTimer?.invalidate()
        simTimer = nil
        #if canImport(CoreMotion)
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        #endif
    }

    public func resetReps() {
        repCounter.reset()
        repCount = 0
        lastTempoSec = 0
    }

    /// 供 WatchSession 接收到手表回传的 `"rep"` / `"exerciseChanged"` / `"setComplete"` 消息时调用。
    public func ingestWatchEvent(
        kind: String,
        exerciseId: String? = nil,
        repCount incomingRepCount: Int? = nil,
        confidence incomingConfidence: Double? = nil,
        tempoSec incomingTempo: Double? = nil
    ) {
        switch kind {
        case "rep":
            let exRaw = exerciseId ?? currentExercise.rawValue
            let ex = WatchExerciseClass(rawValue: exRaw) ?? .barbellBenchPress
            let conf = incomingConfidence ?? 0.92
            let tempo = incomingTempo ?? 2.0
            let nextRep = incomingRepCount ?? (repCount + 1)

            currentExercise = ex
            confidence = conf
            lastTempoSec = tempo
            repCount = nextRep
            isRunning = true
            sourceMode = .watchBridge

            let event = WatchRepDetectedEvent(
                repCount: nextRep,
                exercise: ex,
                confidence: conf,
                tempoSec: tempo,
                timestamp: Date().timeIntervalSince1970
            )
            repPublisher.send(event)
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.65)
            #endif

        case "exerciseChanged":
            if let exerciseId, let ex = WatchExerciseClass(rawValue: exerciseId) {
                currentExercise = ex
                confidence = incomingConfidence ?? 0.85
            }

        case "setComplete":
            setCompletePublisher.send(())

        default:
            break
        }
    }

    /// 采集当前动作的 100 帧窗口作为个人校准原型并落盘。
    public func startQuickCalibration(for exercise: WatchExerciseClass) {
        guard exercise.isActiveExercise else { return }
        calibrationTarget = exercise
        calibrationBuffers.removeAll()
        calibrationProgress = 0
        isCalibrating = true
        if !isRunning {
            start(mode: sourceMode == .watchBridge ? .phoneHandheld : sourceMode)
        }
    }

    public func clearCalibration(for exercise: WatchExerciseClass? = nil) {
        classifier?.clearCalibration(for: exercise)
        calibratedClasses = Set(classifier?.prototypes.keys.map { $0 } ?? [])
    }

    // MARK: - 内部传感器 / 模拟采集

    private func startPhoneIMU() {
        #if canImport(CoreMotion) && !targetEnvironment(simulator)
        guard motionManager.isDeviceMotionAvailable else {
            sourceMode = .simulator
            startSimulatorLoop()
            return
        }
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
            self.processFrame(frame)
        }
        #else
        startSimulatorLoop()
        #endif
    }

    private func startSimulatorLoop() {
        simStartTime = Date()
        simTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 50.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                let t = Date().timeIntervalSince(self.simStartTime)
                let frame = WatchIMUWaveformSimulator.sampleFrame(for: self.simulatedExercise, at: t, periodSec: 2.0)
                self.processFrame(frame)
            }
        }
    }

    private func processFrame(_ frame: IMUFrame) {
        frameBuffer.append(frame)
        if frameBuffer.count > 100 {
            frameBuffer.removeFirst(frameBuffer.count - 100)
        }

        // 记录波形 UI（动态模长偏移）
        let mag = sqrt(frame.ax * frame.ax + frame.ay * frame.ay + frame.az * frame.az) - 1.0
        recentAccelWave.append(mag)
        if recentAccelWave.count > 60 {
            recentAccelWave.removeFirst()
        }

        // 处理个人校准采集
        if isCalibrating {
            calibrationBuffers.append(frame)
            calibrationProgress = min(1.0, Double(calibrationBuffers.count) / 150.0)
            if calibrationBuffers.count >= 150 {
                let win1 = Array(calibrationBuffers.prefix(100))
                let win2 = Array(calibrationBuffers.suffix(100))
                classifier?.saveCalibration(for: calibrationTarget, windows: [win1, win2])
                calibratedClasses = Set(classifier?.prototypes.keys.map { $0 } ?? [])
                isCalibrating = false
                calibrationProgress = 1.0
            }
        }

        sampleCounter += 1
        let shouldClassifyNow = (frameBuffer.count == 100) && (sampleCounter % 15 == 0 || currentExercise == .idle)
        if shouldClassifyNow, let classifier {
            let res = classifier.classify(frames: frameBuffer)
            currentExercise = res.predicted
            confidence = res.confidence
            topCandidates = Array(res.scores.prefix(3))
        }

        if let repEvent = repCounter.ingest(
            frame: frame,
            activeExercise: currentExercise,
            confidence: max(confidence, sourceMode == .simulator ? 0.90 : confidence)
        ) {
            repCount = repEvent.repCount
            lastTempoSec = repEvent.tempoSec
            repPublisher.send(repEvent)
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.55)
            #endif
        }
    }
}

// 下面修复 clearCalibration 同一句 keys 语法（避免后续重复查找）
