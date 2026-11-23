import SwiftUI
import UIKit
import PhotosUI

enum FoodScanMode: String, CaseIterable, Identifiable {
    case meal = "拍餐食"
    case barcode = "扫条形码"
    case label = "扫营养表"

    var id: String { rawValue }
}

struct FoodScanView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var ai: AISettings
    @Environment(\.dismiss) private var dismiss

    var startWithPhotoPicker: Bool = false

    @State private var scanMode: FoodScanMode = .meal
    @State private var showBarcodeScanner = false
    @State private var showCameraPicker = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var showAutoPicker = false
    @State private var didAutoPresentPicker = false
    @State private var previewImage: UIImage?
    @State private var scanStageText: String = ""
    @State private var scanLinePhase = false
    @State private var isolatedOutline = false
    @State private var items: [FoodItem] = []
    @State private var meal: Meal = .lunch
    @State private var busy = false
    @State private var retryAttempt: Int?
    @State private var errorText: String?
    @State private var query = ""
    @State private var recognizedByAI = false
    @Namespace private var modeNS

    private var usedToday: Int { store.state.quotas.used("food") }
    private var remaining: Int { Gate.foodRemaining(used: usedToday) }

    private var totalKcal: Double { items.reduce(0) { $0 + $1.kcal } }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        quotaBar
                        modePicker
                        if scanMode == .barcode {
                            barcodeCard
                        } else {
                            photoCard
                        }

                        if let errorText {
                            errorCard(errorText)
                        }

                        if !items.isEmpty {
                            itemsCard
                            mealPicker
                        }

                        manualCard
                        saveButton
                    }
                    .padding(.horizontal, Metrics.page)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("记一餐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
            .photosPicker(isPresented: $showAutoPicker, selection: $pickerItem, matching: .images, photoLibrary: .shared())
            .sheet(isPresented: $showCameraPicker) {
                SafeCameraPicker { image in
                    Task { await processImage(image) }
                } onUnavailable: {
                    errorText = "当前设备无可用相机，已切换为相册选择"
                    showAutoPicker = true
                } onClose: {
                    showCameraPicker = false
                }
            }
            .sheet(isPresented: $showBarcodeScanner) {
                BarcodeScannerSheet { code in
                    Task { await handleBarcode(code) }
                }
            }
            .onAppear {
                if startWithPhotoPicker && !didAutoPresentPicker {
                    didAutoPresentPicker = true
                    showAutoPicker = true
                }
            }
            .onChange(of: pickerItem) { _, newValue in
                Task { await handle(newValue) }
            }
        }
    }

    // MARK: - 额度

    private var quotaBar: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Palette.amber.opacity(0.14)).frame(width: 34, height: 34)
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.amber)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("AI 热量识别")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Text(ai.isConfigured ? "Gemini 视觉识别 · 今日剩余 \(remaining) 次" : "当前离线，可手动记录")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textFaint)
            }
            Spacer()
            Text("\(usedToday)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.amber)
        }
        .padding(14)
        .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 识别模式切换与条形码卡片

    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(FoodScanMode.allCases) { mode in
                let active = scanMode == mode
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                        scanMode = mode
                        errorText = nil
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 13, weight: active ? .semibold : .medium))
                        .foregroundStyle(active ? Color.black : Palette.textDim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if active {
                                Capsule().fill(Color.white)
                                    .matchedGeometryEffect(id: "foodScanMode", in: modeNS)
                            }
                        }
                }
                .buttonStyle(.stridePress)
            }
        }
        .padding(4)
        .background(Capsule().fill(Palette.card))
        .sensoryFeedback(.selection, trigger: scanMode)
    }

    private var barcodeCard: some View {
        Button {
            showBarcodeScanner = true
        } label: {
            VStack(spacing: 10) {
                if busy {
                    ProgressView().tint(Palette.green)
                    Text("正在检索商品营养数据…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.textDim)
                } else {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(Palette.green)
                    Text("扫描商品条形码 / 手动输入")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.text)
                    Text("支持常见零食饮料及 Open Food Facts 数据库")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textFaint)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 34)
            .card(radius: 24, fill: Palette.cardSoft, stroke: Palette.stroke)
        }
        .buttonStyle(.strideCard)
        .disabled(busy)
    }

    // MARK: - 拍照与可视化食物抠图描边识别

    private var photoCard: some View {
        VStack(spacing: 12) {
            if let previewImage {
                ZStack(alignment: .topLeading) {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .strideScanBeam(active: busy, color: Palette.green)

                    HStack(spacing: 6) {
                        if busy {
                            ProgressView()
                                .scaleEffect(0.75)
                                .tint(Color.white)
                        } else {
                            Image(systemName: isolatedOutline ? "sparkles" : "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Palette.green)
                        }
                        Text(busy ? scanStageText : (isolatedOutline ? "食物区域已描边 · 背景已马赛克" : "视觉识别完成"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.68)))
                    .padding(10)
                }
            }

            HStack(spacing: 10) {
                Button {
                    showCameraPicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(scanMode == .label ? "拍营养表" : "拍一张")
                            .font(.system(size: 14.5, weight: .bold))
                    }
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.green))
                }
                .buttonStyle(.stridePress)
                .disabled(busy)

                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 16, weight: .semibold))
                        Text("从相册选")
                            .font(.system(size: 14.5, weight: .semibold))
                    }
                    .foregroundStyle(Palette.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.cardSoft))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.stroke, lineWidth: 1))
                }
                .disabled(busy)
            }

            Text(scanMode == .label ? "拍包装背面“营养成分表”即可自动换算每 100g 热量" : "拍照后自动检测食物轮廓、背景马赛克隔离并识别克重与营养")
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.textFaint)
                .multilineTextAlignment(.center)
        }
        .padding(14)
        .card(radius: 24, fill: Palette.card, stroke: Palette.stroke)
    }

    private func errorCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Palette.amber)
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.textDim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 16, fill: Palette.amber.opacity(0.08), stroke: Palette.amber.opacity(0.25))
    }

    // MARK: - 结果

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("识别结果")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.text)
                if recognizedByAI {
                    Pill(text: "AI", fg: Palette.greenText, bg: Palette.greenDeep, size: 10)
                }
                Spacer()
                Text("\(Int(totalKcal)) kcal")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.amber)
            }

            ForEach(items.indices, id: \.self) { i in
                HStack(spacing: 8) {
                    Text(items[i].name)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.text)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("0", value: Binding(
                        get: { items[i].grams },
                        set: { newValue in
                            let old = items[i].grams
                            items[i].grams = newValue
                            if old > 0 { scale(index: i, factor: newValue / old) }
                        }
                    ), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.text)
                        .frame(width: 58)

                    Text("g")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textFaint)

                    Text("\(Int(items[i].kcal))")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.textDim)
                        .frame(width: 46, alignment: .trailing)

                    Button {
                        items.remove(at: i)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.textFaint)
                    }
                    .buttonStyle(.stridePress)
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 14) {
                macro("蛋白", items.reduce(0) { $0 + $1.protein }, Palette.green)
                macro("碳水", items.reduce(0) { $0 + $1.carbs }, Palette.blue)
                macro("脂肪", items.reduce(0) { $0 + $1.fat }, Palette.amber)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
        .sensoryFeedback(.impact(weight: .light), trigger: items.count)
    }

    private func macro(_ title: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 10)).foregroundStyle(Palette.textFaint)
            Text("\(Int(value)) g")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .numericRoll(value: Int(value))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mealPicker: some View {
        HStack(spacing: 6) {
            ForEach(Meal.allCases) { m in
                Button {
                    meal = m
                } label: {
                    Text(m.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(meal == m ? Color.black : Palette.textDim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(meal == m ? Color.white : Palette.card))
                }
                .buttonStyle(.stridePress)
            }
        }
        .sensoryFeedback(.selection, trigger: meal)
    }

    // MARK: - 手动

    private var manualCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("或者手动加")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.text)

            TextField("搜食物，比如「鸡胸」", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.cardSoft))

            let results = FoodDatabase.search(query).prefix(6)
            ForEach(Array(results)) { template in
                Button {
                    items.append(template.item(grams: template.defaultGrams))
                    query = ""
                } label: {
                    HStack {
                        Text(template.name)
                            .font(.system(size: 13.5))
                            .foregroundStyle(Palette.text)
                        Spacer()
                        Text("\(Int(template.kcal100)) kcal/100g")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Palette.textFaint)
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.green)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.strideRow(radius: 10))
            }
        }
        .padding(16)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 保存

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text(items.isEmpty ? "还没有食物" : "保存 \(Int(totalKcal)) kcal")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(items.isEmpty ? Palette.textDim : Color.black)
                .numericRoll(value: Int(totalKcal))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(items.isEmpty ? Palette.cardHigh : Color.white)
                )
        }
        .buttonStyle(StridePressButtonStyle(scale: 0.965, pressedOpacity: 0.9, haptic: .medium))
        .disabled(items.isEmpty)
    }

    // MARK: - 行为

    private func handle(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorText = "读不到这张图"
                return
            }
            await processImage(image)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func processImage(_ rawImage: UIImage) async {
        errorText = nil
        guard ai.isConfigured else {
            errorText = "当前离线或 AI 服务暂不可用，您可以先手动添加食物记录。"
            return
        }
        guard Gate.canUseFoodAI(used: usedToday) else {
            errorText = "今天的识别次数用完了。可以手动记录。"
            return
        }

        busy = true
        isolatedOutline = false
        previewImage = rawImage
        scanStageText = scanMode == .label ? "1/2 正在校准营养成分表…" : "1/3 正在检测食物主体轮廓…"
        scanLinePhase = true
        defer {
            busy = false
            retryAttempt = nil
            scanLinePhase = false
        }

        var imageForAI = rawImage
        if scanMode == .meal {
            let isolated = await FoodSubjectIsolator.isolateFood(from: rawImage)
            previewImage = isolated.previewImage
            isolatedOutline = isolated.isolatedSubjectFound
            imageForAI = isolated.previewImage
            scanStageText = isolated.isolatedSubjectFound
                ? "2/3 已描出食物并马赛克背景 · Gemini 分析克重与营养…"
                : "2/3 正在发送焦点区域至 Gemini 分析克重与营养…"
        } else {
            scanStageText = "2/2 Gemini 正在解析营养成分与热量…"
        }

        do {
            let result = if scanMode == .label {
                try await FoodRecognition.estimateNutritionLabel(image: imageForAI, config: ai.config, onRetry: { retryAttempt = $0 })
            } else {
                try await FoodRecognition.estimate(image: imageForAI, config: ai.config, onRetry: { retryAttempt = $0 })
            }
            items = result
            recognizedByAI = true
            store.state.quotas.bump("food")
            store.saveNow()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func handleBarcode(_ code: String) async {
        errorText = nil
        busy = true
        defer { busy = false }
        do {
            let found = try await BarcodeFoodLookup.lookup(barcode: code)
            items = [found]
            recognizedByAI = false
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func scale(index i: Int, factor: Double) {
        guard factor.isFinite, factor > 0 else { return }
        items[i].kcal *= factor
        items[i].protein *= factor
        items[i].carbs *= factor
        items[i].fat *= factor
    }

    private func save() {
        let entry = FoodEntry(date: Date(), meal: meal, items: items, recognizedByAI: recognizedByAI)
        store.addFood(entry)
        dismiss()
    }
}
