import Foundation
import Combine
import AVFoundation
import UserNotifications
#if canImport(CoreMotion)
import CoreMotion
#endif
#if canImport(UIKit)
import UIKit
#endif

extension Notification.Name {
    static let strideMusicNextTrack = Notification.Name("stride.music.nextTrack")
}

// MARK: - 耳机型号与配色定义

public enum HeadphoneModelKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case airPodsPro2 = "airpods_pro_2"
    case airPods4 = "airpods_4"
    case airPods2 = "airpods_2"
    case airPodsMax = "airpods_max"
    case beatsFitPro = "beats_fit_pro"
    case beatsStudioPro = "beats_studio_pro"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .airPodsPro2: return "AirPods Pro 2"
        case .airPods4: return "AirPods 4 / 3"
        case .airPods2: return "AirPods 2"
        case .airPodsMax: return "AirPods Max"
        case .beatsFitPro: return "Beats Fit Pro"
        case .beatsStudioPro: return "Beats Studio Pro"
        }
    }

    public var shortTag: String {
        switch self {
        case .airPodsPro2: return "Pro 2"
        case .airPods4: return "AirPods 4"
        case .airPods2: return "AirPods 2"
        case .airPodsMax: return "Max"
        case .beatsFitPro: return "Fit Pro"
        case .beatsStudioPro: return "Studio Pro"
        }
    }

    public var subtitleZH: String {
        switch self {
        case .airPodsPro2: return "主动降噪入耳 · 支持头部空间追踪"
        case .airPods4: return "半入耳贴合 · 支持头部空间追踪"
        case .airPods2: return "经典长柄入耳 · 支持陪伴时长统计"
        case .airPodsMax: return "阳极氧化铝头戴 · 支持头部空间追踪"
        case .beatsFitPro: return "运动耳翼防掉 · 支持头部空间追踪"
        case .beatsStudioPro: return "头戴无线降噪 · 支持头部空间追踪"
        }
    }

    public var supportsSpatialMotion: Bool {
        self != .airPods2
    }

    /// 根据蓝牙音频路由名称自动匹配最接近的耳机型号。
    public static func detect(fromPortName portName: String) -> HeadphoneModelKind? {
        let lower = portName.lowercased()
        if lower.contains("airpods max") { return .airPodsMax }
        if lower.contains("airpods pro") { return .airPodsPro2 }
        if lower.contains("airpods 4") || lower.contains("airpods (3") || lower.contains("airpods 3") { return .airPods4 }
        if lower.contains("airpods 2") || lower.contains("airpods") { return .airPods2 }
        if lower.contains("beats fit pro") { return .beatsFitPro }
        if lower.contains("beats studio") { return .beatsStudioPro }
        if lower.contains("beats") || lower.contains("powerbeats") { return .beatsFitPro }
        return nil
    }
}

public enum AirPodsMaxColor: String, CaseIterable, Codable, Identifiable, Sendable {
    case midnight
    case starlight
    case blue
    case purple
    case orange

    public var id: String { rawValue }

    public var nameZH: String {
        switch self {
        case .midnight: return "午夜色"
        case .starlight: return "星光色"
        case .blue: return "蓝色"
        case .purple: return "紫色"
        case .orange: return "橙色"
        }
    }

    public var rgb: (r: Double, g: Double, b: Double) {
        switch self {
        case .midnight: return (0.14, 0.16, 0.21)
        case .starlight: return (0.86, 0.83, 0.78)
        case .blue: return (0.31, 0.45, 0.58)
        case .purple: return (0.56, 0.50, 0.68)
        case .orange: return (0.88, 0.47, 0.30)
        }
    }
}

// MARK: - 摇头手势推荐功能配置

public enum HeadphoneShakeAction: String, CaseIterable, Codable, Identifiable, Sendable {
    case smartDual = "smart_dual"
    case nextTrack = "next_track"
    case voiceFormCue = "voice_form_cue"
    case deloadNextSet = "deload_next_set"

    public var id: String { rawValue }

    public var titleZH: String {
        switch self {
        case .smartDual: return "智能双场景（推荐）"
        case .nextTrack: return "切下一首音乐"
        case .voiceFormCue: return "语音播报动作要领"
        case .deloadNextSet: return "下组自动减重 10%"
        }
    }

    public var detailZH: String {
        switch self {
        case .smartDual: return "休息倒计时中摇头=跳过休息立即开下一组；训练中摇头=撤销刚误记的一组"
        case .nextTrack: return "双手推举或硬拉不便摸手机时，轻摇两下头切换下一首训练节奏音乐"
        case .voiceFormCue: return "耳机轻声播报当前动作核心发力要点与呼吸节奏"
        case .deloadNextSet: return "觉得力竭时摇头，自动把下一组推荐重量降低 10%"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .smartDual: return "sparkles"
        case .nextTrack: return "forward.end.fill"
        case .voiceFormCue: return "waveform.and.mic"
        case .deloadNextSet: return "arrow.down.circle.fill"
        }
    }
}

public enum HeadphoneGestureEvent: Equatable, Sendable {
    case nodCompleteSet
    case shake(HeadphoneShakeAction)
}

// MARK: - 纯逻辑可测试内核：低头姿势监测引擎

public enum HeadPostureAlertLevel: String, Sendable {
    case upright
    case warningHeadDown
    case timeoutAlerted

    public var labelZH: String {
        switch self {
        case .upright: return "颈椎中立良好"
        case .warningHeadDown: return "低头计时中"
        case .timeoutAlerted: return "低头超时 · 请抬头"
        }
    }
}

public struct HeadPostureStepOutput: Equatable, Sendable {
    public let relativeDownwardDeg: Double
    public let continuousHeadDownSec: TimeInterval
    public let alertLevel: HeadPostureAlertLevel
    public let shouldTriggerAlert: Bool
}

/// 根据头部相对俯仰角累计连续低头时间，超过阈值则产出提醒并防抖冷却。
public final class HeadPostureEngine {
    public var baselinePitchDeg: Double = 0
    public var angleThresholdDeg: Double = 20.0
    public var timeoutSeconds: TimeInterval = 60.0
    public var cooldownSeconds: TimeInterval = 30.0

    public private(set) var smoothedRelativeDownwardDeg: Double = 0
    public private(set) var continuousHeadDownSec: TimeInterval = 0
    private var lastAlertTime: TimeInterval = -1000
    private var lastTimestamp: TimeInterval?

    public init(
        angleThresholdDeg: Double = 20.0,
        timeoutSeconds: TimeInterval = 60.0,
        cooldownSeconds: TimeInterval = 30.0
    ) {
        self.angleThresholdDeg = angleThresholdDeg
        self.timeoutSeconds = timeoutSeconds
        self.cooldownSeconds = cooldownSeconds
    }

    public func calibrate(currentDownwardPitchDeg: Double) {
        baselinePitchDeg = currentDownwardPitchDeg
        smoothedRelativeDownwardDeg = 0
        continuousHeadDownSec = 0
    }

    public func resetTimer() {
        continuousHeadDownSec = 0
        smoothedRelativeDownwardDeg = 0
        lastTimestamp = nil
    }

    /// `downwardPitchDeg` 越大代表越低头（正值低头、负值抬头）。
    @discardableResult
    public func step(downwardPitchDeg: Double, timestamp: TimeInterval) -> HeadPostureStepOutput {
        let dt: TimeInterval
        if let lastTimestamp {
            dt = max(0.0, min(2.0, timestamp - lastTimestamp))
        } else {
            dt = 0.0
        }
        lastTimestamp = timestamp

        let relative = downwardPitchDeg - baselinePitchDeg
        smoothedRelativeDownwardDeg = 0.72 * smoothedRelativeDownwardDeg + 0.28 * relative

        var shouldAlert = false
        let level: HeadPostureAlertLevel

        if smoothedRelativeDownwardDeg >= angleThresholdDeg {
            continuousHeadDownSec += dt
            if continuousHeadDownSec >= timeoutSeconds {
                level = .timeoutAlerted
                if timestamp - lastAlertTime >= cooldownSeconds {
                    lastAlertTime = timestamp
                    shouldAlert = true
                }
            } else {
                level = .warningHeadDown
            }
        } else {
            // 留 2° 滞回区间防止边缘闪烁，抬头低于 (阈值 - 2°) 时归零计时
            if smoothedRelativeDownwardDeg < max(4.0, angleThresholdDeg - 2.0) {
                continuousHeadDownSec = 0
            }
            level = .upright
        }

        return HeadPostureStepOutput(
            relativeDownwardDeg: smoothedRelativeDownwardDeg,
            continuousHeadDownSec: continuousHeadDownSec,
            alertLevel: level,
            shouldTriggerAlert: shouldAlert
        )
    }
}

// MARK: - 纯逻辑可测试内核：点头 / 摇头双峰防误触检测器

public enum RawHeadGesture: Equatable, Sendable {
    case nod
    case shake
}

/// 基于陀螺仪角速度过零双峰检测点头（X 轴往返 >= 3 次极值切换）与摇头（Y 轴往返 >= 3 次极值切换）。
public final class HeadGestureDetector {
    private struct Sample {
        let t: TimeInterval
        let pitchRate: Double
        let yawRate: Double
    }

    public var thresholdRadPerSec: Double = 1.25
    public var windowSec: TimeInterval = 1.6
    public var cooldownSec: TimeInterval = 1.8

    private var samples: [Sample] = []
    private var lastTriggerTime: TimeInterval = -100

    public init() {}

    public func reset() {
        samples.removeAll()
        lastTriggerTime = -100
    }

    @discardableResult
    public func ingest(timestamp: TimeInterval, pitchRateX: Double, yawRateY: Double) -> RawHeadGesture? {
        samples.append(Sample(t: timestamp, pitchRate: pitchRateX, yawRate: yawRateY))
        samples.removeAll { timestamp - $0.t > windowSec }

        guard timestamp - lastTriggerTime >= cooldownSec, samples.count >= 8 else {
            return nil
        }

        let pitchEnergy = samples.reduce(0.0) { $0 + abs($1.pitchRate) }
        let yawEnergy = samples.reduce(0.0) { $0 + abs($1.yawRate) }

        let pitchFlips = countAlternatingPeaks(samples.map { $0.pitchRate }, threshold: thresholdRadPerSec)
        let yawFlips = countAlternatingPeaks(samples.map { $0.yawRate }, threshold: thresholdRadPerSec)

        // 严格轴隔离：避免点头伴随的微弱晃动误触发摇头
        if pitchFlips >= 3 && pitchEnergy > yawEnergy * 1.35 {
            lastTriggerTime = timestamp
            samples.removeAll()
            return .nod
        }
        if yawFlips >= 3 && yawEnergy > pitchEnergy * 1.35 {
            lastTriggerTime = timestamp
            samples.removeAll()
            return .shake
        }
        return nil
    }

    private func countAlternatingPeaks(_ values: [Double], threshold: Double) -> Int {
        var lastSign = 0
        var switches = 0
        for v in values {
            if v >= threshold {
                if lastSign != 1 {
                    if lastSign != 0 { switches += 1 }
                    lastSign = 1
                }
            } else if v <= -threshold {
                if lastSign != -1 {
                    if lastSign != 0 { switches += 1 }
                    lastSign = -1
                }
            }
        }
        return switches
    }
}

// MARK: - 耳机陪伴时长与偏好持久化存储

public struct HeadphoneCompanionState: Codable, Equatable, Sendable {
    public var dailySeconds: [String: TimeInterval] = [:]
    public var totalSeconds: TimeInterval = 0
    public var secondsByModel: [String: TimeInterval] = [:]
    public var dailyHeadDownAlerts: [String: Int] = [:]

    public var isPostureMonitorEnabled: Bool = true
    public var headDownAngleThresholdDeg: Double = 20.0
    public var headDownTimeoutSec: TimeInterval = 60.0
    public var voiceReminderEnabled: Bool = true
    public var nodToCompleteSetEnabled: Bool = true
    public var shakeAction: HeadphoneShakeAction = .smartDual
    public var preferredModel: HeadphoneModelKind = .airPodsPro2
    public var airPodsMaxColor: AirPodsMaxColor = .midnight
    public var baselinePitchDeg: Double = 0

    public init() {}
}

public struct DailyCompanionStat: Identifiable, Equatable, Sendable {
    public let dayKey: String
    public let label: String
    public let seconds: TimeInterval
    public var id: String { dayKey }
}

/// 独立持久化每日陪伴时长、总陪伴时长与护颈设置（支持测试注入临时文件）。
public final class HeadphoneCompanionStore {
    public private(set) var state: HeadphoneCompanionState
    private let fileURL: URL
    private let calendar: Calendar

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let shortDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    public init(fileURL: URL? = nil, calendar: Calendar = .current) {
        self.calendar = calendar
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Stride", isDirectory: true)
            self.fileURL = base.appendingPathComponent("headphone_companion.json")
        }

        if let data = try? Data(contentsOf: self.fileURL),
           let decoded = try? JSONDecoder().decode(HeadphoneCompanionState.self, from: data) {
            self.state = decoded
        } else {
            self.state = HeadphoneCompanionState()
        }
    }

    public func dayKey(for date: Date) -> String {
        Self.dayFormatter.string(from: date)
    }

    public func addCompanionTime(_ seconds: TimeInterval, model: HeadphoneModelKind, at date: Date = Date()) {
        guard seconds > 0 else { return }
        let key = dayKey(for: date)
        state.dailySeconds[key, default: 0] += seconds
        state.totalSeconds += seconds
        state.secondsByModel[model.rawValue, default: 0] += seconds
    }

    public func recordHeadDownAlert(at date: Date = Date()) {
        let key = dayKey(for: date)
        state.dailyHeadDownAlerts[key, default: 0] += 1
    }

    public func todaySeconds(now: Date = Date()) -> TimeInterval {
        state.dailySeconds[dayKey(for: now), default: 0]
    }

    public func todayAlerts(now: Date = Date()) -> Int {
        state.dailyHeadDownAlerts[dayKey(for: now), default: 0]
    }

    public func companionSeconds(for model: HeadphoneModelKind) -> TimeInterval {
        state.secondsByModel[model.rawValue, default: 0]
    }

    public func streakDays(now: Date = Date()) -> Int {
        var streak = 0
        var cursor = calendar.startOfDay(for: now)
        while true {
            let key = dayKey(for: cursor)
            if (state.dailySeconds[key] ?? 0) >= 60 {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prev
            } else if streak == 0 && calendar.isDateInToday(cursor) {
                // 今天刚戴上还没满 1 分钟时，允许看昨天是否连续
                guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prev
                if (state.dailySeconds[dayKey(for: cursor)] ?? 0) < 60 { break }
            } else {
                break
            }
        }
        return streak
    }

    public func recent7Days(now: Date = Date()) -> [DailyCompanionStat] {
        var list: [DailyCompanionStat] = []
        let today = calendar.startOfDay(for: now)
        for offset in stride(from: 6, through: 0, by: -1) {
            if let d = calendar.date(byAdding: .day, value: -offset, to: today) {
                let key = dayKey(for: d)
                let label = offset == 0 ? "今天" : Self.shortDayFormatter.string(from: d)
                list.append(DailyCompanionStat(dayKey: key, label: label, seconds: state.dailySeconds[key] ?? 0))
            }
        }
        return list
    }

    public func update(_ mutate: (inout HeadphoneCompanionState) -> Void) {
        mutate(&state)
        save()
    }

    public func save() {
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    public static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return "\(h)小时\(m)分"
        } else if m > 0 {
            return "\(m)分\(s)秒"
        } else {
            return "\(s)秒"
        }
    }
}

// MARK: - 前台通知展示代理

public final class HeadphoneNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = HeadphoneNotificationDelegate()

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}

// MARK: - 主耳机管理器（传感器 + 蓝牙路由 + 陪伴计时 + 手机提醒）

@MainActor
public final class HeadphoneMotionManager: NSObject, ObservableObject {
    public static let shared = HeadphoneMotionManager()

    @Published public var isHeadphoneConnected = false
    @Published public var connectedDeviceName: String = "未连接蓝牙耳机"
    @Published public var activeModel: HeadphoneModelKind = .airPodsPro2
    @Published public var airPodsMaxColor: AirPodsMaxColor = .midnight
    @Published public var isMotionAvailable = false
    @Published public var isMotionTrackingActive = false

    // 实时头部姿态角（度）：正 pitch 表示低头，正 yaw 表示右转，roll 表示侧倾
    @Published public var livePitchDeg: Double = 0
    @Published public var liveYawDeg: Double = 0
    @Published public var liveRollDeg: Double = 0
    @Published public var continuousHeadDownSec: TimeInterval = 0
    @Published public var alertLevel: HeadPostureAlertLevel = .upright
    @Published public var simulatedPitchDeg: Double = 0

    // 陪伴时长统计与偏好
    @Published public var todayCompanionSec: TimeInterval = 0
    @Published public var totalCompanionSec: TimeInterval = 0
    @Published public var todayHeadDownAlertCount: Int = 0
    @Published public var streakDays: Int = 0
    @Published public var recent7Days: [DailyCompanionStat] = []

    @Published public var isPostureMonitorEnabled: Bool = true {
        didSet { persistPreferences() }
    }
    @Published public var headDownAngleThresholdDeg: Double = 20.0 {
        didSet {
            postureEngine.angleThresholdDeg = headDownAngleThresholdDeg
            persistPreferences()
        }
    }
    @Published public var headDownTimeoutSec: TimeInterval = 60.0 {
        didSet {
            postureEngine.timeoutSeconds = headDownTimeoutSec
            persistPreferences()
        }
    }
    @Published public var voiceReminderEnabled: Bool = true {
        didSet { persistPreferences() }
    }
    @Published public var nodToCompleteSetEnabled: Bool = true {
        didSet { persistPreferences() }
    }
    @Published public var shakeAction: HeadphoneShakeAction = .smartDual {
        didSet { persistPreferences() }
    }

    @Published public var notificationGranted = false
    @Published public var lastReminderBannerText: String?

    public let gesturePublisher = PassthroughSubject<HeadphoneGestureEvent, Never>()

    private let store: HeadphoneCompanionStore
    private let postureEngine = HeadPostureEngine()
    private let gestureDetector = HeadGestureDetector()
    private let synthesizer = AVSpeechSynthesizer()

    #if canImport(CoreMotion)
    private let headphoneMotion = CMHeadphoneMotionManager()
    #endif

    private var companionTimer: Timer?
    private var simPostureTimer: Timer?
    private var ticksSinceLastSave = 0
    private var routeObserver: NSObjectProtocol?

    public init(store: HeadphoneCompanionStore = HeadphoneCompanionStore()) {
        self.store = store
        super.init()
        loadFromStore()
    }

    deinit {
        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
        }
    }

    public func companionSeconds(for model: HeadphoneModelKind) -> TimeInterval {
        store.companionSeconds(for: model)
    }

    /// App 启动时调用：检查音频路由并开始记录今日/总陪伴时长及低头监测。
    public func startSessionTracking() {
        #if canImport(CoreMotion) && !targetEnvironment(simulator)
        isMotionAvailable = headphoneMotion.isDeviceMotionAvailable
        #else
        isMotionAvailable = false
        #endif

        refreshConnectedAudioRoute()
        if routeObserver == nil {
            routeObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshConnectedAudioRoute()
                }
            }
        }

        if companionTimer == nil {
            companionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.tickCompanionSecond()
                }
            }
        }

        refreshNotificationAuthorization()
        if isPostureMonitorEnabled && isMotionAvailable {
            startHeadphoneMotionUpdates()
        }
    }

    public func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            Task { @MainActor [weak self] in
                self?.notificationGranted = granted
            }
        }
    }

    public func refreshNotificationAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor [weak self] in
                self?.notificationGranted = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
            }
        }
    }

    public func selectDisplayModel(_ model: HeadphoneModelKind) {
        activeModel = model
        store.update { $0.preferredModel = model }
    }

    public func selectMaxColor(_ color: AirPodsMaxColor) {
        airPodsMaxColor = color
        store.update { $0.airPodsMaxColor = color }
    }

    /// 校准当前坐姿为 0° 中立点
    public func calibrateUprightZero() {
        postureEngine.calibrate(currentDownwardPitchDeg: livePitchDeg + postureEngine.baselinePitchDeg)
        store.update { $0.baselinePitchDeg = postureEngine.baselinePitchDeg }
        livePitchDeg = 0
        continuousHeadDownSec = 0
        alertLevel = .upright
        lastReminderBannerText = "已校准正坐零点"
    }

    public func setPostureMonitor(enabled: Bool) {
        isPostureMonitorEnabled = enabled
        if enabled {
            if isMotionAvailable {
                startHeadphoneMotionUpdates()
            }
        } else {
            stopHeadphoneMotionUpdates()
            postureEngine.resetTimer()
            continuousHeadDownSec = 0
            alertLevel = .upright
        }
    }

    /// 供真机无支持传感器耳机/模拟器下手动拖动低头角度测试护颈提醒与 3D 模型跟随。
    public func applySimulatedAngle(pitchDeg: Double) {
        simulatedPitchDeg = pitchDeg
        livePitchDeg = pitchDeg
        if isPostureMonitorEnabled && !isMotionTrackingActive {
            startSimulatedPostureTimerIfNeeded()
        }
    }

    public func triggerTestAlert() {
        fireHeadDownAlert(angleDeg: max(livePitchDeg, headDownAngleThresholdDeg), heldSeconds: headDownTimeoutSec)
    }

    public func triggerTestNod() {
        gesturePublisher.send(.nodCompleteSet)
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.75)
        #endif
    }

    public func triggerTestShake() {
        let action = shakeAction
        if action == .nextTrack {
            NotificationCenter.default.post(name: .strideMusicNextTrack, object: nil)
        }
        gesturePublisher.send(.shake(action))
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
        #endif
    }

    public func speakFormCue(_ text: String) {
        guard voiceReminderEnabled else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.50
        utterance.volume = 0.85
        synthesizer.speak(utterance)
    }

    // MARK: - 内部传感器与音频路由实现

    private func refreshConnectedAudioRoute() {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        let headphonePortTypes: Set<AVAudioSession.Port> = [
            .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .headphones, .usbAudio
        ]
        if let port = outputs.first(where: { headphonePortTypes.contains($0.portType) }) {
            isHeadphoneConnected = true
            connectedDeviceName = port.portName
            if let detected = HeadphoneModelKind.detect(fromPortName: port.portName) {
                activeModel = detected
                store.update { $0.preferredModel = detected }
            }
            if isPostureMonitorEnabled && isMotionAvailable && !isMotionTrackingActive {
                startHeadphoneMotionUpdates()
            }
        } else {
            isHeadphoneConnected = false
            connectedDeviceName = "未连接蓝牙耳机"
            store.save()
        }
    }

    private func tickCompanionSecond() {
        if isHeadphoneConnected {
            store.addCompanionTime(1.0, model: activeModel, at: Date())
            todayCompanionSec = store.todaySeconds()
            totalCompanionSec = store.state.totalSeconds
            streakDays = store.streakDays()
            recent7Days = store.recent7Days()
            ticksSinceLastSave += 1
            if ticksSinceLastSave >= 10 {
                ticksSinceLastSave = 0
                store.save()
            }
        }
    }

    private func startHeadphoneMotionUpdates() {
        #if canImport(CoreMotion) && !targetEnvironment(simulator)
        guard headphoneMotion.isDeviceMotionAvailable, !isMotionTrackingActive else { return }
        isMotionTrackingActive = true
        headphoneMotion.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let pitchDeg = -motion.attitude.pitch * 180.0 / .pi
            let yawDeg = motion.attitude.yaw * 180.0 / .pi
            let rollDeg = motion.attitude.roll * 180.0 / .pi

            self.liveYawDeg = yawDeg
            self.liveRollDeg = rollDeg

            let postureOut = self.postureEngine.step(downwardPitchDeg: pitchDeg, timestamp: motion.timestamp)
            self.livePitchDeg = postureOut.relativeDownwardDeg
            self.continuousHeadDownSec = postureOut.continuousHeadDownSec
            self.alertLevel = postureOut.alertLevel

            if postureOut.shouldTriggerAlert && self.isPostureMonitorEnabled {
                self.fireHeadDownAlert(angleDeg: postureOut.relativeDownwardDeg, heldSeconds: postureOut.continuousHeadDownSec)
            }

            if let rawGesture = self.gestureDetector.ingest(
                timestamp: motion.timestamp,
                pitchRateX: motion.rotationRate.x,
                yawRateY: motion.rotationRate.y
            ) {
                switch rawGesture {
                case .nod:
                    if self.nodToCompleteSetEnabled {
                        self.gesturePublisher.send(.nodCompleteSet)
                    }
                case .shake:
                    let action = self.shakeAction
                    if action == .nextTrack {
                        NotificationCenter.default.post(name: .strideMusicNextTrack, object: nil)
                    }
                    self.gesturePublisher.send(.shake(action))
                }
            }
        }
        #endif
    }

    private func stopHeadphoneMotionUpdates() {
        #if canImport(CoreMotion) && !targetEnvironment(simulator)
        if headphoneMotion.isDeviceMotionActive {
            headphoneMotion.stopDeviceMotionUpdates()
        }
        #endif
        isMotionTrackingActive = false
        simPostureTimer?.invalidate()
        simPostureTimer = nil
    }

    private func startSimulatedPostureTimerIfNeeded() {
        guard simPostureTimer == nil else { return }
        simPostureTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPostureMonitorEnabled, !self.isMotionTrackingActive else { return }
                let nowTs = Date().timeIntervalSinceReferenceDate
                let out = self.postureEngine.step(downwardPitchDeg: self.simulatedPitchDeg + self.postureEngine.baselinePitchDeg, timestamp: nowTs)
                self.livePitchDeg = out.relativeDownwardDeg
                self.continuousHeadDownSec = out.continuousHeadDownSec
                self.alertLevel = out.alertLevel
                if out.shouldTriggerAlert {
                    self.fireHeadDownAlert(angleDeg: out.relativeDownwardDeg, heldSeconds: out.continuousHeadDownSec)
                }
            }
        }
    }

    private func fireHeadDownAlert(angleDeg: Double, heldSeconds: TimeInterval) {
        store.recordHeadDownAlert()
        store.save()
        todayHeadDownAlertCount = store.todayAlerts()

        let angleInt = Int(angleDeg.rounded())
        let secInt = Int(heldSeconds.rounded())
        let msg = "已低头约 \(angleInt)° 持续 \(secInt) 秒，请抬头活动一下颈椎"
        lastReminderBannerText = msg

        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif

        let content = UNMutableNotificationContent()
        content.title = "颈椎健康提醒 · 注意抬头"
        content.body = msg
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "stride.posture.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req)

        if voiceReminderEnabled {
            speakFormCue("已低头超过设定时间，请抬头放松颈椎。")
        }
    }

    private func loadFromStore() {
        let s = store.state
        activeModel = s.preferredModel
        airPodsMaxColor = s.airPodsMaxColor
        isPostureMonitorEnabled = s.isPostureMonitorEnabled
        headDownAngleThresholdDeg = s.headDownAngleThresholdDeg
        headDownTimeoutSec = s.headDownTimeoutSec
        voiceReminderEnabled = s.voiceReminderEnabled
        nodToCompleteSetEnabled = s.nodToCompleteSetEnabled
        shakeAction = s.shakeAction
        postureEngine.baselinePitchDeg = s.baselinePitchDeg
        postureEngine.angleThresholdDeg = s.headDownAngleThresholdDeg
        postureEngine.timeoutSeconds = s.headDownTimeoutSec

        todayCompanionSec = store.todaySeconds()
        totalCompanionSec = s.totalSeconds
        todayHeadDownAlertCount = store.todayAlerts()
        streakDays = store.streakDays()
        recent7Days = store.recent7Days()
    }

    private func persistPreferences() {
        store.update { s in
            s.isPostureMonitorEnabled = isPostureMonitorEnabled
            s.headDownAngleThresholdDeg = headDownAngleThresholdDeg
            s.headDownTimeoutSec = headDownTimeoutSec
            s.voiceReminderEnabled = voiceReminderEnabled
            s.nodToCompleteSetEnabled = nodToCompleteSetEnabled
            s.shakeAction = shakeAction
            s.preferredModel = activeModel
            s.airPodsMaxColor = airPodsMaxColor
        }
    }
}
