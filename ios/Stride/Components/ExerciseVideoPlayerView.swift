import SwiftUI
import AVFoundation

// MARK: - 原生 AVFoundation 720p 无缝循环静音视频层

private struct LoopingVideoLayerView: UIViewRepresentable {
    let url: URL
    let isPlaying: Bool
    let playbackRate: Float

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        context.coordinator.configure(url: url, in: view, isPlaying: isPlaying, rate: playbackRate)
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        context.coordinator.update(url: url, in: uiView, isPlaying: isPlaying, rate: playbackRate)
    }

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    final class PlayerContainerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    final class Coordinator {
        private var queuePlayer: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var currentURL: URL?

        func configure(url: URL, in view: PlayerContainerView, isPlaying: Bool, rate: Float) {
            teardown()
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)

            let asset = AVURLAsset(url: url)
            let item = AVPlayerItem(asset: asset)
            let player = AVQueuePlayer(playerItem: item)
            player.isMuted = true
            player.automaticallyWaitsToMinimizeStalling = false

            let loop = AVPlayerLooper(player: player, templateItem: item)
            view.playerLayer.player = player
            view.playerLayer.videoGravity = .resizeAspectFill

            self.queuePlayer = player
            self.looper = loop
            self.currentURL = url

            if isPlaying {
                player.playImmediately(atRate: rate)
            } else {
                player.pause()
            }
        }

        func update(url: URL, in view: PlayerContainerView, isPlaying: Bool, rate: Float) {
            if currentURL != url {
                configure(url: url, in: view, isPlaying: isPlaying, rate: rate)
                return
            }
            guard let player = queuePlayer else { return }
            if isPlaying {
                if player.timeControlStatus != .playing || player.rate != rate {
                    player.playImmediately(atRate: rate)
                }
            } else if player.timeControlStatus != .paused {
                player.pause()
            }
        }

        func teardown() {
            queuePlayer?.pause()
            looper?.disableLooping()
            queuePlayer?.removeAllItems()
            looper = nil
            queuePlayer = nil
            currentURL = nil
        }
    }
}

// MARK: - 720p 动作示范视频播放器（预置高清封面 + 磁盘缓存离线秒播 + 0.5x 慢动作）

struct ExerciseVideoPlayerView: View {
    let videoURL: URL?
    let posterName: String?

    @State private var localFileURL: URL?
    @State private var isPlaying = true
    @State private var slowMo = false
    @State private var loading = false
    @State private var fromCache = false
    @State private var failed = false
    @State private var controlHapticToken = 0

    var body: some View {
        ZStack {
            Color(hex: 0x101012)

            if let poster = CatalogExercise.bundleThumbImage(named: posterName) {
                Image(uiImage: poster)
                    .resizable()
                    .scaledToFill()
            }

            if let localFileURL {
                LoopingVideoLayerView(
                    url: localFileURL,
                    isPlaying: isPlaying,
                    playbackRate: slowMo ? 0.5 : 1.0
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    isPlaying.toggle()
                    controlHapticToken += 1
                }
                .transition(.opacity)
            } else if loading {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.small)
                    Text("正在缓冲 720p 视频…")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.65)))
            } else if failed {
                VStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.white.opacity(0.85))
                    Text("视频加载失败，请检查网络")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.85))
                    Button {
                        Task { await loadVideo() }
                    } label: {
                        Text("重新加载")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.white))
                    }
                    .buttonStyle(.stridePress)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.black.opacity(0.68)))
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Palette.stroke, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if localFileURL != nil {
                HStack(spacing: 4) {
                    Image(systemName: fromCache ? "checkmark.circle.fill" : "video.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(fromCache ? Palette.green : Color.white)
                    Text(fromCache ? "720p 视频 · 已缓存" : "720p 高清视频")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.62)))
                .padding(12)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if localFileURL != nil {
                videoControls
                    .padding(12)
            }
        }
        .sensoryFeedback(.selection, trigger: controlHapticToken)
        .task(id: videoURL) {
            await loadVideo()
        }
    }

    private var videoControls: some View {
        HStack(spacing: 6) {
            Button {
                isPlaying.toggle()
                controlHapticToken += 1
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 28, height: 26)
                    .background(Circle().fill(Color.white.opacity(0.18)))
            }
            .buttonStyle(.stridePress)

            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    slowMo.toggle()
                }
                controlHapticToken += 1
            } label: {
                Text(slowMo ? "0.5× 慢放" : "1.0×")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(slowMo ? Color.black : Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(slowMo ? Palette.green : Color.white.opacity(0.16)))
            }
            .buttonStyle(.stridePress)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.black.opacity(0.62)))
    }

    private func loadVideo() async {
        guard let videoURL else {
            failed = true
            return
        }
        let targetLocalURL = ExerciseMediaCache.cachedFileURL(for: videoURL)
        if FileManager.default.fileExists(atPath: targetLocalURL.path) {
            localFileURL = targetLocalURL
            fromCache = true
            failed = false
            loading = false
            return
        }

        loading = true
        failed = false
        localFileURL = nil

        do {
            let res = try await ExerciseMediaCache.loadData(from: videoURL)
            withAnimation(.easeOut(duration: 0.2)) {
                localFileURL = targetLocalURL
                fromCache = res.fromCache
            }
        } catch {
            failed = true
        }
        loading = false
    }
}
