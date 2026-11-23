import SwiftUI

/// 智能耳机陪伴与护颈控制中心：
/// - 6 款全型号 3D PBR 交互展示舞台（实时跟随抬头/低头/转头）
/// - 每日陪伴时长 + 累计总陪伴时长 + 近 7 天趋势与型号分布
/// - 低头角度判断 + 自定义超时时间 + 手机弹窗/语音/震动提醒
/// - 训练中「点头完成本组」与「摇头推荐功能 4 选 1」
struct HeadphoneCompanionView: View {
    @EnvironmentObject private var headphone: HeadphoneMotionManager
    @Environment(\.dismiss) private var dismiss

    @State private var toast: String?
    @State private var showSimulatorDebug = false
    @Namespace private var headphoneModelNS

    private let timeoutPresets: [(label: String, sec: TimeInterval)] = [
        ("15秒(测试)", 15),
        ("30秒", 30),
        ("1分钟", 60),
        ("3分钟", 180),
        ("5分钟", 300)
    ]

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    heroStageCard
                    companionDurationCard
                    postureMonitorCard
                    headGestureCard
                }
                .padding(.horizontal, Metrics.page)
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("智能耳机 · 护颈与 3D")
        .navigationBarTitleDisplayMode(.inline)
        .toast($toast)
        .onAppear {
            headphone.refreshNotificationAuthorization()
        }
        .onChange(of: headphone.lastReminderBannerText) { _, newText in
            if let newText {
                toast = newText
            }
        }
    }

    // MARK: - 1. 顶部 3D 展示舞台与型号选择

    private var heroStageCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(headphone.isHeadphoneConnected ? Palette.green : Palette.amber)
                    .frame(width: 8, height: 8)
                Text(headphone.isHeadphoneConnected ? headphone.connectedDeviceName : "预览模式 · \(headphone.activeModel.displayName)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                Spacer()
                Text(statusBadgeText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(statusColor.opacity(0.16)))
            }

            ZStack(alignment: .bottomLeading) {
                Headphone3DModelView(
                    model: headphone.activeModel,
                    maxColor: headphone.airPodsMaxColor,
                    pitchDeg: headphone.livePitchDeg,
                    yawDeg: headphone.liveYawDeg,
                    rollDeg: headphone.liveRollDeg,
                    isHeadDownWarning: headphone.alertLevel != .upright
                )
                .frame(height: 230)
                .frame(maxWidth: .infinity)
                .background(
                    RadialGradient(
                        colors: [
                            (headphone.alertLevel != .upright ? Palette.coralHi : Palette.blue).opacity(0.16),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: 150
                    )
                )

                HStack(spacing: 8) {
                    Label(
                        String(format: "俯仰 %+.0f°", headphone.livePitchDeg),
                        systemImage: headphone.livePitchDeg >= headphone.headDownAngleThresholdDeg ? "arrow.down.forward.circle.fill" : "figure.stand"
                    )
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(headphone.alertLevel == .upright ? Palette.textDim : statusColor)
                    .numericRoll(value: Int(headphone.livePitchDeg.rounded()))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.55)))

                    if headphone.continuousHeadDownSec > 0 {
                        Text("已低头 \(Int(headphone.continuousHeadDownSec))s / \(Int(headphone.headDownTimeoutSec))s")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(statusColor)
                            .numericRoll(value: Int(headphone.continuousHeadDownSec))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.black.opacity(0.55)))
                    }

                    Spacer()

                    Text("可拖动 360° 旋转")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.textFaint)
                }
                .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Palette.stroke, lineWidth: 0.8)
            )

            // 6 款耳机型号横向磁吸切换条
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HeadphoneModelKind.allCases) { kind in
                        let selected = headphone.activeModel == kind
                        Button {
                            if headphone.activeModel != kind {
                                headphone.selectDisplayModel(kind)
                                StrideHaptics.shared.selection()
                            }
                        } label: {
                            Text(kind.displayName)
                                .font(.system(size: 12, weight: selected ? .bold : .medium))
                                .foregroundStyle(selected ? Color.black : Palette.textDim)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule().fill(selected ? Color.white : Palette.cardHigh)
                                )
                        }
                        .buttonStyle(.stridePress)
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: headphone.activeModel)

            if headphone.activeModel == .airPodsMax {
                HStack(spacing: 10) {
                    Text("AirPods Max 配色")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.textDim)
                    Spacer()
                    ForEach(AirPodsMaxColor.allCases) { color in
                        let rgb = color.rgb
                        let selected = headphone.airPodsMaxColor == color
                        Button {
                            headphone.selectMaxColor(color)
                        } label: {
                            Circle()
                                .fill(Color(red: rgb.r, green: rgb.g, blue: rgb.b))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle().strokeBorder(selected ? Color.white : Color.white.opacity(0.25), lineWidth: selected ? 2.2 : 0.8)
                                )
                                .scaleEffect(selected ? 1.12 : 1.0)
                        }
                        .buttonStyle(.stridePress)
                    }
                }
                .padding(.top, 2)
            } else {
                Text(headphone.activeModel.subtitleZH)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.textFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    private var statusBadgeText: String {
        switch headphone.alertLevel {
        case .upright:
            return headphone.isMotionTrackingActive ? "追踪中 · 正常" : "待机就绪"
        case .warningHeadDown:
            return "正在低头"
        case .timeoutAlerted:
            return "低头超时"
        }
    }

    private var statusColor: Color {
        switch headphone.alertLevel {
        case .upright: return Palette.green
        case .warningHeadDown: return Palette.amber
        case .timeoutAlerted: return Palette.coralHi
        }
    }

    // MARK: - 2. 每日陪伴时长与总陪伴时长看板

    private var companionDurationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("耳机陪伴时长", systemImage: "headphones")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text("连续 \(headphone.streakDays) 天")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.greenText)
                    .numericRoll(value: headphone.streakDays)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Palette.greenDeep))
            }

            HStack(spacing: 10) {
                statBox(
                    title: "今日陪伴",
                    value: HeadphoneCompanionStore.formatDuration(headphone.todayCompanionSec),
                    rollKey: Int(headphone.todayCompanionSec),
                    tint: Palette.green
                )
                statBox(
                    title: "累计总陪伴",
                    value: HeadphoneCompanionStore.formatDuration(headphone.totalCompanionSec),
                    rollKey: Int(headphone.totalCompanionSec),
                    tint: Palette.blue
                )
                statBox(
                    title: "今日低头提醒",
                    value: "\(headphone.todayHeadDownAlertCount) 次",
                    rollKey: headphone.todayHeadDownAlertCount,
                    tint: Palette.amber
                )
            }

            // 近 7 天陪伴柱状图（支持长按滑动拾取每日时长）
            VStack(alignment: .leading, spacing: 6) {
                Text("近 7 天陪伴趋势")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Palette.textDim)

                InteractiveBarChartScrubber(
                    items: headphone.recent7Days,
                    valueProvider: \.seconds,
                    labelProvider: \.label,
                    valueTextProvider: { HeadphoneCompanionStore.formatDuration($0.seconds) },
                    barColor: Palette.blue,
                    height: 92
                )
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.cardSoft))
        }
        .padding(15)
        .luxuryCard(radius: 22, accent: Palette.blue)
    }

    private func statBox(title: String, value: String, rollKey: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10.5))
                .foregroundStyle(Palette.textDim)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .numericRoll(value: rollKey)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.cardHigh))
    }

    // MARK: - 3. 抬头/低头监测与超时提醒设置

    private var postureMonitorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("低头护颈监测与提醒", systemImage: "figure.mind.and.body")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { headphone.isPostureMonitorEnabled },
                    set: { headphone.setPostureMonitor(enabled: $0) }
                ))
                .labelsHidden()
                .tint(Palette.green)
            }

            if !headphone.notificationGranted {
                HStack(spacing: 10) {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(Palette.amber)
                    Text("开启通知权限后，低头超时可在手机锁屏/前台弹窗提醒")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.textDim)
                    Spacer()
                    Button("去授权") {
                        headphone.requestNotificationPermission()
                    }
                    .buttonStyle(.stridePress)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Palette.amber))
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.amber.opacity(0.12)))
            }

            // 低头判断角度滑块
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("判定低头角度阈值")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.text)
                    Spacer()
                    Text("\(Int(headphone.headDownAngleThresholdDeg.rounded()))° 以上算低头")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.blue)
                        .numericRoll(value: Int(headphone.headDownAngleThresholdDeg.rounded()))
                }
                Slider(value: $headphone.headDownAngleThresholdDeg, in: 12...38, step: 1)
                    .tint(Palette.blue)
            }

            // 连续低头超时阈值
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("超出低头时长提醒")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.text)
                    Spacer()
                    Text("超过 \(Int(headphone.headDownTimeoutSec)) 秒提醒")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.amber)
                        .numericRoll(value: Int(headphone.headDownTimeoutSec))
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(timeoutPresets, id: \.sec) { preset in
                            let selected = Int(headphone.headDownTimeoutSec) == Int(preset.sec)
                            Button {
                                headphone.headDownTimeoutSec = preset.sec
                            } label: {
                                Text(preset.label)
                                    .font(.system(size: 12, weight: selected ? .bold : .medium))
                                    .foregroundStyle(selected ? Color.black : Palette.textDim)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(selected ? Palette.amber : Palette.cardHigh))
                            }
                            .buttonStyle(.stridePress)
                        }
                    }
                }
            }

            Toggle(isOn: $headphone.voiceReminderEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("超时轻语音播报提醒")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(Palette.text)
                    Text("通过耳机轻声播报「请抬头放松颈椎」")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textFaint)
                }
            }
            .tint(Palette.green)

            HStack(spacing: 10) {
                Button {
                    headphone.calibrateUprightZero()
                    toast = "已把当前头部姿态设为 0° 正坐标准"
                } label: {
                    Label("校准当前坐姿 0°", systemImage: "scope")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Palette.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.cardHigh))
                }
                .buttonStyle(.strideSpin)

                Button {
                    headphone.triggerTestAlert()
                } label: {
                    Label("立即测试手机提醒", systemImage: "bell.and.waves.left.and.right")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.green))
                }
                .buttonStyle(.strideShimmer(glow: Palette.green))
            }

            // 无耳机传感器的调试模拟滑块
            Button {
                withAnimation(.snappy(duration: 0.2)) { showSimulatorDebug.toggle() }
            } label: {
                HStack {
                    Text(showSimulatorDebug ? "收起 3D 姿态与低头测试滑块" : "无传感器时手动测试 3D 随动与低头计时")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Palette.blue)
                    Spacer()
                    Image(systemName: showSimulatorDebug ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.blue)
                }
                .padding(.top, 2)
            }
            .buttonStyle(.stridePress)

            if showSimulatorDebug {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("模拟俯仰低头角度")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textDim)
                        Spacer()
                        Text(String(format: "%+.0f°", headphone.simulatedPitchDeg))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.text)
                    }
                    Slider(
                        value: Binding(
                            get: { headphone.simulatedPitchDeg },
                            set: { headphone.applySimulatedAngle(pitchDeg: $0) }
                        ),
                        in: -20...45,
                        step: 1
                    )
                    .tint(Palette.coralHi)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.cardSoft))
            }
        }
        .padding(15)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 4. 训练头控交互（点头完成本组 + 摇头推荐功能）

    private var headGestureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("训练头控交互", systemImage: "airpodspro")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.text)

            Toggle(isOn: $headphone.nodToCompleteSetEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("点头（2 下）完成本组")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.text)
                    Text("训练中双手负重时，轻点两下头自动打卡本组并启动休息倒计时")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.textDim)
                }
            }
            .tint(Palette.green)

            Divider().overlay(Palette.stroke)

            VStack(alignment: .leading, spacing: 8) {
                Text("摇头（2 下）功能分配")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Palette.text)

                ForEach(HeadphoneShakeAction.allCases) { option in
                    let selected = headphone.shakeAction == option
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            headphone.shakeAction = option
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: option.sfSymbol)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(selected ? Palette.green : Palette.textDim)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(selected ? Palette.green.opacity(0.18) : Palette.cardHigh))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.titleZH)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Palette.text)
                                Text(option.detailZH)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Palette.textDim)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 17))
                                .foregroundStyle(selected ? Palette.green : Palette.strokeHi)
                        }
                        .padding(11)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selected ? Palette.greenDeep.opacity(0.45) : Palette.cardHigh.opacity(0.6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(selected ? Palette.green.opacity(0.6) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.stridePress)
                }
            }

            HStack(spacing: 10) {
                Button {
                    headphone.triggerTestNod()
                    toast = "已模拟：点头 2 下（完成本组）"
                } label: {
                    Text("测试点头")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Palette.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.cardHigh))
                }
                .buttonStyle(.stridePress)

                Button {
                    headphone.triggerTestShake()
                    toast = "已模拟：摇头 2 下（\(headphone.shakeAction.titleZH)）"
                } label: {
                    Text("测试摇头")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Palette.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.cardHigh))
                }
                .buttonStyle(.stridePress)
            }
        }
        .padding(15)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }
}
