import SwiftUI
import AVFoundation

// MARK: - 原生条形码扫码弹窗（无相机时支持手动输入与内置测试条码）

struct BarcodeScannerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var onDetected: (String) -> Void

    @State private var manualCode = ""
    @State private var cameraAvailable = AVCaptureDevice.default(for: .video) != nil

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()

                VStack(spacing: 16) {
                    if cameraAvailable {
                        BarcodeCameraPreview { code in
                            onDetected(code)
                            dismiss()
                        }
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(Palette.green.opacity(0.65), lineWidth: 2)
                        )
                        .overlay(alignment: .bottom) {
                            Text("将包装食品条形码对准框内")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.black.opacity(0.6)))
                                .padding(12)
                        }
                    } else {
                        EmptyHint(
                            icon: "barcode.viewfinder",
                            title: "当前环境无摄像头",
                            message: "可直接输入条形码数字或点击下方常见包装食品示例。"
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("手动输入条形码")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.textDim)
                        HStack(spacing: 8) {
                            TextField("例如 6948939611524", text: $manualCode)
                                .keyboardType(.numberPad)
                                .font(.system(size: 15, design: .monospaced))
                                .foregroundStyle(Palette.text)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.cardSoft))
                            Button {
                                let trimmed = manualCode.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                onDetected(trimmed)
                                dismiss()
                            } label: {
                                Text("查询")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.black)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.green))
                            }
                            .buttonStyle(.stridePress)
                        }
                    }
                    .padding(14)
                    .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("常见包装速查")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.textFaint)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(BarcodeFoodLookup.localBuiltInBarcodes.keys).sorted(), id: \.self) { code in
                                    if let item = BarcodeFoodLookup.localBuiltInBarcodes[code] {
                                        Button {
                                            onDetected(code)
                                            dismiss()
                                        } label: {
                                            Text(item.name)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(Palette.text)
                                                .padding(.horizontal, 11)
                                                .padding(.vertical, 7)
                                                .background(Capsule().fill(Palette.cardSoft))
                                        }
                                        .buttonStyle(.stridePress)
                                    }
                                }
                            }
                        }
                    }

                    Spacer()
                }
                .padding(Metrics.page)
            }
            .navigationTitle("扫条形码")
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

private struct BarcodeCameraPreview: UIViewRepresentable {
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        context.coordinator.start(in: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onCode: (String) -> Void
        let session = AVCaptureSession()
        var previewLayer: AVCaptureVideoPreviewLayer?
        private var delivered = false

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func start(in view: UIView) {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.ean13, .ean8, .upce, .code128]

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
            previewLayer = layer

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }

        func stop() {
            if session.isRunning {
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    self?.session.stopRunning()
                }
            }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard !delivered,
                  let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let code = obj.stringValue, !code.isEmpty else { return }
            delivered = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            stop()
            onCode(code)
        }
    }
}
