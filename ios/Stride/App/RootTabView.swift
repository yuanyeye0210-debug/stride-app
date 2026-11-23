import SwiftUI

struct RootTabView: View {
    @State private var selection = 0
    @State private var homeChannel: HomeChannel = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            // 按需只挂载当前激活的 Tab，彻底杜绝 4 个重型页面同时常驻 ZStack 抢占 CPU/GPU
            Group {
                switch selection {
                case 0:
                    NavigationStack {
                        HomeChannelHostView(
                            channel: $homeChannel,
                            onJumpToPlan: {
                                selection = 1
                            }
                        )
                    }
                case 1:
                    NavigationStack { PlanHubView() }
                case 2:
                    NavigationStack { ProgressViewScreen() }
                default:
                    NavigationStack { MeView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar(selection: $selection)
        }
        .background(Palette.bg.ignoresSafeArea())
    }
}

// MARK: - 主页顶部 4 频道容器（首页 | 音乐 | 跑步 | 插件）

private struct HomeChannelHostView: View {
    @EnvironmentObject private var store: AppStore

    @Binding var channel: HomeChannel
    var onJumpToPlan: () -> Void

    @State private var showCoachSheet = false
    @State private var showRunSheet = false
    @State private var showMusicFavoritesSheet = false

    var body: some View {
        ZStack(alignment: .top) {
            // 频道视图直接瞬切，不把整屏数百个子视图卷入 Spring 布局插值动画
            Group {
                switch channel {
                case .home:
                    TodayView(onJumpToPlan: onJumpToPlan)
                case .music:
                    MusicDiscoverView(showFavoritesSheet: $showMusicFavoritesSheet)
                case .run:
                    RunCenterView()
                case .plugins:
                    PluginPlazaView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HomeTopSegmentBar(
                channel: $channel,
                onAI: { showCoachSheet = true },
                onFavoriteMusic: { showMusicFavoritesSheet = true },
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
    }
}
