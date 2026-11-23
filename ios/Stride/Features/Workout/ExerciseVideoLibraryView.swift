import SwiftUI

// MARK: - 动作视频库总览页（支持计划页内嵌 & 弹窗选动作双重模式）

struct ExerciseVideoLibraryView: View {
    @Environment(\.dismiss) private var dismiss

    /// 非 nil 时表示从「开始训练 / 添加动作」弹窗进入，点击或详情底部的按钮可直接加入训练。
    var onPick: ((Exercise) -> Void)? = nil
    /// 是否内嵌于顶部悬浮胶囊栏下方（需要预留顶部安全距离与底部 tab 栏空间）。
    var embeddedInPlanHub: Bool = false

    @State private var query = ""
    @State private var selectedBodyPart: String? = nil
    @State private var selectedEquipment: String? = nil
    @State private var detailExercise: CatalogExercise?
    @State private var startSessionDraft: SessionDraft?

    @Namespace private var partNS

    private let catalog = ExerciseCatalogStore.shared

    private var filtered: [CatalogExercise] {
        catalog.filter(
            query: query,
            bodyPart: selectedBodyPart,
            equipment: selectedEquipment
        )
    }

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if embeddedInPlanHub {
                        headerSummary
                    }

                    searchBar
                    bodyPartFilterBar
                    equipmentFilterBar

                    resultsCountBar

                    if filtered.isEmpty {
                        EmptyHint(
                            icon: "magnifyingglass",
                            title: "没有匹配的动作",
                            message: "试试搜中文/英文动作名（如 卧推、深蹲、bench）或切换上方的部位与器械筛选。"
                        )
                        .padding(.top, 24)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filtered) { item in
                                exerciseRow(item)
                                    .strideScrollDepth(minScale: 0.96, minOpacity: 0.88)
                            }
                        }

                        Text("720p 真人视频来源 CC0 公共领域 · 肌群解剖图由 RepDB (repdb.co) 提供")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.textFaint)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, Metrics.page)
                .padding(.top, embeddedInPlanHub ? 62 : 12)
                .padding(.bottom, embeddedInPlanHub ? Metrics.floatingTabBottomInset + 20 : 28)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(item: $detailExercise) { item in
            ExerciseVideoDetailSheet(
                exercise: item,
                pickMode: onPick != nil,
                onPickOrStart: {
                    let converted = item.toExercise()
                    if let onPick {
                        onPick(converted)
                        detailExercise = nil
                        dismiss()
                    } else {
                        detailExercise = nil
                        startSessionDraft = SessionDraft(
                            title: converted.name,
                            kind: converted.group == .cardio ? .run : .strength,
                            exercises: [
                                LoggedExercise(
                                    exerciseID: converted.id,
                                    name: converted.name,
                                    group: converted.group,
                                    isTimed: converted.isTimed,
                                    restSec: 90,
                                    sets: (0..<3).map { _ in
                                        SetEntry(weight: 0, reps: converted.isTimed ? 0 : 10, seconds: converted.isTimed ? 45 : 0)
                                    }
                                )
                            ]
                        )
                    }
                }
            )
            .strideSheetDetents([.large])
        }
        .sheet(item: $startSessionDraft) { draft in
            SessionView(draft: draft)
        }
    }

    // MARK: - 顶部标题与搜索

    private var headerSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("动作视频库")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text("\(catalog.all.count) 个真人视频")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Palette.green.opacity(0.14)))
            }
            Text("精选核心力量与拉伸动作 · 全员 720p 真人循环视频（支持 0.5× 慢放）")
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.textDim)
        }
        .padding(.top, 4)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.textDim)
            TextField("搜中文部位/器械或英文名（如 卧推、胸、dumbbell）", text: $query)
                .font(.system(size: 14))
                .foregroundStyle(Palette.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.textFaint)
                }
                .buttonStyle(.stridePress)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.stroke, lineWidth: 1))
    }

    // MARK: - 部位 & 器械筛选

    private var bodyPartFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                partChip(title: "全部部位", value: nil)
                ForEach(catalog.availableBodyParts, id: \.self) { part in
                    partChip(title: CatalogExercise.bodyPartName(part), value: part)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectedBodyPart)
    }

    private func partChip(title: String, value: String?) -> some View {
        let active = selectedBodyPart == value
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                selectedBodyPart = value
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: active ? .semibold : .medium))
                .foregroundStyle(active ? Color.black : Palette.textDim)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background {
                    if active {
                        Capsule()
                            .fill(Color.white)
                            .matchedGeometryEffect(id: "exercisePartChip", in: partNS)
                    } else {
                        Capsule()
                            .fill(Palette.card)
                    }
                }
        }
        .buttonStyle(.stridePress)
    }

    private var equipmentFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                equipChip(title: "全部器械", value: nil)
                ForEach(catalog.availableEquipments, id: \.self) { eq in
                    equipChip(title: CatalogExercise.equipmentName(eq), value: eq)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectedEquipment)
    }

    private func equipChip(title: String, value: String?) -> some View {
        let active = selectedEquipment == value
        return Button {
            withAnimation(.snappy(duration: 0.22)) {
                selectedEquipment = value
            }
        } label: {
            Text(title)
                .font(.system(size: 11.5, weight: active ? .semibold : .medium))
                .foregroundStyle(active ? Palette.green : Palette.textFaint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(active ? Palette.green.opacity(0.15) : Palette.cardSoft)
                )
                .overlay(
                    Capsule().strokeBorder(active ? Palette.green.opacity(0.45) : Palette.stroke, lineWidth: 0.8)
                )
        }
        .buttonStyle(.stridePress)
    }

    private var resultsCountBar: some View {
        HStack {
            Text("共 \(filtered.count) 个动作")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.textDim)
                .numericRoll(value: filtered.count)
            Spacer()
            if selectedBodyPart != nil || selectedEquipment != nil || !query.isEmpty {
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        query = ""
                        selectedBodyPart = nil
                        selectedEquipment = nil
                    }
                } label: {
                    Text("重置筛选")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Palette.blue)
                }
                .buttonStyle(.stridePress)
            }
        }
    }

    // MARK: - 动作卡片行

    private func exerciseRow(_ item: CatalogExercise) -> some View {
        Button {
            if let onPick {
                onPick(item.toExercise())
                dismiss()
            } else {
                detailExercise = item
            }
        } label: {
            HStack(spacing: 12) {
                ExerciseThumbView(url: item.thumbURL, localThumb: item.localThumb, hasVideo: item.hasVideo)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayTitle)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Palette.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if item.displayTitle != item.name {
                        Text(item.name)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.textFaint)
                            .lineLimit(1)
                    }

                    HStack(spacing: 6) {
                        badge(item.bodyPartZH, tint: item.muscleGroup.tint)
                        badge(item.equipmentZH, tint: Palette.textDim)
                        Text(item.difficultyZH.map { "\(item.targetZH) · \($0)" } ?? item.targetZH)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.textFaint)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                if onPick != nil {
                    Button {
                        detailExercise = item
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Palette.green)
                    }
                    .buttonStyle(.stridePress)
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Palette.green)
                }
            }
            .padding(12)
            .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
        }
        .buttonStyle(.strideCard)
        .contextMenu {
            Button {
                detailExercise = item
            } label: {
                Label("观看 720p 动作示范视频", systemImage: "play.rectangle.fill")
            }
            if let onPick {
                Button {
                    onPick(item.toExercise())
                    dismiss()
                } label: {
                    Label("加入本次训练", systemImage: "plus.circle.fill")
                }
            }
        }
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.14)))
    }
}

// MARK: - 动作视频详情弹窗

struct ExerciseVideoDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let exercise: CatalogExercise
    let pickMode: Bool
    var onPickOrStart: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        if exercise.hasVideo {
                            ExerciseVideoPlayerView(videoURL: exercise.videoURL, posterName: exercise.localThumb)
                        } else {
                            ExerciseGIFPlayerView(startURL: exercise.startImageURL, peakURL: exercise.peakImageURL)
                                .frame(height: 300)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(exercise.displayTitle)
                                .font(.system(size: 21, weight: .bold))
                                .foregroundStyle(Palette.text)

                            if exercise.displayTitle != exercise.name {
                                Text(exercise.name)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Palette.textFaint)
                            }

                            HStack(spacing: 8) {
                                tagPill("部位：\(exercise.bodyPartZH)", color: exercise.muscleGroup.tint)
                                tagPill("器械：\(exercise.equipmentZH)", color: Palette.amber)
                                if let diff = exercise.difficultyZH {
                                    tagPill("难度：\(diff)", color: Palette.purple)
                                }
                            }
                        }

                        HStack(spacing: 14) {
                            ExerciseMuscleBadgeView(url: exercise.muscleImageURL)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("目标与协同肌群")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Palette.textDim)
                                Text("主练：\(exercise.targetZH)")
                                    .font(.system(size: 14.5, weight: .bold))
                                    .foregroundStyle(Palette.text)
                                if !exercise.secondary.isEmpty {
                                    Text("协同：\(exercise.secondary.map(CatalogExercise.targetName).joined(separator: " · "))")
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(Palette.textDim)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(radius: 16, fill: Palette.card, stroke: Palette.stroke)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("动作执行步骤")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Palette.text)

                            ForEach(Array(exercise.steps.enumerated()), id: \.offset) { idx, step in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(idx + 1)")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.black)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(Palette.green))
                                    Text(step)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Palette.text)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)

                        if let tips = exercise.tips, !tips.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("动作要领与避坑提示")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Palette.text)

                                ForEach(tips, id: \.self) { tip in
                                    HStack(alignment: .top, spacing: 9) {
                                        Image(systemName: "lightbulb.fill")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Palette.amber)
                                            .padding(.top, 2)
                                        Text(tip)
                                            .font(.system(size: 13.5))
                                            .foregroundStyle(Palette.textDim)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .padding(15)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
                        }

                        Button {
                            onPickOrStart()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: pickMode ? "plus.circle.fill" : "figure.strengthtraining.traditional")
                                Text(pickMode ? "加入本次训练" : "以此动作开始训练")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.green))
                        }
                        .buttonStyle(.strideShimmer(glow: Palette.green))

                        Text("720p 真人视频来源 CC0 公共领域 · 肌群解剖图由 RepDB (repdb.co) 提供")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.textFaint)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(Metrics.page)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("动作示范")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func tagPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.14)))
    }
}

// 让 SessionDraft 支持 `.sheet(item:)`
extension SessionDraft: Identifiable {
    var id: String { title }
}
