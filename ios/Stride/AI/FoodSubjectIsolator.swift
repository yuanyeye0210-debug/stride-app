import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// 基于 Apple iOS 17+ 原生 Vision 主体分割 + CoreImage 滤镜：
/// 自动识别食物前景主体，将周围背景做马赛克暗化处理，并在食物边缘描出荧光绿高亮轮廓。
enum FoodSubjectIsolator {
    private static let ciContext = CIContext()

    struct IsolationResult {
        let previewImage: UIImage
        let isolatedSubjectFound: Bool
    }

    static func isolateFood(from image: UIImage) async -> IsolationResult {
        await Task.detached(priority: .userInitiated) {
            let normalized = normalizeOrientation(image)
            guard let ciInput = CIImage(image: normalized) else {
                return IsolationResult(previewImage: normalized, isolatedSubjectFound: false)
            }

            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(ciImage: ciInput, options: [:])
            do {
                try handler.perform([request])
                guard let result = request.results?.first, !result.allInstances.isEmpty else {
                    return IsolationResult(previewImage: fallbackMosaicBorder(ciInput, fallback: normalized), isolatedSubjectFound: false)
                }

                let maskBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
                let maskImage = CIImage(cvPixelBuffer: maskBuffer)

                if let rendered = renderMosaicWithOutline(input: ciInput, mask: maskImage) {
                    return IsolationResult(previewImage: rendered, isolatedSubjectFound: true)
                }
            } catch {
                // 主体分割失败时安全降级为四周马赛克聚焦框
            }

            return IsolationResult(previewImage: fallbackMosaicBorder(ciInput, fallback: normalized), isolatedSubjectFound: false)
        }.value
    }

    /// 合成「清晰食物主体 + 荧光绿描边 + 周围马赛克背景」。
    private static func renderMosaicWithOutline(input: CIImage, mask: CIImage) -> UIImage? {
        let extent = input.extent

        // 1. 周围背景：像素马赛克 + 轻微压暗，突出中心食物
        let pixellate = CIFilter.pixellate()
        pixellate.inputImage = input.clampedToExtent()
        pixellate.scale = Float(max(16, min(extent.width, extent.height) / 26.0))
        guard let pixelated = pixellate.outputImage?.cropped(to: extent) else { return nil }

        let darken = CIFilter.colorControls()
        darken.inputImage = pixelated
        darken.brightness = -0.18
        darken.saturation = 0.45
        let darkMosaic = darken.outputImage ?? pixelated

        // 2. 生成食物轮廓高亮描边（膨胀掩膜减去原掩膜）
        let dilate = CIFilter.morphologyMaximum()
        dilate.inputImage = mask
        dilate.radius = Float(max(3.5, min(extent.width, extent.height) / 150.0))
        let dilatedMask = dilate.outputImage?.cropped(to: extent) ?? mask

        let diff = CIFilter.differenceBlendMode()
        diff.inputImage = dilatedMask
        diff.backgroundImage = mask
        let edgeMask = diff.outputImage?.cropped(to: extent)

        // 将清晰原图通过 mask 叠放到马赛克背景上
        let blend = CIFilter.blendWithMask()
        blend.inputImage = input
        blend.backgroundImage = darkMosaic
        blend.maskImage = mask
        var composed = blend.outputImage ?? input

        // 叠加霓虹绿描边高亮（#5CE08F）
        if let edgeMask {
            let greenColor = CIImage(color: CIColor(red: 0.36, green: 0.88, blue: 0.56, alpha: 0.95)).cropped(to: extent)
            let edgeBlend = CIFilter.blendWithMask()
            edgeBlend.inputImage = greenColor
            edgeBlend.backgroundImage = composed
            edgeBlend.maskImage = edgeMask
            composed = edgeBlend.outputImage ?? composed
        }

        guard let cg = ciContext.createCGImage(composed, from: extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// 无法识别明显前景时的兜底：保留中央区域清晰，四周加马赛克。
    private static func fallbackMosaicBorder(_ input: CIImage, fallback: UIImage) -> UIImage {
        let extent = input.extent
        let pixellate = CIFilter.pixellate()
        pixellate.inputImage = input.clampedToExtent()
        pixellate.scale = Float(max(14, min(extent.width, extent.height) / 28.0))
        guard let mosaic = pixellate.outputImage?.cropped(to: extent) else { return fallback }

        let grad = CIFilter.radialGradient()
        grad.center = CGPoint(x: extent.midX, y: extent.midY)
        grad.radius0 = Float(min(extent.width, extent.height) * 0.28)
        grad.radius1 = Float(min(extent.width, extent.height) * 0.46)
        grad.color0 = CIColor.white
        grad.color1 = CIColor.black
        guard let mask = grad.outputImage?.cropped(to: extent) else { return fallback }

        let blend = CIFilter.blendWithMask()
        blend.inputImage = input
        blend.backgroundImage = mosaic
        blend.maskImage = mask
        guard let out = blend.outputImage,
              let cg = ciContext.createCGImage(out, from: extent) else { return fallback }
        return UIImage(cgImage: cg)
    }

    private static func normalizeOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
