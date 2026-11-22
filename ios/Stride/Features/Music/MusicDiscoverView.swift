import SwiftUI
import AVFoundation

/// 基于 AVAudioEngine 合成的实时 BPM 电子节拍器音频引擎（强弱拍鼓点，零外部音频文件依赖）。
final class MetronomeAudioEngine: ObservableObject {
    static let shared = MetronomeAudioEngine()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var timer: Timer?
    private var beatIndex = 0
    private var accentBuffer: AVAudioPCMBuffer?
    private var tickBuffer: AVAudioPCMBuffer?

    private init() {
        setupAudio()
    }

    private func setupAudio() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        accentBuffer = makeClickBuffer(freq: 980, duration: 0.045, gain: 0.35, format: format)
        tickBuffer = makeClickBuffer(freq: 660, duration: 0.035, gain: 0.22, format: format)
    }

    private func makeClickBuffer(freq: Double, duration: Double, gain: Float, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let count = AVAudioFrameCount(format.sampleRate * duration)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count) else { return nil }
        buf.frameLength = count
        guard let data = buf.floatChannelData?[0] else { return nil }
        let sr = format.sampleRate
        for i in 0..<Int(count) {
            let t = Double(i) / sr
            let env = Float(exp(-t * 55.0))
            data[i] = sin(Float(2.0 * .pi * freq * t)) * env * gain
        }
        return buf
    }

    func start(bpm: Int) {
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        if !engine.isRunning {
            try? engine.start()
        }
        if !player.isPlaying {
            player.play()
        }
        beatIndex = 0
        let interval = 60.0 / Double(max(60, min(220, bpm)))
        playTick()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.playTick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func playTick() {
        let buf = (beatIndex % 4 == 0) ? accentBuffer : tickBuffer
        beatIndex += 1
        if let buf {
            player.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        }
    }
}

struct MusicDiscoverView: View {
    @EnvironmentObject private var store: AppStore

    @Binding var showFavoritesSheet: Bool

    @State private var sourceMode = "精选歌单"
    @State private var showSearch = false
    @State private var searchQuery = ""
    @State private var showInfoAlert = false
    @State private var showImportSheet = false
    @State private var showLyricsSheet = false
    @State private var activeTrack: DemoTrack?
    @State private var isPlaying = false

    struct DemoPlaylist: Identifiable {
        let id: String
        let badge: String
        let headline: String
        let subtitle: String
        let title: String
        let sourceLabel: String
        let colors: [Color]
        let bpm: Int
    }

    struct DemoTrack: Identifiable {
        let id: String
        let rank: Int
        let title: String
        let artist: String
        let bpm: Int
        let colors: [Color]
    }

    private let hotCharts: [DemoPlaylist] = [
        DemoPlaylist(id: "chart.global", badge: "热门", headline: "Top 100\nGlobal", subtitle: "全球热榜", title: "Top 100: Global", sourceLabel: "Stride 精选", colors: [Color(hex: 0xDF4F67), Color(hex: 0xF7B0BE)], bpm: 128),
        DemoPlaylist(id: "chart.run", badge: "热门", headline: "Top 100\nRunning", subtitle: "跑步节奏", title: "Top 100: 跑步热榜", sourceLabel: "Stride 精选", colors: [Color(hex: 0x2F855A), Color(hex: 0xD46B38)], bpm: 170),
        DemoPlaylist(id: "chart.hiit", badge: "热门", headline: "Top 100\nHIIT", subtitle: "高燃间歇", title: "Top 100: HIIT 能量", sourceLabel: "Stride 精选", colors: [Color(hex: 0x5B6CFF), Color(hex: 0xC678DD)], bpm: 145)
    ]

    private let recommended: [DemoPlaylist] = [
        DemoPlaylist(id: "rec.fitness", badge: "推荐", headline: "Fitness+\n180 BPM", subtitle: "步频节拍", title: "Stride Fitness: 高能节拍", sourceLabel: "Stride 精选", colors: [Color(hex: 0x232328), Color(hex: 0x62E63C)], bpm: 180),
        DemoPlaylist(id: "rec.strength", badge: "推荐", headline: "Heavy\nLifting", subtitle: "深蹲硬拉", title: "Heavy Lifting: 力量房", sourceLabel: "Stride 精选", colors: [Color(hex: 0x2C2C34), Color(hex: 0xFFB86B)], bpm: 132)
    ]

    private let workoutPlaylists: [DemoPlaylist] = [
        DemoPlaylist(id: "wo.rnb", badge: "运动", headline: "R&B\nWorkout", subtitle: "力量韵律", title: "R&B Workout", sourceLabel: "Stride Fitness", colors: [Color(hex: 0x16161B), Color(hex: 0x585B68)], bpm: 124),
        DemoPlaylist(id: "wo.pure", badge: "跑步", headline: "Pure\nRunning", subtitle: "纯粹配速", title: "Pure Running", sourceLabel: "Stride Fitness", colors: [Color(hex: 0x243318), Color(hex: 0xC8FF00)], bpm: 174),
        DemoPlaylist(id: "wo.80s", badge: "燃脂", headline: "'80s\nWorkout", subtitle: "复古合成", title: "'80s Workout", sourceLabel: "Stride Fitness", colors: [Color(hex: 0x8F401A), Color(hex: 0xFF9F43)], bpm: 138)
    ]

    private let topTracks: [DemoTrack] = [
        DemoTrack(id: "t1", rank: 1, title: "Stride Pace 170", artist: "步频律动组", bpm: 170, colors: [Palette.lime, Palette.green]),
        DemoTrack(id: "t2", rank: 2, title: "PR Day Anthem", artist: "铁馆重金属", bpm: 136, colors: [Palette.amber, Palette.coralHi]),
        DemoTrack(id: "t3", rank: 3, title: "Night Tempo Run", artist: "都市夜跑", bpm: 162, colors: [Palette.blue, Palette.purple]),
        DemoTrack(id: "t4", rank: 4, title: "Cool Down Breeze", artist: "拉伸白噪音", bpm: 92, colors: [Palette.cyan, Palette.indigo]),
        DemoTrack(id: "t5", rank: 5, title: "Zone 2 Cruise", artist: "耐力电音", bpm: 156, colors: [Palette.green, Palette.cyan]),
        DemoTrack(id: "t6", rank: 6, title: "Tabata Sprint", artist: "间歇冲刺", bpm: 180, colors: [Palette.ringMove, Palette.amber])
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    // 顶部工具控制栏
                    HStack(spacing: 8) {
                        Text("热门歌单")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Palette.text)
                        Spacer()

                        Button { showInfoAlert = true } label: {
                            Image(systemName: "info")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Palette.text)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Palette.cardHigh))
                        }
                        .buttonStyle(.stridePress)

                        Button {
                            withAnimation(.snappy(duration: 0.2)) { showSearch.toggle() }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Palette.text)
                                .symbolEffect(.bounce, value: showSearch)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Palette.cardHigh))
                        }
                        .buttonStyle(.stridePress)

                        Menu {
                            Button("精选歌单（本机内置）") { sourceMode = "精选歌单" }
                            Button("歌单链接导入") { showImportSheet = true }
                            Button("LRC 歌词跟读") { showLyricsSheet = true }
                        } label: {
                            HStack(spacing: 4) {
                                Text(sourceMode)
                                    .font(.system(size: 12.5, weight: .semibold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(Palette.text)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(Capsule().fill(Palette.cardHigh))
                        }
                    }
                    .padding(.horizontal, Metrics.page)

                    if showSearch {
                        TextField("搜索曲目或歌单（支持 BPM）", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.text)
                            .padding(11)
                            .card(radius: 14, fill: Palette.card, stroke: Palette.stroke)
                            .padding(.horizontal, Metrics.page)
                    }

                    // 1. 热门歌单横向大图
                    horizontalPlaylistsSection(items: filtered(hotCharts), large: true)

                    // 2. 推荐歌单
                    sectionHeader("推荐歌单")
                    horizontalPlaylistsSection(items: filtered(recommended), large: false)

                    // 3. 热门单曲
                    sectionHeader("热门单曲")
                    topTracksCarousel

                    // 4. 运动 & 健身歌单
                    sectionHeader("运动 & 健身歌单")
                    horizontalPlaylistsSection(items: filtered(workoutPlaylists), large: false)

                    // 5. 本地歌单导入 & LRC 歌词直达
                    localMusicToolsSection
                }
                .padding(.top, 68)
                .padding(.bottom, Metrics.floatingTabBottomInset + (activeTrack != nil ? 76 : 16))
            }

            if let track = activeTrack {
                miniPlayerBar(track)
                    .padding(.horizontal, Metrics.page)
                    .padding(.bottom, Metrics.floatingTabBottomInset + 8)
            }
        }
        .alert("关于运动音乐", isPresented: $showInfoAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("当前为免账号离线版本，未连接外部 Apple Music 流媒体权限；提供精选训练节拍歌单、本地歌单链接 BPM 解析与 LRC 歌词同步跟读。")
        }
        .sheet(isPresented: $showImportSheet) {
            NavigationStack { PlaylistImportView() }
                .strideSheetDetents([.medium, .large])
        }
        .sheet(isPresented: $showLyricsSheet) {
            NavigationStack { LyricsView() }
                .strideSheetDetents([.medium, .large])
        }
        .sheet(isPresented: $showFavoritesSheet) {
            MusicFavoritesSheet(playlists: hotCharts + recommended + workoutPlaylists, tracks: topTracks)
                .strideSheetDetents([.medium, .large])
        }
        .sensoryFeedback(.selection, trigger: activeTrack?.id)
        .sensoryFeedback(.impact(weight: .light), trigger: isPlaying)
        .onChange(of: isPlaying) { _, playing in
            if playing, let track = activeTrack {
                MetronomeAudioEngine.shared.start(bpm: track.bpm)
            } else {
                MetronomeAudioEngine.shared.stop()
            }
        }
        .onChange(of: activeTrack?.id) { _, _ in
            if isPlaying, let track = activeTrack {
                MetronomeAudioEngine.shared.start(bpm: track.bpm)
            }
        }
        .onDisappear {
            isPlaying = false
            MetronomeAudioEngine.shared.stop()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(Palette.text)
            .padding(.horizontal, Metrics.page)
    }

    private func filtered(_ list: [DemoPlaylist]) -> [DemoPlaylist] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return list }
        return list.filter { $0.title.localizedCaseInsensitiveContains(q) || "\($0.bpm)".contains(q) }
    }

    private func horizontalPlaylistsSection(items: [DemoPlaylist], large: Bool) -> some View {
        let w: CGFloat = large ? 228 : 164
        let h: CGFloat = large ? 228 : 164
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(items) { item in
                    let fav = store.isMusicFavorite(item.id)
                    VStack(alignment: .leading, spacing: 6) {
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: w, height: h)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.badge)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(Color.black.opacity(0.35)))
                                    Spacer()
                                    Button {
                                        store.toggleMusicFavorite(item.id)
                                    } label: {
                                        Image(systemName: fav ? "heart.fill" : "heart")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(fav ? Color(hex: 0xFA2D48) : Color.white.opacity(0.85))
                                            .symbolEffect(.bounce, value: fav)
                                    }
                                    .buttonStyle(StridePressButtonStyle(scale: 0.85, pressedOpacity: 0.9, haptic: .light))
                                }

                                Spacer()

                                Text(item.headline)
                                    .font(.system(size: large ? 26 : 20, weight: .black))
                                    .foregroundStyle(Color.white)
                                Text("\(item.bpm) BPM · \(item.subtitle)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.85))
                            }
                            .padding(14)
                            .frame(width: w, height: h)
                        }
                        .onTapGesture {
                            activeTrack = DemoTrack(id: item.id, rank: 1, title: item.title, artist: item.sourceLabel, bpm: item.bpm, colors: item.colors)
                            isPlaying = true
                        }
                        .scaleEffect(activeTrack?.id == item.id && isPlaying ? 0.98 : 1.0)
                        .animation(.snappy(duration: 0.22), value: activeTrack?.id)

                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.text)
                            .lineLimit(1)
                        Text(item.sourceLabel)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textFaint)
                            .lineLimit(1)
                    }
                    .frame(width: w, alignment: .leading)
                    .strideScrollDepth(minScale: 0.95, minOpacity: 0.85)
                }
            }
            .padding(.horizontal, Metrics.page)
        }
    }

    private var topTracksCarousel: some View {
        let filteredTracks = searchQuery.isEmpty ? topTracks : topTracks.filter {
            $0.title.localizedCaseInsensitiveContains(searchQuery) || $0.artist.localizedCaseInsensitiveContains(searchQuery)
        }
        return VStack(spacing: 10) {
            ForEach(filteredTracks) { track in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: track.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }

                    Text("\(track.rank)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.textFaint)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.text)
                        Text("\(track.artist) · \(track.bpm) BPM")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textDim)
                    }

                    Spacer()

                    Button {
                        if activeTrack?.id == track.id {
                            isPlaying.toggle()
                        } else {
                            activeTrack = track
                            isPlaying = true
                        }
                    } label: {
                        Image(systemName: (activeTrack?.id == track.id && isPlaying) ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(hex: 0xFA2D48))
                            .frame(width: 32, height: 32)
                            .overlay(Circle().strokeBorder(Color(hex: 0xFA2D48), lineWidth: 1.5))
                            .symbolEffect(.bounce, value: activeTrack?.id == track.id && isPlaying)
                    }
                    .buttonStyle(.stridePress)
                }
                .padding(.horizontal, Metrics.page)
            }
        }
    }

    private var localMusicToolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("本机音频工具")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, Metrics.page)

            HStack(spacing: 12) {
                Button { showImportSheet = true } label: {
                    HStack {
                        Image(systemName: "link").foregroundStyle(Palette.pink)
                        Text("歌单链接导入").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Palette.text)
                        Spacer()
                    }
                    .padding(14)
                    .card(radius: 16, fill: Palette.card, stroke: Palette.stroke)
                }
                .buttonStyle(.strideCard(radius: 16))

                Button { showLyricsSheet = true } label: {
                    HStack {
                        Image(systemName: "text.alignleft").foregroundStyle(Palette.blue)
                        Text("LRC 歌词同步").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Palette.text)
                        Spacer()
                    }
                    .padding(14)
                    .card(radius: 16, fill: Palette.card, stroke: Palette.stroke)
                }
                .buttonStyle(.strideCard(radius: 16))
            }
            .padding(.horizontal, Metrics.page)
        }
    }

    private func miniPlayerBar(_ track: DemoTrack) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(LinearGradient(colors: track.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "waveform")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(track.title)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                Text("\(track.bpm) BPM · \(isPlaying ? "播放中（模拟节拍）" : "已暂停")")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textDim)
            }

            Spacer()

            Button { showLyricsSheet = true } label: {
                Image(systemName: "waveform")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isPlaying ? Color(hex: 0xFA2D48) : Palette.textDim)
                    .symbolEffect(.variableColor.iterative, isActive: isPlaying)
            }
            .buttonStyle(.stridePress)

            Button {
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color(hex: 0xFA2D48)))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.stridePress)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .liquidGlassCapsule(tint: Color.black.opacity(0.65))
        .contentShape(Capsule())
        .onTapGesture { showLyricsSheet = true }
        .gesture(
            DragGesture(minimumDistance: 16)
                .onEnded { val in
                    if val.translation.height < -16 {
                        showLyricsSheet = true
                    }
                }
        )
    }
}

private struct MusicFavoritesSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let playlists: [MusicDiscoverView.DemoPlaylist]
    let tracks: [MusicDiscoverView.DemoTrack]

    var body: some View {
        let favSet = Set(store.state.favoriteMusicIDs)
        let favLists = playlists.filter { favSet.contains($0.id) }
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                if favLists.isEmpty {
                    EmptyHint(icon: "heart", title: "还没有收藏歌单", message: "在歌单封面上点心形即可收藏到这里。")
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(favLists) { item in
                                HStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 44, height: 44)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.text)
                                        Text("\(item.bpm) BPM · \(item.sourceLabel)").font(.system(size: 12)).foregroundStyle(Palette.textDim)
                                    }
                                    Spacer()
                                    Button {
                                        store.toggleMusicFavorite(item.id)
                                    } label: {
                                        Image(systemName: "heart.fill").foregroundStyle(Color(hex: 0xFA2D48))
                                    }
                                    .buttonStyle(StridePressButtonStyle(scale: 0.86, pressedOpacity: 0.9, haptic: .light))
                                }
                                .padding(12)
                                .card(radius: 16, fill: Palette.card, stroke: Palette.stroke)
                            }
                        }
                        .padding(Metrics.page)
                        .animation(.snappy(duration: 0.22), value: favLists.count)
                    }
                }
            }
            .navigationTitle("音乐收藏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
