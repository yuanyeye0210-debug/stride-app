import SwiftUI

struct RootTabView: View {
    @State private var selection = 0
    @State private var homeChannel: HomeChannel = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                tab(0) {
                    NavigationStack {
                        HomeChannelHostView(
                            channel: $homeChannel,
                            onJumpToPlan: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    selection = 1
                                }
                            }
                        )
                    }
                }
                tab(1) { NavigationStack { TrainingHomeView() } }
                tab(2) { NavigationStack { ProgressViewScreen() } }
                tab(3) { NavigationStack { MeView() } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar(selection: $selection)
        }
        .background(Palette.bg.ignoresSafeArea())
    }

    private func tab<Content: View>(_ tag: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(selection == tag ? 1 : 0)
            .allowsHitTesting(selection == tag)
            .accessibilityHidden(selection != tag)
    }
}

// MARK: - 主页顶部 4 频道容器（首页 | 音乐 | 跑步 | 插件）

private struct HomeChannelHostView: View {
    @EnvironmentObject private var store: AppStore

    @Binding var channel: HomeChannel
    var onJumpToPlan: () -> Void

    @State private var showCoachSheet = false
    @State private var showRunSheet = false
    @State private var showPlaylistSheet = false
    @State private var showLyricsSheet = false

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                switch channel {
                case .home:
                    TodayView(onJumpToPlan: onJumpToPlan)
                case .music:
                    HomeMusicPreview(
                        onOpenImport: { showPlaylistSheet = true },
                        onOpenLyrics: { showLyricsSheet = true }
                    )
                case .run:
                    HomeRunPreview(
                        onStartRun: { showRunSheet = true }
                    )
                case .plugins:
                    HomePluginsPreview()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HomeTopSegmentBar(
                channel: $channel,
                onAI: { showCoachSheet = true },
                onFavoriteMusic: { showPlaylistSheet = true },
                onQuickRun: { showRunSheet = true }
            )
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showCoachSheet) {
            NavigationStack { CoachView() }
        }
        .sheet(isPresented: $showRunSheet) {
            RunCaptureView()
        }
        .sheet(isPresented: $showPlaylistSheet) {
            NavigationStack { PlaylistImportView() }
        }
        .sheet(isPresented: $showLyricsSheet) {
            NavigationStack { LyricsView() }
        }
    }
}

// MARK: - 音乐 / 跑步 / 插件在 Phase 1 的本地通道入口（将在 Phase 4 完整重构）

private struct HomeMusicPreview: View {
    var onOpenImport: () -> Void
    var onOpenLyrics: () -> Void

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("运动音乐")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Palette.text)

                    Text("已为你准备本机歌单与逐行歌词跟读工具；完整 Apple Music 风格发现页将在下一阶段上线。")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textDim)

                    Button(action: onOpenImport) {
                        HStack(spacing: 12) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Palette.pink)
                                .frame(width: 44, height: 44)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.pink.opacity(0.14)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("歌单链接导入与 BPM 分段")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Palette.text)
                                Text("粘贴歌单链接，按热身 / 主训 / 冲刺节拍分组")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Palette.textDim)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Palette.textFaint)
                        }
                        .padding(16)
                        .card(radius: 20, fill: Palette.card, stroke: Palette.stroke)
                    }
                    .buttonStyle(.plain)

                    Button(action: onOpenLyrics) {
                        HStack(spacing: 12) {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Palette.blue)
                                .frame(width: 44, height: 44)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.blue.opacity(0.14)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("LRC 歌词同步跟读")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Palette.text)
                                Text("支持导入 LRC 时间轴，锻炼时逐行高亮滚动")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Palette.textDim)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Palette.textFaint)
                        }
                        .padding(16)
                        .card(radius: 20, fill: Palette.card, stroke: Palette.stroke)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Metrics.page)
                .padding(.top, 68)
                .padding(.bottom, Metrics.floatingTabBottomInset + 16)
            }
        }
    }
}

private struct HomeRunPreview: View {
    @EnvironmentObject private var store: AppStore
    var onStartRun: () -> Void
    @State private var selectedRun: RouteRun?

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Button(action: onStartRun) {
                        HStack {
                            Image(systemName: "figure.run")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Palette.lime)
                            Text("开始跑步（点击右上 GO 也可直接启动）")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Palette.text)
                            Spacer()
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.black)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Palette.lime))
                        }
                        .padding(16)
                        .card(radius: 20, fill: Palette.card, stroke: Palette.stroke)
                    }
                    .buttonStyle(.plain)

                    if !store.state.runs.isEmpty {
                        Text("近期跑步足迹")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Palette.text)
                            .padding(.top, 4)

                        ForEach(store.state.runs.prefix(4)) { run in
                            Button {
                                selectedRun = run
                            } label: {
                                HStack(spacing: 12) {
                                    RouteArtView(points: run.points, style: run.style, lineWidth: 2, showsBaseline: false)
                                        .frame(width: 60, height: 60)
                                        .background(Palette.cardSoft)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(run.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Palette.text)
                                        Text(String(format: "%.2f km · %@", run.distanceM / 1000, run.style.title))
                                            .font(.system(size: 12))
                                            .foregroundStyle(Palette.textDim)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(Palette.textFaint)
                                }
                                .padding(12)
                                .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, Metrics.page)
                .padding(.top, 68)
                .padding(.bottom, Metrics.floatingTabBottomInset + 16)
            }
        }
        .sheet(item: $selectedRun) { run in
            RouteDetailView(run: run)
        }
    }
}

private struct HomePluginsPreview: View {
    var body: some View {
        PluginsView(embeddedInChannel: true)
    }
}
