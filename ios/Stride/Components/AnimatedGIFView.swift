import SwiftUI
import UIKit
import ImageIO

// MARK: - 原生 ImageIO 循环动画 GIF 播放器 + 磁盘缓存缩略图

/// 从 GIF 二进制数据解码生成原生逐帧循环 `UIImage`。
enum GIFImageDecoder {
    static func decode(data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }

        if count == 1, let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            return UIImage(cgImage: cg)
        }

        var frames: [UIImage] = []
        var totalDuration: TimeInterval = 0

        for i in 0..<count {
            guard let cg = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            frames.append(UIImage(cgImage: cg))
            totalDuration += frameDuration(at: i, source: source)
        }

        guard !frames.isEmpty else { return nil }
        return UIImage.animatedImage(with: frames, duration: max(0.3, totalDuration))
    }

    private static func frameDuration(at index: Int, source: CGImageSource) -> TimeInterval {
        let defaultDelay: TimeInterval = 0.08
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any],
              let gifProps = props[kCGImagePropertyGIFDictionary as String] as? [String: Any] else {
            return defaultDelay
        }
        let delay = (gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double)
            ?? (gifProps[kCGImagePropertyGIFDelayTime as String] as? Double)
            ?? defaultDelay
        return delay < 0.02 ? defaultDelay : delay
    }
}

private struct GIFUIImageRepresentable: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIImageView {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        iv.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return iv
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.image = image
    }
}

/// 带本机缓存、双帧平滑循环演示、播放控制与加载重试的动作示范高清播放器。
struct ExerciseGIFPlayerView: View {
    let startURL: URL?
    let peakURL: URL?

    @State private var startImage: UIImage?
    @State private var peakImage: UIImage?
    @State private var animatedGIFImage: UIImage?
    @State private var showPeak = false
    @State private var isPlaying = true
    @State private var loading = false
    @State private var fromCache = false
    @State private var failed = false
    @State private var controlHapticToken = 0

    init(url: URL?) {
        self.startURL = url
        self.peakURL = nil
    }

    init(startURL: URL?, peakURL: URL? = nil) {
        self.startURL = startURL
        self.peakURL = (peakURL != startURL) ? peakURL : nil
    }

    private var hasDualFrames: Bool {
        startImage != nil && peakImage != nil
    }

    private var mediaTaskKey: String {
        "\(startURL?.absoluteString ?? "")|\(peakURL?.absoluteString ?? "")"
    }

    private var loopTaskKey: String {
        "\(mediaTaskKey)|\(isPlaying)|\(hasDualFrames)"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(hex: 0xD7F0FC))

            if let startImage {
                let activeImage = (showPeak ? (peakImage ?? startImage) : startImage)
                Image(uiImage: activeImage)
                    .resizable()
                    .scaledToFit()
                    .padding(10)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard hasDualFrames else { return }
                        isPlaying.toggle()
                        controlHapticToken += 1
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else if let animatedGIFImage {
                GIFUIImageRepresentable(image: animatedGIFImage)
                    .padding(10)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else if loading {
                VStack(spacing: 10) {
                    ProgressView()
                        .tint(Color.black.opacity(0.65))
                    Text("正在加载 512px 高清示范…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.58))
                }
            } else if failed {
                VStack(spacing: 10) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.black.opacity(0.45))
                    Text("高清示范加载失败，请检查网络")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.58))
                    Button {
                        Task { await loadMedia() }
                    } label: {
                        Text("重新加载")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.black))
                    }
                    .buttonStyle(.stridePress)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if startImage != nil || animatedGIFImage != nil {
                HStack(spacing: 4) {
                    Image(systemName: fromCache ? "checkmark.circle.fill" : (hasDualFrames ? "sparkles" : "photo.fill"))
                        .font(.system(size: 10.5))
                    Text(badgeText)
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundStyle(Color.white.opacity(0.94))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.55)))
                .padding(12)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if hasDualFrames {
                dualFrameControls
                    .padding(12)
            }
        }
        .sensoryFeedback(.selection, trigger: controlHapticToken)
        .task(id: mediaTaskKey) {
            await loadMedia()
        }
        .task(id: loopTaskKey) {
            guard isPlaying, hasDualFrames else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_150_000_000)
                if Task.isCancelled { break }
                withAnimation(.easeInOut(duration: 0.25)) {
                    showPeak.toggle()
                }
            }
        }
    }

    private var badgeText: String {
        if fromCache {
            return "512px 高清 · 已缓存"
        }
        return hasDualFrames ? "512px 高清示范" : "512px 高清姿态"
    }

    private var dualFrameControls: some View {
        HStack(spacing: 4) {
            framePill(title: "起始", active: !showPeak && !isPlaying) {
                isPlaying = false
                withAnimation(.easeInOut(duration: 0.2)) { showPeak = false }
                controlHapticToken += 1
            }

            framePill(title: "顶峰", active: showPeak && !isPlaying) {
                isPlaying = false
                withAnimation(.easeInOut(duration: 0.2)) { showPeak = true }
                controlHapticToken += 1
            }

            Button {
                isPlaying.toggle()
                controlHapticToken += 1
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.white.opacity(0.18)))
            }
            .buttonStyle(.stridePress)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.black.opacity(0.60)))
    }

    private func framePill(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: active ? .bold : .medium))
                .foregroundStyle(active ? Color.black : Color.white.opacity(0.88))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(active ? Color.white : Color.clear))
        }
        .buttonStyle(.stridePress)
    }

    private func loadMedia() async {
        guard let startURL else {
            failed = true
            return
        }
        loading = true
        failed = false
        startImage = nil
        peakImage = nil
        animatedGIFImage = nil
        showPeak = false

        // 若仅为单张老格式 GIF，走逐帧解码路径保持兼容
        if peakURL == nil, startURL.pathExtension.lowercased() == "gif" {
            do {
                let result = try await ExerciseMediaCache.loadData(from: startURL)
                let decoded = await Task.detached(priority: .userInitiated) {
                    GIFImageDecoder.decode(data: result.data)
                }.value
                if let decoded {
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.animatedGIFImage = decoded
                        self.fromCache = result.fromCache
                    }
                } else {
                    self.failed = true
                }
            } catch {
                self.failed = true
            }
            loading = false
            return
        }

        do {
            async let startFetch = ExerciseMediaCache.loadData(from: startURL)
            async let peakFetch: (data: Data, fromCache: Bool)? = {
                guard let peakURL else { return nil }
                return try? await ExerciseMediaCache.loadData(from: peakURL)
            }()

            let sRes = try await startFetch
            let pRes = await peakFetch

            let decodedStart = await Task.detached(priority: .userInitiated) {
                UIImage(data: sRes.data)
            }.value

            var decodedPeak: UIImage?
            if let pData = pRes?.data {
                decodedPeak = await Task.detached(priority: .userInitiated) {
                    UIImage(data: pData)
                }.value
            }

            if let decodedStart {
                withAnimation(.easeOut(duration: 0.2)) {
                    self.startImage = decodedStart
                    self.peakImage = decodedPeak
                    self.fromCache = sRes.fromCache && (pRes?.fromCache ?? true)
                }
            } else {
                self.failed = true
            }
        } catch {
            self.failed = true
        }
        loading = false
    }
}

/// 列表行内轻量高速缩略图（视频条目展示 16:9 内置电影感封面；静态条目展示 512px 高清矢量下采样图）。
struct ExerciseThumbView: View {
    let url: URL?
    var localThumb: String? = nil
    var hasVideo: Bool = false

    @State private var image: UIImage?

    var body: some View {
        if hasVideo {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: 0x1A1A1E))

                if let poster = CatalogExercise.bundleThumbImage(named: localThumb) ?? image {
                    Image(uiImage: poster)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 54)
                        .clipped()
                } else {
                    Image(systemName: "video.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Palette.textDim)
                }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.45)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.black.opacity(0.55)))
            }
            .frame(width: 96, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Palette.stroke, lineWidth: 0.8)
            )
            .overlay(alignment: .bottomTrailing) {
                Text("720p")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.black.opacity(0.65)))
                    .padding(4)
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color(hex: 0xD7F0FC))

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipped()
                        .transition(.opacity)
                } else {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.35))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .task(id: url) {
                guard let url, image == nil else { return }
                if let result = try? await ExerciseMediaCache.loadData(from: url) {
                    let decoded = await Task.detached(priority: .utility) {
                        ExerciseMediaCache.decodeDownsampled(data: result.data, maxPixelSize: 180)
                    }.value
                    if let decoded {
                        withAnimation(.easeOut(duration: 0.16)) {
                            self.image = decoded
                        }
                    }
                }
            }
        }
    }
}

/// 目标肌群解剖高亮缩略卡片（透明底亮橙肌群图）。
struct ExerciseMuscleBadgeView: View {
    let url: URL?

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Palette.stroke, lineWidth: 1)
                )

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .transition(.opacity)
            } else {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Palette.textFaint)
            }
        }
        .frame(width: 76, height: 76)
        .task(id: url) {
            guard let url, image == nil else { return }
            if let result = try? await ExerciseMediaCache.loadData(from: url) {
                let decoded = await Task.detached(priority: .utility) {
                    UIImage(data: result.data)
                }.value
                if let decoded {
                    withAnimation(.easeOut(duration: 0.16)) {
                        self.image = decoded
                    }
                }
            }
        }
    }
}
