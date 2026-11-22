import SwiftUI

// MARK: - 正反面人体肌群覆盖热力图（交互式）

struct MuscleBodyHeatmapCard: View {
    let sessions: [WorkoutSession]

    @State private var selectedGroup: MuscleGroup? = .chest

    private var weeklySets: [MuscleGroup: Int] {
        ProgressiveEngine.weeklySetBalance(sessions: sessions)
    }

    private func heatColor(for group: MuscleGroup) -> Color {
        let count = weeklySets[group] ?? 0
        switch count {
        case 0: return Color.white.opacity(0.14)
        case 1...5: return Palette.blue.opacity(0.72)
        case 6...11: return Palette.green.opacity(0.88)
        case 12...17: return Palette.amber.opacity(0.90)
        default: return Palette.coralHi.opacity(0.92)
        }
    }

    private func loadLabel(for count: Int) -> String {
        switch count {
        case 0: return "本周未练"
        case 1...5: return "轻度刺激"
        case 6...11: return "黄金容量"
        case 12...17: return "高负荷"
        default: return "极高负荷 · 注意恢复"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("全身肌群热力图")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Palette.text)
                    Text("近 7 天肌群训练覆盖 · 点击任意部位查看详情")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.textDim)
                }
                Spacer()
                legendRow
            }

            HStack(spacing: 12) {
                figureColumn(title: "正面") {
                    frontBodyFigure
                }
                figureColumn(title: "背面") {
                    backBodyFigure
                }
            }
            .sensoryFeedback(.selection, trigger: selectedGroup)

            if let group = selectedGroup {
                let sets = weeklySets[group] ?? 0
                HStack(spacing: 12) {
                    Circle()
                        .fill(heatColor(for: group))
                        .frame(width: 12, height: 12)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(group.rawValue) · \(loadLabel(for: sets))")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(Palette.text)
                        Text("近 7 天累计完成 \(sets) 组有效训练（建议周容量 8–16 组）")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.textDim)
                    }
                    Spacer()
                    Text("\(sets) 组")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(group.tint)
                        .numericRoll(value: sets)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.cardSoft))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(16)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    private var legendRow: some View {
        HStack(spacing: 4) {
            ForEach([Color.white.opacity(0.16), Palette.blue, Palette.green, Palette.amber, Palette.coralHi], id: \.self) { c in
                RoundedRectangle(cornerRadius: 2)
                    .fill(c)
                    .frame(width: 10, height: 6)
            }
        }
    }

    private func figureColumn<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 6) {
            content()
                .frame(height: 185)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.cardSoft.opacity(0.65)))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.textFaint)
        }
    }

    // MARK: - 正面人体肌肉块

    private var frontBodyFigure: some View {
        VStack(spacing: 3) {
            // 头颈
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 22, height: 22)

            // 肩 + 胸 + 手臂
            HStack(spacing: 3) {
                muscleButton(.arms, width: 12, height: 42, radius: 6) // 左臂
                VStack(spacing: 3) {
                    HStack(spacing: 4) {
                        muscleButton(.shoulders, width: 16, height: 14, radius: 5)
                        muscleButton(.chest, width: 34, height: 22, radius: 6)
                        muscleButton(.shoulders, width: 16, height: 14, radius: 5)
                    }
                    // 核心腹肌
                    muscleButton(.core, width: 32, height: 34, radius: 7)
                }
                muscleButton(.arms, width: 12, height: 42, radius: 6) // 右臂
            }

            // 下肢股四 + 小腿
            HStack(spacing: 8) {
                VStack(spacing: 3) {
                    muscleButton(.legs, width: 16, height: 42, radius: 7)
                    muscleButton(.legs, width: 13, height: 28, radius: 6)
                }
                VStack(spacing: 3) {
                    muscleButton(.legs, width: 16, height: 42, radius: 7)
                    muscleButton(.legs, width: 13, height: 28, radius: 6)
                }
            }
        }
    }

    // MARK: - 背面人体肌肉块

    private var backBodyFigure: some View {
        VStack(spacing: 3) {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 22, height: 22)

            HStack(spacing: 3) {
                muscleButton(.arms, width: 12, height: 42, radius: 6) // 三头
                VStack(spacing: 3) {
                    HStack(spacing: 4) {
                        muscleButton(.shoulders, width: 15, height: 14, radius: 5) // 后束
                        muscleButton(.back, width: 36, height: 34, radius: 7) // 背阔/上背
                        muscleButton(.shoulders, width: 15, height: 14, radius: 5)
                    }
                    // 下背核心
                    muscleButton(.core, width: 28, height: 22, radius: 6)
                }
                muscleButton(.arms, width: 12, height: 42, radius: 6)
            }

            // 臀部 + 腘绳肌 + 小腿
            HStack(spacing: 8) {
                VStack(spacing: 3) {
                    muscleButton(.legs, width: 17, height: 18, radius: 7)
                    muscleButton(.legs, width: 15, height: 28, radius: 6)
                    muscleButton(.legs, width: 13, height: 24, radius: 6)
                }
                VStack(spacing: 3) {
                    muscleButton(.legs, width: 17, height: 18, radius: 7)
                    muscleButton(.legs, width: 15, height: 28, radius: 6)
                    muscleButton(.legs, width: 13, height: 24, radius: 6)
                }
            }
        }
    }

    private func muscleButton(_ group: MuscleGroup, width: CGFloat, height: CGFloat, radius: CGFloat) -> some View {
        let isSelected = selectedGroup == group
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                selectedGroup = group
            }
        } label: {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(heatColor(for: group))
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Color.white.opacity(isSelected ? 0.95 : 0.0), lineWidth: 1.5)
                )
                .scaleEffect(isSelected ? 1.06 : 1.0)
        }
        .buttonStyle(.stridePress)
    }
}

// MARK: - 单动作历史 e1RM 成长折线图

struct ExerciseOneRMTrendCard: View {
    @EnvironmentObject private var store: AppStore

    private let trackedNames = ["卧推", "深蹲", "硬拉", "站姿推举", "引体向上", "杠铃划船"]
    @State private var selectedExercise = "卧推"
    @State private var tappedIndex: Int? = nil

    private var availableNames: [String] {
        let dynamic = Set(store.state.sessions.flatMap { $0.exercises.map(\.name) })
        let merged = trackedNames.filter { name in
            dynamic.contains(where: { $0.contains(name) })
        }
        if !merged.isEmpty { return merged }
        let fallback = Array(dynamic.prefix(6)).sorted()
        return fallback.isEmpty ? trackedNames : fallback
    }

    private var points: [(date: Date, e1rm: Double)] {
        let query = selectedExercise
        return store.state.sessions
            .sorted { $0.date < $1.date }
            .compactMap { s -> (Date, Double)? in
                let best = s.exercises
                    .filter { $0.name.localizedCaseInsensitiveContains(query) }
                    .flatMap(\.doneSets)
                    .map { ProgressiveEngine.e1RM(weight: $0.weight, reps: $0.reps) }
                    .max() ?? 0
                return best > 0 ? (s.date, best) : nil
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("单动作 1RM 趋势")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Palette.text)
                    Text("按估算极限重量追踪力量增长")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.textDim)
                }
                Spacer()
                if let latest = points.last {
                    Text("\(Int(latest.e1rm.rounded())) kg")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.green)
                        .numericRoll(value: latest.e1rm)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(availableNames, id: \.self) { name in
                        let on = selectedExercise == name
                        Button {
                            withAnimation(.snappy(duration: 0.22)) {
                                selectedExercise = name
                                tappedIndex = nil
                            }
                        } label: {
                            Text(name)
                                .font(.system(size: 12, weight: on ? .bold : .medium))
                                .foregroundStyle(on ? Color.black : Palette.textDim)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(on ? Color.white : Palette.cardSoft))
                        }
                        .buttonStyle(.stridePress)
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: selectedExercise)

            if points.count < 2 {
                Text(points.isEmpty ? "暂无「\(selectedExercise)」的完成记录。" : "记录 2 次以上即可绘制「\(selectedExercise)」1RM 成长折线。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.textFaint)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            } else {
                chartArea
                    .frame(height: 145)
            }
        }
        .padding(16)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
        .onAppear {
            if !availableNames.contains(selectedExercise), let first = availableNames.first {
                selectedExercise = first
            }
        }
    }

    private var chartArea: some View {
        let minVal = (points.map(\.e1rm).min() ?? 0) * 0.92
        let maxVal = max(minVal + 5, (points.map(\.e1rm).max() ?? 100) * 1.05)

        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height - 20
            let stepX = w / CGFloat(max(1, points.count - 1))

            ZStack(alignment: .topLeading) {
                Path { path in
                    for (idx, pt) in points.enumerated() {
                        let x = CGFloat(idx) * stepX
                        let ratio = (pt.e1rm - minVal) / max(1, maxVal - minVal)
                        let y = h - CGFloat(ratio) * h
                        if idx == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Palette.green, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                ForEach(Array(points.enumerated()), id: \.offset) { idx, pt in
                    let x = CGFloat(idx) * stepX
                    let ratio = (pt.e1rm - minVal) / max(1, maxVal - minVal)
                    let y = h - CGFloat(ratio) * h
                    let active = tappedIndex == idx

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            tappedIndex = active ? nil : idx
                        }
                    } label: {
                        Circle()
                            .fill(active ? Color.white : Palette.green)
                            .frame(width: active ? 11 : 8, height: active ? 11 : 8)
                            .overlay(Circle().strokeBorder(Color.black, lineWidth: 1.5))
                    }
                    .buttonStyle(.stridePress)
                    .position(x: x, y: y)

                    if active || idx == points.count - 1 && tappedIndex == nil {
                        Text("\(Int(pt.e1rm.rounded()))kg")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.white))
                            .position(x: min(max(24, x), w - 24), y: max(12, y - 16))
                    }
                }
            }
        }
    }
}
