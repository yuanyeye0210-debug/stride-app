import SwiftUI
import PhotosUI
import Combine
import UIKit

// MARK: - 插件交互总路由弹窗

struct PluginToolHostSheet: View {
    @Environment(\.dismiss) private var dismiss
    let plugin: StridePluginItem

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                toolBody
            }
            .navigationTitle(plugin.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var toolBody: some View {
        switch plugin.interaction {
        case .cadenceMetronome:
            CadenceMetronomeToolView()
        case .intervalTimer:
            IntervalTimerToolView()
        case .breatheGuide:
            BreatheGuideToolView()
        case .stretchTimer:
            StretchTimerToolView()
        case .sleepAudio:
            SleepAudioToolView()
        case .hrrTest:
            HRRTestToolView()
        case .shoeMileage:
            ShoeMileageToolView()
        case .posturePolaroid:
            PosturePolaroidToolView()
        case .linearProgression:
            LinearProgressionToolView()
        case .macrosPlanner:
            MacrosPlannerToolView()
        case .runWatermark, .glassWatermark, .deviceFrame:
            WatermarkStudioToolView(mode: plugin.interaction)
        case .musicShortcut:
            PlaylistImportView()
        case .podcastPlayer:
            PodcastToolView()
        case .calculator(let kind):
            ScientificCalculatorToolView(kind: kind)
        }
    }
}

// MARK: - 1. 步频节拍器（真发声鼓点 + Tap Tempo 点按测速 + 雷达脉冲）

private struct CadenceMetronomeToolView: View {
    @State private var spm: Double = 176
    @State private var running = false
    @State private var beatOn = false
    @State private var count = 0
    @State private var timer: Timer?
    @State private var tapTimestamps: [TimeInterval] = []

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RadarPulseRing(color: Palette.lime, isActive: running, size: 170)

                Circle()
                    .fill(beatOn ? Palette.lime.opacity(0.28) : Color.white.opacity(0.06))
                    .frame(width: 170, height: 170)
                    .scaleEffect(beatOn ? 1.12 : 1.0)
                    .animation(.easeOut(duration: 0.12), value: beatOn)

                VStack(spacing: 4) {
                    Text("\(Int(spm))")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.lime)
                        .numericRoll(value: Int(spm))
                    Text("步 / 分钟 (SPM)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.textDim)
                }
            }
            .padding(.top, 14)

            Slider(value: $spm, in: 145...205, step: 1) { _ in
                if running { restartTimer() }
            }
            .tint(Palette.lime)
            .padding(.horizontal)

            HStack(spacing: 10) {
                ForEach([165, 175, 180, 190], id: \.self) { preset in
                    Button("\(preset)") {
                        spm = Double(preset)
                        if running { restartTimer() }
                    }
                    .buttonStyle(.strideStepper(accent: Palette.lime))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Int(spm) == preset ? Color.black : Palette.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Int(spm) == preset ? Palette.lime : Palette.card))
                }
            }

            Button {
                let now = Date().timeIntervalSinceReferenceDate
                tapTimestamps.append(now)
                if tapTimestamps.count > 5 {
                    tapTimestamps.removeFirst(tapTimestamps.count - 5)
                }
                if let measured = TapTempoCalculator.computeBPM(timestamps: tapTimestamps, range: 145...205) {
                    spm = Double(measured)
                    if running { restartTimer() }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                    Text("连续点按测步频 (Tap Tempo)")
                }
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(Palette.lime)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(Palette.cardHigh))
                .overlay(Capsule().strokeBorder(Palette.lime.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.strideStepper(accent: Palette.lime))

            Spacer()

            PrimaryButton(title: running ? "停止节拍器" : "启动声音 + 触觉打拍", tint: Palette.lime) {
                running.toggle()
                if running { restartTimer() } else { stopTimer() }
            }
        }
        .padding(Metrics.page)
        .onDisappear { stopTimer() }
    }

    private func restartTimer() {
        stopTimer()
        let bpmInt = Int(spm.rounded())
        MetronomeAudioEngine.shared.start(bpm: bpmInt)
        let interval = 60.0 / max(100, spm)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            beatOn = true
            count += 1
            UIImpactFeedbackGenerator(style: count % 2 == 0 ? .medium : .light).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                beatOn = false
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        beatOn = false
        MetronomeAudioEngine.shared.stop()
    }
}

// MARK: - 2. 间歇计时器

private struct IntervalTimerToolView: View {
    @State private var workSec = 20
    @State private var restSec = 10
    @State private var rounds = 8

    @State private var running = false
    @State private var currentRound = 1
    @State private var isWorkPhase = true
    @State private var remainSec = 20

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text(isWorkPhase ? "全力输出" : "组间恢复")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isWorkPhase ? Palette.lime : Palette.blue)
                Text("\(remainSec)")
                    .font(.system(size: 68, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.text)
                    .monospacedDigit()
                Text("第 \(currentRound) / \(rounds) 轮")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textDim)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .card(radius: 24, fill: Palette.card, stroke: Palette.stroke)

            HStack(spacing: 10) {
                ForEach([("Tabata 20/10", 20, 10, 8), ("EMOM 60s", 60, 0, 10), ("40/20 × 6", 40, 20, 6)], id: \.0) { item in
                    Button(item.0) {
                        applyPreset(w: item.1, r: item.2, n: item.3)
                    }
                    .buttonStyle(.strideStepper(accent: Palette.lime))
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Palette.cardHigh))
                }
            }

            VStack(spacing: 10) {
                Stepper("工作时长：\(workSec) 秒", value: $workSec, in: 10...180, step: 5)
                Stepper("休息时长：\(restSec) 秒", value: $restSec, in: 0...120, step: 5)
                Stepper("总轮数：\(rounds) 轮", value: $rounds, in: 1...20)
            }
            .font(.system(size: 14))
            .foregroundStyle(Palette.text)
            .padding(14)
            .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
            .disabled(running)

            Spacer()

            HStack(spacing: 10) {
                SecondaryButton(title: "重置") {
                    running = false
                    currentRound = 1
                    isWorkPhase = true
                    remainSec = workSec
                }
                PrimaryButton(title: running ? "暂停" : "开始", tint: Palette.lime) {
                    if !running && remainSec <= 0 {
                        currentRound = 1
                        isWorkPhase = true
                        remainSec = workSec
                    }
                    running.toggle()
                }
            }
        }
        .padding(Metrics.page)
        .onReceive(ticker) { _ in
            guard running else { return }
            if remainSec > 1 {
                remainSec -= 1
            } else if isWorkPhase && restSec > 0 {
                isWorkPhase = false
                remainSec = restSec
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            } else if currentRound < rounds {
                currentRound += 1
                isWorkPhase = true
                remainSec = workSec
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                running = false
                remainSec = 0
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func applyPreset(w: Int, r: Int, n: Int) {
        running = false
        workSec = w
        restSec = r
        rounds = n
        currentRound = 1
        isWorkPhase = true
        remainSec = w
    }
}

// MARK: - 3. 呼吸训练

private struct BreatheGuideToolView: View {
    @State private var mode = 0 // 0=方块 4-4-4-4, 1=4-7-8, 2=共振 5.5
    @State private var running = false
    @State private var stepIdx = 0
    @State private var remain = 4

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var stages: [(name: String, sec: Int, expanded: Bool)] {
        switch mode {
        case 1: return [("吸气", 4, true), ("屏息", 7, true), ("慢呼", 8, false)]
        case 2: return [("吸气", 6, true), ("呼气", 6, false)]
        default: return [("吸气", 4, true), ("屏息", 4, true), ("呼气", 4, false), ("屏息", 4, false)]
        }
    }

    var body: some View {
        let cur = stages[stepIdx % stages.count]
        VStack(spacing: 22) {
            Picker("", selection: $mode) {
                Text("方块 4-4-4-4").tag(0)
                Text("助眠 4-7-8").tag(1)
                Text("共振呼吸").tag(2)
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in
                running = false
                stepIdx = 0
                remain = stages[0].sec
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(Palette.cyan.opacity(0.22))
                    .frame(width: cur.expanded && running ? 210 : 120, height: cur.expanded && running ? 210 : 120)
                    .animation(.easeInOut(duration: Double(cur.sec)), value: stepIdx)

                Circle()
                    .strokeBorder(Palette.cyan, lineWidth: 2)
                    .frame(width: 140, height: 140)

                VStack(spacing: 4) {
                    Text(running ? cur.name : "准备")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Palette.text)
                    Text("\(remain)s")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.cyan)
                }
            }

            Spacer()

            PrimaryButton(title: running ? "结束" : "开始跟练", tint: Palette.cyan) {
                running.toggle()
                stepIdx = 0
                remain = stages[0].sec
            }
        }
        .padding(Metrics.page)
        .onReceive(ticker) { _ in
            guard running else { return }
            if remain > 1 {
                remain -= 1
            } else {
                stepIdx = (stepIdx + 1) % stages.count
                remain = stages[stepIdx].sec
            }
        }
    }
}

// MARK: - 4. 拉伸跟练 / 辅助睡眠 / HRR / 播客

private struct StretchTimerToolView: View {
    @State private var routine = 0
    @State private var idx = 0
    @State private var secLeft = 30
    @State private var running = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let routines: [[(String, Int)]] = [
        [("股四头肌站姿拉伸", 30), ("腘绳肌前屈拉伸", 30), ("小腿腓肠肌推墙", 30), ("臀中肌交叉抱膝", 30)],
        [("胸大肌门框拉伸", 30), ("背阔肌婴儿式延伸", 30), ("肩后束横臂拉伸", 30), ("髂腰肌弓步拉伸", 40)],
        [("颈部斜方侧倾", 25), ("胸椎泡沫轴/猫牛式", 35), ("梨状肌坐姿 4 字", 35), ("手腕前臂伸展", 25)]
    ]

    var body: some View {
        let items = routines[routine]
        let cur = items[idx % items.count]
        VStack(spacing: 18) {
            Picker("", selection: $routine) {
                Text("跑后拉伸").tag(0)
                Text("练后放松").tag(1)
                Text("久坐缓解").tag(2)
            }
            .pickerStyle(.segmented)
            .onChange(of: routine) { _, _ in
                running = false; idx = 0; secLeft = routines[routine][0].1
            }

            VStack(spacing: 8) {
                Text(cur.0).font(.system(size: 22, weight: .bold)).foregroundStyle(Palette.text)
                Text("\(secLeft) 秒").font(.system(size: 54, weight: .heavy, design: .rounded)).foregroundStyle(Palette.green)
                Text("第 \(idx + 1) / \(items.count) 个动作").font(.system(size: 12)).foregroundStyle(Palette.textDim)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .card(radius: 24, fill: Palette.card, stroke: Palette.stroke)

            ForEach(items.indices, id: \.self) { i in
                HStack {
                    Text(items[i].0).foregroundStyle(i == idx ? Palette.green : Palette.textDim)
                    Spacer()
                    Text("\(items[i].1)s").foregroundStyle(Palette.textFaint)
                }
                .font(.system(size: 13.5, weight: i == idx ? .bold : .regular))
                .padding(.horizontal, 12)
            }
            Spacer()
            PrimaryButton(title: running ? "暂停" : "开始跟练", tint: Palette.green) { running.toggle() }
        }
        .padding(Metrics.page)
        .onReceive(ticker) { _ in
            guard running else { return }
            if secLeft > 1 { secLeft -= 1 }
            else if idx + 1 < items.count { idx += 1; secLeft = items[idx].1 }
            else { running = false; idx = 0; secLeft = items[0].1 }
        }
    }
}

private struct SleepAudioToolView: View {
    @StateObject private var ambient = AmbientAudioEngine.shared
    @State private var scene: AmbientScene = .rain
    @State private var minutes = 30
    @State private var secLeft = 1800
    @State private var running = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(AmbientScene.allCases) { item in
                    let on = scene == item
                    Button {
                        scene = item
                        ambient.currentScene = item
                        if running {
                            ambient.start(scene: item)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: item.icon)
                                .font(.system(size: 14, weight: .bold))
                            Text(item.rawValue)
                                .font(.system(size: 13.5, weight: .semibold))
                        }
                        .foregroundStyle(on ? Color.black : Palette.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 14).fill(on ? Palette.purple : Palette.card))
                    }
                    .buttonStyle(.strideStepper(accent: Palette.purple))
                }
            }
            .animation(.snappy(duration: 0.2), value: scene)
            .sensoryFeedback(.selection, trigger: scene)

            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Text(scene.rawValue).font(.system(size: 18, weight: .bold)).foregroundStyle(Palette.text)
                    AudioSpectrumBars(isPlaying: running, bpm: 72, color: Palette.purple, barCount: 5, maxHeight: 16)
                }
                Text(scene.subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.textDim)
                Text(PluginMath.formatDuration(Double(secLeft)))
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.purple)
                    .monospacedDigit()
                    .numericRoll(value: secLeft, countsDown: true)
                Text(running ? "实时合成环境声场播放中" : "选好时长点开始播放真实助眠声场")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.textDim)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .luxuryCard(radius: 22, accent: Palette.purple)

            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill").foregroundStyle(Palette.purple)
                    Text("声场音量")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(Palette.text)
                    Slider(value: $ambient.volume, in: 0.05...1.0)
                        .tint(Palette.purple)
                }
                Stepper("定时关闭：\(minutes) 分钟", value: $minutes, in: 10...90, step: 10)
                    .foregroundStyle(Palette.text)
                    .onChange(of: minutes) { _, v in if !running { secLeft = v * 60 } }
            }
            .padding(14)
            .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)

            Spacer()
            PrimaryButton(title: running ? "停止声场" : "播放\(scene.rawValue)并开始定时", tint: Palette.purple) {
                if !running {
                    secLeft = minutes * 60
                    running = true
                    ambient.start(scene: scene)
                } else {
                    running = false
                    ambient.stop()
                }
            }
        }
        .padding(Metrics.page)
        .onReceive(ticker) { _ in
            guard running else { return }
            if secLeft > 1 {
                secLeft -= 1
            } else {
                running = false
                ambient.stop()
            }
        }
        .onDisappear {
            running = false
            ambient.stop()
        }
    }
}

private struct HRRTestToolView: View {
    @State private var peakHR: Double = 165
    @State private var after1MinHR: Double = 132
    @State private var secLeft = 60
    @State private var counting = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var drop: Int { Int((peakHR - after1MinHR).rounded()) }
    private var rating: String {
        switch drop {
        case ..<13: return "偏弱（建议加强有氧底座与恢复）"
        case 13..<22: return "一般水平"
        case 22..<35: return "良好"
        default: return "优秀耐力水平"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("停下后 1 分钟心率回落计时")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textDim)
                Text("\(secLeft) s")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.coralHi)
                Button(counting ? "停止计时" : "开始 60 秒倒计时") {
                    if !counting { secLeft = 60 }
                    counting.toggle()
                }
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(Color.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.white))
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)

            VStack(spacing: 12) {
                Stepper("停下瞬间心率：\(Int(peakHR)) bpm", value: $peakHR, in: 100...210)
                Stepper("1 分钟后心率：\(Int(after1MinHR)) bpm", value: $after1MinHR, in: 50...200)
            }
            .foregroundStyle(Palette.text)
            .padding(14)
            .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)

            VStack(spacing: 4) {
                Text("1 分钟心率下降 \(drop) bpm")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(drop >= 22 ? Palette.green : Palette.amber)
                Text("评估结果：\(rating)")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textDim)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)

            Spacer()
        }
        .padding(Metrics.page)
        .onReceive(ticker) { _ in
            guard counting else { return }
            if secLeft > 1 { secLeft -= 1 } else { counting = false }
        }
    }
}

private struct PodcastToolView: View {
    @StateObject private var player = PodcastSpeechPlayer.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Label("运动科学语音精讲", systemImage: "waveform.badge.mic")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(Palette.greenText)
                    Spacer()
                    Button {
                        player.cycleSpeed()
                    } label: {
                        Text(String(format: "%.2g× 倍速", player.playbackSpeedMultiplier))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Palette.greenDeep))
                    }
                    .buttonStyle(.strideStepper(accent: Palette.green))
                }

                ForEach(PodcastSpeechPlayer.catalog) { ep in
                    let on = player.playingEpisodeID == ep.id && player.isPlaying
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            player.toggle(episode: ep)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(ep.code)
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color.black)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(on ? Palette.green : Palette.yellow))
                                        Text(ep.durationLabel)
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(Palette.textDim)
                                    }
                                    Text(ep.title)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(Palette.text)
                                        .multilineTextAlignment(.leading)
                                    Text(ep.summary)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Palette.textDim)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                VStack(spacing: 6) {
                                    Image(systemName: on ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(on ? Palette.green : Palette.text)
                                        .symbolEffect(.bounce, value: on)
                                    if on {
                                        AudioSpectrumBars(isPlaying: true, bpm: 120, color: Palette.green, barCount: 4, maxHeight: 12)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.strideCard(radius: 18))

                        if player.playingEpisodeID == ep.id {
                            BarProgress(progress: player.progress, color: Palette.green, height: 4)
                            let segIdx = min(max(0, player.currentSegmentIndex), ep.segments.count - 1)
                            Text("章节 \(segIdx + 1)/\(ep.segments.count)：\(ep.segments[segIdx])")
                                .font(.system(size: 12.5))
                                .foregroundStyle(Palette.greenText)
                                .lineSpacing(3)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.cardSoft))
                        }
                    }
                    .padding(14)
                    .luxuryCard(radius: 18, accent: on ? Palette.green : Palette.blue)
                }
            }
            .animation(.snappy(duration: 0.22), value: player.playingEpisodeID)
            .animation(.snappy(duration: 0.22), value: player.currentSegmentIndex)
            .sensoryFeedback(.selection, trigger: player.playingEpisodeID)
            .padding(Metrics.page)
        }
        .onDisappear {
            player.stop()
        }
    }
}

// MARK: - 5. 跑鞋里程管理

private struct ShoeMileageToolView: View {
    @EnvironmentObject private var store: AppStore
    @State private var brand = ""
    @State private var name = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    TextField("品牌（如 Nike / Asics / 特步）", text: $brand)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Palette.text)
                        .padding(11)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.cardSoft))
                    TextField("鞋款名称（如 Pegasus 41）", text: $name)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Palette.text)
                        .padding(11)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.cardSoft))
                    PrimaryButton(title: "添加跑鞋（跑步时自动累计里程）", enabled: !name.isEmpty, tint: Palette.lime) {
                        store.addShoe(name: name, brand: brand.isEmpty ? "跑鞋" : brand)
                        name = ""
                        brand = ""
                    }
                }
                .padding(14)
                .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)

                ForEach(store.state.shoes) { shoe in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(shoe.brand) · \(shoe.name)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Palette.text)
                            Spacer()
                            Button(role: .destructive) {
                                store.deleteShoe(id: shoe.id)
                            } label: {
                                Image(systemName: "trash").foregroundStyle(Palette.textFaint)
                            }
                        }
                        BarProgress(progress: shoe.loggedKm / max(1, shoe.maxKm), color: Palette.lime, height: 6)
                        Text(String(format: "已跑 %.1f km / 寿命 %.0f km", shoe.loggedKm, shoe.maxKm))
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textDim)
                    }
                    .padding(14)
                    .card(radius: 16, fill: Palette.card, stroke: Palette.stroke)
                }
            }
            .padding(Metrics.page)
        }
    }
}

// MARK: - 6. 体态拍立得

private struct PosturePolaroidToolView: View {
    @EnvironmentObject private var store: AppStore
    @State private var pickerItem: PhotosPickerItem?

    private var posturePhotos: [PhotoMemory] {
        store.state.photoMemories.filter { $0.categoryRaw == "posture" }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    HStack {
                        Image(systemName: "camera.viewfinder")
                        Text("选择本周体态照，生成拍立得卡片")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                }
                .onChange(of: pickerItem) { _, item in
                    Task {
                        if let item, let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                            store.savePhotoMemory(image: img, caption: "体态记录", category: "posture")
                        }
                    }
                }

                if posturePhotos.isEmpty {
                    EmptyHint(icon: "person.crop.rectangle", title: "还没有体态照", message: "每周拍一张正面/侧面体态照，自动叠成拍立得方便对比。")
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                        ForEach(posturePhotos) { p in
                            if let img = store.loadPhotoImage(fileName: p.fileName) {
                                VStack(spacing: 8) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 170)
                                        .clipped()
                                    Text(dayText(p.date))
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(Color.black)
                                }
                                .padding(10)
                                .padding(.bottom, 6)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
            }
            .padding(Metrics.page)
        }
    }

    private func dayText(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy.MM.dd"; return f.string(from: d)
    }
}

// MARK: - 7. +2.5 线性加重周期（直接存进个人模板）

private struct LinearProgressionToolView: View {
    @EnvironmentObject private var store: AppStore
    @State private var liftName = "深蹲"
    @State private var startKg: Double = 70
    @State private var stepKg: Double = 2.5
    @State private var weeks = 6
    @State private var savedToast = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    Picker("主项", selection: $liftName) {
                        Text("深蹲").tag("深蹲")
                        Text("杠铃卧推").tag("杠铃卧推")
                        Text("罗马尼亚硬拉").tag("罗马尼亚硬拉")
                        Text("站姿推举").tag("站姿推举")
                    }
                    .pickerStyle(.segmented)

                    Stepper("起始重量：\(String(format: "%.1f", startKg)) kg", value: $startKg, in: 20...200, step: 2.5)
                    Stepper("每周加重：+\(String(format: "%.2f", stepKg)) kg", value: $stepKg, in: 1.25...10, step: 1.25)
                    Stepper("周期长度：\(weeks) 周", value: $weeks, in: 3...12)
                }
                .foregroundStyle(Palette.text)
                .padding(14)
                .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)

                ForEach(1...weeks, id: \.self) { w in
                    let weight = startKg + Double(w - 1) * stepKg
                    HStack {
                        Text("第 \(w) 周")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Palette.green)
                        Spacer()
                        Text("\(liftName) 4 × 5 @ \(String(format: "%.2f", weight)) kg")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.text)
                    }
                    .padding(12)
                    .card(radius: 14, fill: Palette.card, stroke: Palette.stroke)
                }

                PrimaryButton(title: savedToast ? "已存入我的个人模板 ✓" : "存进个人训练模板", tint: Palette.yellow) {
                    let tpl = WorkoutTemplate(
                        id: "prog.\(UUID().uuidString)",
                        posterWords: ["+2.5", "CYCLE"],
                        accentRaw: "silver",
                        title: "\(liftName) 线性周期（第1周 \(Int(startKg))kg）",
                        level: "进阶",
                        estimatedMinutes: 50,
                        categories: ["单动作专项"],
                        focus: liftName == "杠铃卧推" ? .chest : (liftName == "站姿推举" ? .shoulders : .legs),
                        exercises: [PlannedExercise(name: liftName, sets: 4, reps: "5 @ \(Int(startKg))kg")],
                        isCustom: true
                    )
                    store.addCustomTemplate(tpl)
                    savedToast = true
                }
            }
            .padding(Metrics.page)
        }
    }
}

// MARK: - 8. 宏量分配（一键设为每日营养目标）

private struct MacrosPlannerToolView: View {
    @EnvironmentObject private var store: AppStore
    @State private var goal: Goal = .cut
    @State private var applied = false

    private var previewProfile: Profile {
        var p = store.state.profile
        p.goal = goal
        return p
    }

    var body: some View {
        let p = previewProfile
        let kcal = p.kcalTarget
        let protein = p.proteinTarget
        let fat = Int((Double(kcal) * 0.27 / 9.0).rounded())
        let carbs = max(60, Int((Double(kcal - protein * 4 - fat * 9) / 4.0).rounded()))

        VStack(spacing: 16) {
            Picker("目标", selection: $goal) {
                ForEach(Goal.allCases) { g in Text(g.rawValue).tag(g) }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                StatTile(value: "\(kcal)", label: "千卡 / 天", tint: Palette.amber)
                StatTile(value: "\(protein) g", label: "蛋白质", tint: Palette.green)
            }
            HStack(spacing: 10) {
                StatTile(value: "\(carbs) g", label: "碳水化合物", tint: Palette.blue)
                StatTile(value: "\(fat) g", label: "脂肪", tint: Palette.amber)
            }

            Spacer()

            PrimaryButton(title: applied ? "已设为每日营养目标 ✓" : "一键设为每日目标", tint: Palette.green) {
                store.state.profile.goal = goal
                store.state.profile.dailyKcalGoal = kcal
                applied = true
            }
        }
        .padding(Metrics.page)
        .onAppear { goal = store.state.profile.goal }
    }
}

// MARK: - 9. 跑步水印 / 玻璃水印 / 带壳截图生成器（ImageRenderer 出图）

private struct WatermarkStudioToolView: View {
    @EnvironmentObject private var store: AppStore
    let mode: PluginInteractionKind

    @State private var pickerItem: PhotosPickerItem?
    @State private var bgImage: UIImage?
    @State private var showShare = false
    @State private var exportedImage: UIImage?

    private var latestRun: RouteRun? { store.state.runs.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                artworkCanvas
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 14, weight: .semibold))
                        Text("选一张底图照片")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .foregroundStyle(Palette.text)
                    .background(Capsule().fill(Palette.cardHigh))
                    .overlay(Capsule().strokeBorder(Palette.strokeHi, lineWidth: 1))
                }
                .onChange(of: pickerItem) { _, item in
                    Task {
                        if let item, let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                            bgImage = img
                        }
                    }
                }

                PrimaryButton(title: "导出分享图片", tint: Palette.lime) {
                    let renderer = ImageRenderer(content: artworkCanvas.frame(width: 340, height: 340))
                    renderer.scale = 3
                    if let uiImage = renderer.uiImage {
                        exportedImage = uiImage
                        showShare = true
                    }
                }
            }
            .padding(Metrics.page)
        }
        .sheet(isPresented: $showShare) {
            if let exportedImage {
                ShareSheet(items: [exportedImage])
                    .strideSheetDetents([.medium, .large])
            }
        }
    }

    @ViewBuilder
    private var artworkCanvas: some View {
        let km = String(format: "%.2f km", (latestRun?.distanceM ?? 5200) / 1000)
        let pace = latestRun.map { $0.paceSecPerKm > 0 ? PluginMath.formatPace($0.paceSecPerKm) : "5′18″/km" } ?? "5′18″/km"

        ZStack {
            if let bgImage {
                Image(uiImage: bgImage)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color(hex: 0x16241D), Color(hex: 0x0C1017)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            if case .deviceFrame = mode {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.85), lineWidth: 5)
                    .padding(14)
                    .overlay(alignment: .top) {
                        Capsule().fill(Color.black).frame(width: 72, height: 18).padding(.top, 22)
                    }
            }

            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Brand.name)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Palette.lime)
                        Text(km)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white)
                        Text("\(pace) · \(latestRun?.title ?? "晨跑")")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                    Spacer()
                    if let pts = latestRun?.points, !pts.isEmpty {
                        RouteArtView(points: pts, style: .neon, lineWidth: 2.2, showsBaseline: false)
                            .frame(width: 74, height: 64)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.52))
                )
                .padding(16)
            }
        }
    }
}
