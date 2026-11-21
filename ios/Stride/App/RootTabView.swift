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
                tab(1) { NavigationStack { PlanHubView() } }
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
    @State private var showMusicFavoritesSheet = false

    var body: some View {
        ZStack(alignment: .top) {
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
