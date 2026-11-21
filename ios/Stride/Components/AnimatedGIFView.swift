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

/// 带本机缓存、加载指示与重试的动作示范 GIF 播放卡片。
struct ExerciseGIFPlayerView: View {
    let url: URL?

    @State private var animatedImage: UIImage?
    @State private var loading = false
    @State private var fromCache = false
    @State private var failed = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)

            if let animatedImage {
                GIFUIImageRepresentable(image: animatedImage)
                    .padding(14)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else if loading {
                VStack(spacing: 10) {
                    ProgressView()
                        .tint(Color.black.opacity(0.65))
                    Text("正在加载动作示范动画…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.55))
                }
            } else if failed {
                VStack(spacing: 10) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.black.opacity(0.45))
                    Text("示范动画加载失败，请检查网络")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.55))
                    Button {
                        Task { await loadGIF() }
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
            if animatedImage != nil {
                HStack(spacing: 4) {
                    Image(systemName: fromCache ? "checkmark.circle.fill" : "play.circle.fill")
                        .font(.system(size: 10.5))
                    Text(fromCache ? "已缓存离线可看" : "高清示范中")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundStyle(fromCache ? Palette.green : Color.black.opacity(0.75))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.08)))
                .padding(12)
            }
        }
        .task(id: url) {
            await loadGIF()
        }
    }

    private func loadGIF() async {
        guard let url else {
            failed = true
            return
        }
        loading = true
        failed = false
        do {
            let result = try await ExerciseMediaCache.loadData(from: url)
            let decoded = await Task.detached(priority: .userInitiated) {
                GIFImageDecoder.decode(data: result.data)
            }.value
            if let decoded {
                withAnimation(.easeOut(duration: 0.2)) {
                    self.animatedImage = decoded
                    self.fromCache = result.fromCache
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

/// 列表行内轻量缓存缩略图。
struct ExerciseThumbView: View {
    let url: URL?

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.95))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            } else {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.35))
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task(id: url) {
            guard let url, image == nil else { return }
            if let result = try? await ExerciseMediaCache.loadData(from: url),
               let ui = UIImage(data: result.data) {
                self.image = ui
            }
        }
    }
}
