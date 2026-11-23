import Foundation
import AVFoundation
import Combine

// MARK: - 1. 原生离线助眠环境白噪音实时合成引擎（零外部音频文件依赖）

enum AmbientScene: String, CaseIterable, Identifiable {
    case rain = "夏夜雨声"
    case fireplace = "壁炉篝火"
    case ocean = "深海白噪音"
    case forest = "森林晚风"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .rain: return "cloud.rain.fill"
        case .fireplace: return "flame.fill"
        case .ocean: return "water.waves"
        case .forest: return "leaf.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .rain: return "柔和粉红雨幕 · 屋檐稀疏水滴"
        case .fireplace: return "深沉木柴暖频 · 随机火星轻响"
        case .ocean: return "0.12Hz 潮汐包络 · 深海低频涌动"
        case .forest: return "动态扫频松林风声 · 呼吸共振"
        }
    }

    /// 滤波器基础截止系数（0.03...0.45）
    var filterAlpha: Float {
        switch self {
        case .rain: return 0.24
        case .fireplace: return 0.08
        case .ocean: return 0.12
        case .forest: return 0.18
        }
    }
}

/// 基于 AVAudioEngine + AVAudioPCMBuffer 环形缓冲合成的真实环境声场播放器。
final class AmbientAudioEngine: ObservableObject {
    static let shared = AmbientAudioEngine()

    @Published private(set) var isPlaying: Bool = false
    @Published var currentScene: AmbientScene = .rain {
        didSet {
            if isPlaying && oldValue != currentScene {
                rebuildAndScheduleBuffer()
            }
        }
    }
    @Published var volume: Float = 0.55 {
        didSet {
            let clamped = min(1.0, max(0.0, volume))
            if volume != clamped {
                volume = clamped
            }
            engine.mainMixerNode.outputVolume = clamped
        }
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var format: AVAudioFormat?
    private var attached = false

    init() {
        setupAudioGraph()
    }

    private func setupAudioGraph() {
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else { return }
        self.format = fmt
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: fmt)
        engine.mainMixerNode.outputVolume = volume
        attached = true
    }

    func start(scene: AmbientScene? = nil) {
        if let scene {
            currentScene = scene
        }
        guard attached else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        if !engine.isRunning {
            try? engine.start()
        }
        rebuildAndScheduleBuffer()
        if engine.isRunning && !player.isPlaying {
            player.play()
        }
        isPlaying = true
    }

    func stop() {
        if player.isPlaying {
            player.stop()
        }
        isPlaying = false
    }

    func toggle(scene: AmbientScene? = nil) {
        if isPlaying {
            stop()
        } else {
            start(scene: scene)
        }
    }

    /// 离线生成 4 秒无缝循环的环境音频 PCM 缓冲，兼容真机与 Simulator。
    static func synthesizeLoopBuffer(scene: AmbientScene, sampleRate: Double = 44100, seconds: Double = 4.0) -> AVAudioPCMBuffer? {
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return nil }
        let frameCount = AVAudioFrameCount(max(1024, Int(sampleRate * seconds)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        var b0: Float = 0, b1: Float = 0, b2: Float = 0
        var lowpass: Float = 0
        var rngState: UInt64 = 0x9E3779B97F4A7C15
        let alpha = scene.filterAlpha
        let total = Int(frameCount)

        for i in 0..<total {
            // xorshift64* 高速伪随机白噪声 (-1...1)
            rngState ^= rngState >> 12
            rngState ^= rngState << 25
            rngState ^= rngState >> 27
            let randUnit = Float((rngState &* 2685821657736338717) >> 40) / Float(1 << 24)
            let white = randUnit * 2.0 - 1.0

            // Kellet 3 阶粉红噪声近似
            b0 = 0.99765 * b0 + white * 0.0990460
            b1 = 0.96300 * b1 + white * 0.2965164
            b2 = 0.57000 * b2 + white * 1.0526913
            let pink = (b0 + b1 + b2 + white * 0.1848) * 0.12

            let t = Double(i) / sampleRate
            var sample: Float = 0

            switch scene {
            case .rain:
                lowpass = lowpass + alpha * (pink - lowpass)
                let dropBurst: Float = (i % 6400 < 90) ? sin(Float(i % 90) * 0.35) * 0.08 : 0
                sample = lowpass * 0.52 + dropBurst

            case .fireplace:
                lowpass = lowpass + alpha * (pink - lowpass)
                let crackleGate = (rngState & 0x3FFF) == 7
                let crackle: Float = crackleGate ? (white * 0.32) : 0
                sample = lowpass * 0.68 + crackle

            case .ocean:
                lowpass = lowpass + alpha * (pink - lowpass)
                let tide = Float(0.52 + 0.42 * sin(2.0 * .pi * (t / seconds)))
                sample = lowpass * tide * 0.65

            case .forest:
                let dynAlpha = alpha * Float(0.75 + 0.25 * cos(2.0 * .pi * (t / seconds)))
                lowpass = lowpass + dynAlpha * (pink - lowpass)
                sample = (pink - lowpass * 0.6) * 0.42
            }

            // 首尾 1200 采样交叉淡入淡出确保循环零爆音
            let edge = 1200
            var env: Float = 1.0
            if i < edge {
                env = Float(i) / Float(edge)
            } else if i > total - edge {
                env = Float(total - i) / Float(edge)
            }
            channel[i] = max(-0.85, min(0.85, sample * env))
        }
        return buffer
    }

    private func rebuildAndScheduleBuffer() {
        guard attached, let fmt = format,
              let buf = Self.synthesizeLoopBuffer(scene: currentScene, sampleRate: fmt.sampleRate, seconds: 4.0) else { return }
        player.stop()
        player.scheduleBuffer(buf, at: nil, options: [.loops], completionHandler: nil)
        if engine.isRunning {
            player.play()
        }
    }
}

// MARK: - 2. 运动科学播客中文语音精讲播放器（原生 AVSpeechSynthesizer）

struct PodcastEpisodeItem: Identifiable, Equatable {
    let id: String
    let code: String
    let title: String
    let durationLabel: String
    let category: String
    let summary: String
    let segments: [String]
}

final class PodcastSpeechPlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = PodcastSpeechPlayer()

    static let catalog: [PodcastEpisodeItem] = [
        PodcastEpisodeItem(
            id: "p1",
            code: "EP.01",
            title: "Zone 2 轻松跑为什么能越跑越快？",
            durationLabel: "18 分钟 · 耐力生理学",
            category: "耐力生理学",
            summary: "解析线粒体密度、毛细血管网与乳酸清除率（MCT-1）的底层生理适应机制。",
            segments: [
                "欢迎收听步迹运动科学播客第一期：为什么看似轻松的二区有氧跑，反而能让你的配速稳步提升？",
                "生理学上，Zone 2 对应血乳酸浓度维持在 2 毫摩尔每升以下的最高有氧强度，大约在最大心率的百分之 60 到 70。",
                "在这个区间内，你的慢肌纤维（I 型肌纤维）得到最充分的募集，线粒体生物合成信号 PGC-1alpha 达到峰值。",
                "坚持每周 3 到 4 次、每次 45 分钟以上的二区跑，能显著提升心肌每搏输出量与骨骼肌毛细血管密度。",
                "记住核心原则：把百分之 80 的周跑量留给能够完整说出一句话的轻松配速，把高强度留在百分之 20 的间歇日。"
            ]
        ),
        PodcastEpisodeItem(
            id: "p2",
            code: "EP.02",
            title: "每周多少组才算有效肌肥大容量？",
            durationLabel: "22 分钟 · 力量训练",
            category: "力量训练",
            summary: "从最小有效容量（MEV）到最大可恢复容量（MRV），拆解自然训练者的黄金周组数。",
            segments: [
                "欢迎来到步迹播客第二期：今天我们聊聊自然健身者每周每个肌群到底应该练多少组？",
                "根据 Schoenfeld 等人的系统综述，大肌群每周 10 到 18 组接近力竭的有效工作组，是肌肥大收益最高的黄金甜区。",
                "所谓有效工作组，是指距离力竭还有 1 到 3 次余力，也就是 RPE 7 到 9 的正式组，不包含轻重量热身组。",
                "如果把 16 组全部堆在同一个训练日，第 9 组之后的机械张力与神经募集会大幅衰减，变成无效垃圾容量。",
                "最优策略是将同一肌群拆分为每周 2 次频率，每次安排 6 到 8 组高质量正式组，给蛋白质合成留出 48 小时恢复窗口。"
            ]
        ),
        PodcastEpisodeItem(
            id: "p3",
            code: "EP.03",
            title: "赛前碳水加载与补给窗口实操",
            durationLabel: "15 分钟 · 马拉松营养",
            category: "马拉松营养",
            summary: "如何避免撞墙期？肝糖原与肌糖原超量恢复时间窗及能量胶摄入配比指南。",
            segments: [
                "欢迎收听步迹播客第三期：长距离耐力赛前的碳水加载与比赛中能量补给实操指南。",
                "人体肌糖原与肝糖原总储量大约在 400 到 500 克，折合不到 2000 千卡热量，在半马后段或全马 30 公里极易耗尽。",
                "赛前 36 到 48 小时，建议将每日碳水摄入提高到每公斤体重 7 到 9 克，同时减少高纤维与高油脂食物以减轻肠胃负担。",
                "起跑后不要等口渴或饥饿再补给：建议从第 40 分钟起，每 35 到 45 分钟补充一支含 25 克碳水的等渗能量胶。",
                "搭配双源碳水（麦芽糊精加果糖）可将肠道每小时碳水吸收上限从 60 克提升至 90 克，彻底告别 32 公里撞墙期。"
            ]
        )
    ]

    @Published private(set) var playingEpisodeID: String? = nil
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentSegmentIndex: Int = 0
    @Published var playbackSpeedMultiplier: Float = 1.0

    private let synthesizer = AVSpeechSynthesizer()
    private var activeEpisode: PodcastEpisodeItem?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    var progress: Double {
        guard let ep = activeEpisode, !ep.segments.isEmpty else { return 0 }
        return min(1.0, max(0.0, Double(currentSegmentIndex + 1) / Double(ep.segments.count)))
    }

    func toggle(episode: PodcastEpisodeItem) {
        if playingEpisodeID == episode.id && isPlaying {
            stop()
        } else {
            play(episode: episode, segmentIndex: playingEpisodeID == episode.id ? currentSegmentIndex : 0)
        }
    }

    func play(episode: PodcastEpisodeItem, segmentIndex: Int = 0) {
        synthesizer.stopSpeaking(at: .immediate)
        activeEpisode = episode
        playingEpisodeID = episode.id
        currentSegmentIndex = min(max(0, segmentIndex), max(0, episode.segments.count - 1))
        isPlaying = true
        speakCurrentSegment()
    }

    func cycleSpeed() {
        if playbackSpeedMultiplier < 1.1 {
            playbackSpeedMultiplier = 1.25
        } else if playbackSpeedMultiplier < 1.4 {
            playbackSpeedMultiplier = 1.5
        } else {
            playbackSpeedMultiplier = 1.0
        }
        if isPlaying, let ep = activeEpisode {
            play(episode: ep, segmentIndex: currentSegmentIndex)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
    }

    private func speakCurrentSegment() {
        guard let ep = activeEpisode,
              ep.segments.indices.contains(currentSegmentIndex) else {
            isPlaying = false
            return
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: ep.segments[currentSegmentIndex])
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = min(0.62, max(0.42, 0.50 * playbackSpeedMultiplier))
        synthesizer.speak(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isPlaying, let ep = self.activeEpisode else { return }
            if self.currentSegmentIndex + 1 < ep.segments.count {
                self.currentSegmentIndex += 1
                self.speakCurrentSegment()
            } else {
                self.isPlaying = false
                self.currentSegmentIndex = 0
            }
        }
    }
}
