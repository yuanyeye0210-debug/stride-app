import SwiftUI

/// Apple Watch 6 轴动作识别模型与自动计次工作台：
/// - 实时展示端侧 11 类神经网络（10 动作 + 静息）分类与置信度
/// - 自动周期峰谷计次（每做 1 个自动 +1 并同步到训练组）
/// - 支持「手表实时同步 / iPhone 握持 50Hz 实测 / 6 轴波形模拟」与个人动作录制微调
struct WatchMotionStudioView: View {
    @EnvironmentObject private var watch: WatchSession
    @EnvironmentObject private var watchMotion: WatchMotionSessionController

    @State private var toast: String?
    @State private var showWatchInstallNote = false

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    connectionHeaderCard
                    liveRecognitionCard
                    modeAndSimulatorCard
                    calibrationWorkshopCard
                    watchDeploymentCard
                }
                .padding(.horizontal, Metrics.page)
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("手表动作识别与计次")
        .navigationBarTitleDisplayMode(.inline)
        .toast($toast)
    }

    // MARK: - 1. 模型与手表连接概况

    private var connectionHeaderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "applewatch.watchface")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Palette.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("端侧 6 轴动作识别模型")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.text)
                        Text(watchMotion.modelVersionText)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.textDim)
                    }
                }
                Spacer()
                Text(watch.reachable ? "Watch 在线" : "手机端就绪")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(watch.reachable ? Palette.greenText : Palette.blue)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill((watch.reachable ? Palette.green : Palette.blue).opacity(0.18)))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(WatchExerciseClass.trainableExercises) { item in
                        let isActive = watchMotion.currentExercise == item
                        Text(item.nameZH)
                            .font(.system(size: 11, weight: isActive ? .bold : .medium))
                            .foregroundStyle(isActive ? Color.black : Palette.textDim)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(isActive ? Palette.green : Palette.cardHigh))
                    }
                }
            }
        }
        .padding(15)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 2. 实时识别动作 + 超大自动计次卡 + 6 轴波形

    private var liveRecognitionCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前识别动作")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Palette.textDim)
                    HStack(spacing: 8) {
                        Image(systemName: watchMotion.currentExercise.sfSymbol)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(watchMotion.currentExercise.isActiveExercise ? Palette.green : Palette.textDim)
                        Text(watchMotion.currentExercise.nameZH)
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundStyle(Palette.text)
                    }
                    HStack(spacing: 8) {
                        Text("置信度 \(Int((watchMotion.confidence * 100).rounded()))%")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.greenText)
                            .numericRoll(value: Int((watchMotion.confidence * 100).rounded()))
                        if watchMotion.lastTempoSec > 0 {
                            Text("· 节奏 \(String(format: "%.1fs/次", watchMotion.lastTempoSec))")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Palette.textDim)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("自动计次")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.textDim)
                    ZStack {
                        RadarPulseRing(color: Palette.lime, isActive: watchMotion.isRunning, size: 62)
                        ConfettiBurstView(trigger: watchMotion.repCount, colors: [Palette.lime, Palette.green, Palette.cyan])
                        Text("\(watchMotion.repCount)")
                            .font(.system(size: 46, weight: .black, design: .rounded))
                            .foregroundStyle(Palette.lime)
                            .numericRoll(value: watchMotion.repCount)
                    }
                }
            }
            .sensoryFeedback(.impact(weight: .heavy), trigger: watchMotion.repCount)

            // 置信度进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.cardHigh)
                    Capsule()
                        .fill(LinearGradient(colors: [Palette.green, Palette.lime], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * min(1, watchMotion.confidence)))
                }
            }
            .frame(height: 6)

            // 实时 6 轴加速度合成波形预览
            imuWaveformChart
                .frame(height: 58)

            HStack(spacing: 10) {
                Button {
                    if watchMotion.isRunning {
                        watchMotion.stop()
                    } else {
                        watchMotion.start()
                    }
                } label: {
                    Label(
                        watchMotion.isRunning ? "停止识别与计次" : "开始自动识别计次",
                        systemImage: watchMotion.isRunning ? "stop.fill" : "play.fill"
                    )
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(watchMotion.isRunning ? Color.white : Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(watchMotion.isRunning ? Palette.coralHi : Palette.green)
                    )
                }
                .buttonStyle(.strideShimmer(glow: watchMotion.isRunning ? Palette.coralHi : Palette.green))

                Button {
                    watchMotion.resetReps()
                    toast = "计次已清零"
                } label: {
                    Text("清零")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.cardHigh))
                }
                .buttonStyle(.strideSpin)
            }
        }
        .padding(16)
        .luxuryCard(radius: 22, accent: Palette.green)
    }

    private var imuWaveformChart: some View {
        GeometryReader { geo in
            let pts = watchMotion.recentAccelWave
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.cardSoft)
                if pts.count > 1 {
                    Path { path in
                        let w = geo.size.width
                        let h = geo.size.height
                        let mid = h * 0.5
                        let step = w / CGFloat(pts.count - 1)
                        for (i, val) in pts.enumerated() {
                            let y = mid - CGFloat(max(-1.0, min(1.0, val))) * (h * 0.42)
                            let x = CGFloat(i) * step
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Palette.cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    // MARK: - 3. 信号源模式与模拟动作验证

    private var modeAndSimulatorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("传感器信号来源")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Palette.text)

            Picker("信号源", selection: $watchMotion.sourceMode) {
                ForEach(WatchMotionSourceMode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: watchMotion.sourceMode) { _, newMode in
                if watchMotion.isRunning {
                    watchMotion.start(mode: newMode)
                }
            }

            if watchMotion.sourceMode == .simulator {
                HStack {
                    Text("选择模拟演示动作")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.textDim)
                    Spacer()
                    Picker("模拟动作", selection: $watchMotion.simulatedExercise) {
                        ForEach(WatchExerciseClass.allCases) { item in
                            Text(item.nameZH).tag(item)
                        }
                    }
                    .tint(Palette.green)
                }
                .padding(.top, 2)
            } else if watchMotion.sourceMode == .phoneHandheld {
                Text("手持 iPhone 模拟腕部做哑铃弯举/卧推/深蹲，手机 50Hz IMU 会直接喂给同一端侧识别与计次模型。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.textDim)
            } else {
                Text("当 Apple Watch 运行 StrideWatch 并开始动作后，手表端识别出的动作与每次自动计次会毫秒级同步到这里和训练记录卡。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.textDim)
            }
        }
        .padding(15)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 4. 个人动作采集校准工坊

    private var calibrationWorkshopCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("个人发力原型校准（越用越准）", systemImage: "waveform.path.ecg")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(Palette.text)
                Spacer()
                if !watchMotion.calibratedClasses.isEmpty {
                    Button("清空校准") {
                        watchMotion.clearCalibration()
                        toast = "已重置为出厂通用模型"
                    }
                    .buttonStyle(.stridePress)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Palette.coralHi)
                }
            }

            Text("每个人握距、左右手习惯不同。选定动作点击录制 3 秒标准发力，端侧会把你的个人惯性原型与神经网络融合。")
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.textDim)

            HStack {
                Picker("校准目标", selection: $watchMotion.calibrationTarget) {
                    ForEach(WatchExerciseClass.trainableExercises) { item in
                        Text(item.nameZH).tag(item)
                    }
                }
                .tint(Palette.text)

                Spacer()

                Button {
                    watchMotion.startQuickCalibration(for: watchMotion.calibrationTarget)
                    toast = "正在采集「\(watchMotion.calibrationTarget.nameZH)」3 秒特征..."
                } label: {
                    Text(watchMotion.isCalibrating ? "采集中 \(Int(watchMotion.calibrationProgress * 100))%" : "录制校准样本")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(watchMotion.isCalibrating ? Palette.amber : Palette.blue))
                }
                .buttonStyle(.stridePress)
                .disabled(watchMotion.isCalibrating)
            }

            if !watchMotion.calibratedClasses.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(watchMotion.calibratedClasses.sorted(), id: \.self) { raw in
                            let label = WatchExerciseClass(rawValue: raw)?.nameZH ?? raw
                            Label("\(label) 已校准", systemImage: "checkmark.seal.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Palette.greenText)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Palette.greenDeep))
                        }
                    }
                }
            }
        }
        .padding(15)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 5. 免费签名说明与 Watch 独立工程提示

    private var watchDeploymentCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy(duration: 0.2)) { showWatchInstallNote.toggle() }
            } label: {
                HStack {
                    Label("Apple Watch 装表与源码说明", systemImage: "info.circle")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Palette.textDim)
                    Spacer()
                    Image(systemName: showWatchInstallNote ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textFaint)
                }
            }
            .buttonStyle(.stridePress)

            if showWatchInstallNote {
                Text("为确保免费 Apple ID + Sideloadly 能顺利装入 iPhone，默认安装包保持纯净单 Target。仓库 `ios/StrideWatch/` 与 `ios/project-with-watch.yml` 中已为你提供完整 watchOS 端源码与 `ml/watch_exercise_model/` 训练脚本；若日后改用付费开发者账号或 Mac Xcode，可直接编译安装到手表上自动计次并震动反馈。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .card(radius: 18, fill: Palette.cardSoft, stroke: Palette.stroke)
    }
}
