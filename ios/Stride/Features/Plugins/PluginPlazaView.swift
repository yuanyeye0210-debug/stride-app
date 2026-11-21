import SwiftUI

struct PluginPlazaView: View {
    @EnvironmentObject private var store: AppStore

    @State private var selectedPlugin: StridePluginItem?
    @State private var selectedCollection: PluginCollectionKind?
    @State private var query = ""
    @State private var showSearch = false

    private var filteredPlugins: [StridePluginItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return PluginsCatalog.all }
        return PluginsCatalog.all.filter {
            $0.title.localizedCaseInsensitiveContains(q)
                || $0.summary.localizedCaseInsensitiveContains(q)
                || $0.posterWords.joined(separator: " ").localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if showSearch {
                        TextField("搜索 62 款本机插件", text: $query)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.text)
                            .padding(12)
                            .card(radius: 16, fill: Palette.card, stroke: Palette.stroke)
                            .padding(.horizontal, Metrics.page)
                    }

                    // 顶部横向主题合集 Banner（图 20–21）
                    if query.isEmpty {
                        collectionsCarousel
                    }

                    // 标题与搜索切换
                    HStack {
                        Text("全部工具 · \(filteredPlugins.count)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.textDim)
                        Spacer()
                        Button {
                            withAnimation(.snappy(duration: 0.2)) { showSearch.toggle() }
                        } label: {
                            Image(systemName: showSearch ? "xmark.circle.fill" : "magnifyingglass")
                                .font(.system(size: 15))
                                .foregroundStyle(Palette.textDim)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Metrics.page)

                    // 双列海报插件网格
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                        ForEach(filteredPlugins) { item in
                            Button {
                                store.markPluginInstalled(item.id)
                                selectedPlugin = item
                            } label: {
                                PluginPosterCard(
                                    item: item,
                                    installed: store.isPluginInstalled(item.id)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Metrics.page)

                    // 图 33 页脚隐私声明
                    Text("这些工具都在本机计算，不上传你的数据。")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textFaint)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 10)
                }
                .padding(.top, 68)
                .padding(.bottom, Metrics.floatingTabBottomInset + 16)
            }
        }
        .sheet(item: $selectedPlugin) { item in
            PluginToolHostSheet(plugin: item)
        }
        .sheet(item: Binding(
            get: { selectedCollection.map { CollectionWrapper(kind: $0) } },
            set: { selectedCollection = $0?.kind }
        )) { wrapper in
            PluginCollectionDetailSheet(kind: wrapper.kind) { plugin in
                selectedCollection = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    store.markPluginInstalled(plugin.id)
                    selectedPlugin = plugin
                }
            }
        }
    }

    // MARK: - 顶部横向合集轮播

    private var collectionsCarousel: some View {
        let runTotal = PluginsCatalog.count(in: .runningPack)
        let runInstalled = PluginsCatalog.installedCount(in: .runningPack, installedIDs: store.state.installedPluginIDs)
        let strTotal = PluginsCatalog.count(in: .strengthPack)
        let strInstalled = PluginsCatalog.installedCount(in: .strengthPack, installedIDs: store.state.installedPluginIDs)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                Button {
                    selectedCollection = .runningPack
                } label: {
                    RunningCollectionBanner(installed: runInstalled, total: runTotal)
                        .frame(width: 316, height: 186)
                }
                .buttonStyle(.plain)

                Button {
                    selectedCollection = .strengthPack
                } label: {
                    StrengthCollectionBanner(installed: strInstalled, total: strTotal)
                        .frame(width: 316, height: 186)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Metrics.page)
        }
    }
}

private struct CollectionWrapper: Identifiable {
    let kind: PluginCollectionKind
    var id: String { kind.rawValue }
}

// MARK: - 专题合集卡片 1：红棕跑道跑者合集（图 20）

private struct RunningCollectionBanner: View {
    let installed: Int
    let total: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x3D1D1A), Color(hex: 0x241210)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 塑胶跑道背景纹理
            Canvas { ctx, size in
                for lane in 0..<6 {
                    let inset = CGFloat(lane) * 9 + 14
                    let rect = CGRect(x: size.width * 0.36 + inset, y: -20 + inset * 0.4, width: size.width * 0.75, height: size.height + 20)
                    ctx.stroke(
                        RoundedRectangle(cornerRadius: 70).path(in: rect),
                        with: .color(Color.white.opacity(0.14)),
                        lineWidth: 1.1
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "square.stack.3d.up.fill").font(.system(size: 11))
                        Text("合集 · 跑步专业")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.14)))

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.14)))
                }

                Spacer()

                Text("跑步专业训练插件合集")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.white)

                Text("马拉松与耐力跑者常用的 \(total) 个工具")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.75))

                HStack(spacing: 10) {
                    BarProgress(progress: total > 0 ? Double(installed) / Double(total) : 0, color: Color.white, height: 4)
                    Text("已启用 \(installed) / \(total)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
            }
            .padding(18)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - 专题合集卡片 2：深蓝五色奥林匹克杠铃片合集（图 21）

private struct StrengthCollectionBanner: View {
    let installed: Int
    let total: Int

    private let plateColors: [Color] = [
        Color(hex: 0xD9383A),
        Color(hex: 0x2F6FE4),
        Color(hex: 0xE6B92E),
        Color(hex: 0x2E9E56),
        Color(hex: 0xE6E7EB)
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x162642), Color(hex: 0x0F172A)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 右上奥林匹克五色杠铃片图形
            HStack(spacing: 4) {
                ForEach(plateColors.indices, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(plateColors[idx].opacity(0.72))
                        .frame(width: 9, height: CGFloat(58 - idx * 7))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 26)
            .padding(.trailing, 24)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "square.stack.3d.up.fill").font(.system(size: 11))
                        Text("合集 · 力量训练")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.14)))

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.14)))
                }

                Spacer()

                Text("力量训练插件合集")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.white)

                Text("力量举、举重与健身房常用的 \(total) 个计算工具")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.75))

                HStack(spacing: 10) {
                    BarProgress(progress: total > 0 ? Double(installed) / Double(total) : 0, color: Color.white, height: 4)
                    Text("已启用 \(installed) / \(total)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
            }
            .padding(18)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - 双列海报插件卡片（图 20–33）

private struct PluginPosterCard: View {
    let item: StridePluginItem
    let installed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: -4) {
                    Spacer(minLength: 6)
                    ForEach(item.posterWords, id: \.self) { word in
                        Text(word)
                            .font(.system(size: item.posterWords.count > 1 ? 24 : 30, weight: .black))
                            .tracking(-0.7)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color(hex: 0x8F9199)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.45)
                    }
                    Spacer(minLength: 6)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 112)
                .background(Color(hex: 0x0A0A0B))

                if item.badge != .none {
                    Image(systemName: item.badge == .media ? "dot.radiowaves.left.and.right" : "wand.and.stars")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(installed ? Palette.green : Palette.textDim)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                        .padding(10)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                Text(item.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textDim)
                    .lineLimit(2)
                    .frame(height: 30, alignment: .topLeading)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0x161618))
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Palette.stroke, lineWidth: 1)
        )
    }
}

// MARK: - 专题合集详情弹窗

private struct PluginCollectionDetailSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let kind: PluginCollectionKind
    var onOpenPlugin: (StridePluginItem) -> Void

    private var list: [StridePluginItem] {
        PluginsCatalog.all.filter { $0.collection == kind }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 10) {
                        Button("一键标记合集全部已启用") {
                            for item in list { store.markPluginInstalled(item.id) }
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.white))
                        .padding(.bottom, 6)

                        ForEach(list) { item in
                            Button {
                                onOpenPlugin(item)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Palette.text)
                                        Text(item.summary)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Palette.textDim)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    if store.isPluginInstalled(item.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Palette.green)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(Palette.textFaint)
                                    }
                                }
                                .padding(14)
                                .card(radius: 16, fill: Palette.card, stroke: Palette.stroke)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Metrics.page)
                }
            }
            .navigationTitle(kind == .runningPack ? "跑步专业训练插件" : "力量训练插件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
