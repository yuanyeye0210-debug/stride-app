import SwiftUI

struct AISettingsView: View {
    @EnvironmentObject private var ai: AISettings
    @Environment(\.dismiss) private var dismiss

    @State private var draft = AIConfig()
    @State private var revealKey = false
    @State private var testing = false
    @State private var testResult: String?
    @State private var testOK = false

    @State private var loadingModels = false
    @State private var fetchedGeminiModels: [String] = []
    @State private var modelsFetchError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        providerSelector
                        note
                        apiKeyCard
                        modelSectionCard(
                            title: "对话模型",
                            subtitle: draft.provider == .gemini
                                ? "用于 AI 教练对话与训练分析（Gemini 全系支持中文与深度推理）"
                                : "用于 AI 教练对话，例如 gpt-4o-mini / deepseek-chat",
                            text: $draft.chatModel,
                            visionOnly: false
                        )
                        modelSectionCard(
                            title: "视觉模型",
                            subtitle: draft.provider == .gemini
                                ? "用于拍照识食热量估算（Gemini 全系原生多模态，可直接与对话同模型）"
                                : "用于拍照热量识别，需要模型支持图片输入",
                            text: $draft.visionModel,
                            visionOnly: true,
                            showSyncWithChat: true
                        )

                        if draft.provider == .gemini {
                            remoteModelsDiscoveryCard
                        }

                        baseURLCard
                        temperatureCard
                        testSection
                        saveButton
                    }
                    .padding(Metrics.page)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("AI 服务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
            .onAppear { draft = ai.config }
        }
    }

    // MARK: - 服务商选择（Google Gemini / OpenAI 兼容）

    private var providerSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("AI 服务商")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text(draft.provider == .gemini ? "原生 REST 协议" : "Chat Completions")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Palette.textFaint)
            }

            HStack(spacing: 10) {
                ForEach(AIProvider.allCases) { item in
                    let selected = draft.provider == item
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            draft.switchProvider(to: item)
                            testResult = nil
                            modelsFetchError = nil
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: item == .gemini ? "sparkles" : "globe")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(
                                    selected
                                        ? (item == .gemini ? Palette.blue : Palette.green)
                                        : Palette.textDim
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 5) {
                                    Text(item.displayName)
                                        .font(.system(size: 13.5, weight: .bold))
                                        .foregroundStyle(Palette.text)
                                        .lineLimit(1)
                                    if item == .gemini {
                                        Text("推荐")
                                            .font(.system(size: 9.5, weight: .bold))
                                            .foregroundStyle(Color.black)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1.5)
                                            .background(Capsule().fill(Palette.green))
                                    }
                                }
                                Text(item == .gemini ? "Gemini 2.5 / 3 原生直连" : "OpenAI / DeepSeek / 中转")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(Palette.textFaint)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selected ? Palette.cardSoft : Palette.bg.opacity(0.45))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    selected
                                        ? (item == .gemini ? Palette.blue.opacity(0.75) : Palette.green.opacity(0.75))
                                        : Palette.stroke,
                                    lineWidth: selected ? 1.4 : 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 隐私与使用说明

    private var note: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: draft.provider == .gemini ? "sparkles" : "info.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.blue)
                Text(
                    draft.provider == .gemini
                        ? "已内置 Google Gemini 原生接口：在 Google AI Studio（aistudio.google.com）申请免费或付费 API Key 粘贴到下方，即可同时启用 AI 教练与拍照热量识别。"
                        : "不填也能用：教练会切到本地规则引擎，热量识别可以手动记录。填好之后所有 AI 功能才接真模型。"
                )
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.textDim)
                .fixedSize(horizontal: false, vertical: true)
            }
            Text("接口地址与 Key 仅保存在本机（Key 加密存于系统钥匙串）。发起对话或识食时，请求直接发往你配置的目标地址，不经过 Stride 服务器。清空 Key 即停止发送。")
                .font(.system(size: 12))
                .foregroundStyle(Palette.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 16, fill: Palette.blue.opacity(0.07), stroke: Palette.blue.opacity(0.2))
    }

    // MARK: - API Key

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(draft.provider == .gemini ? "Gemini API Key" : "API Key")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Button {
                    revealKey.toggle()
                } label: {
                    Image(systemName: revealKey ? "eye.slash" : "eye")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.textDim)
                }
                .buttonStyle(.plain)
            }

            Group {
                if revealKey {
                    TextField(draft.provider == .gemini ? "AIzaSy..." : "sk-...", text: $draft.apiKey)
                } else {
                    SecureField(draft.provider == .gemini ? "AIzaSy..." : "sk-...", text: $draft.apiKey)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(size: 14, design: .monospaced))
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 13).fill(Palette.cardSoft))

            Text(
                draft.provider == .gemini
                    ? "保存在本机系统钥匙串，通过 x-goog-api-key 请求头安全发送，不会写入 UserDefaults"
                    : "保存在本机系统钥匙串，请求模型时以 Bearer 令牌发送，不会写入 UserDefaults"
            )
            .font(.system(size: 10.5))
            .foregroundStyle(Palette.textFaint)
        }
        .padding(14)
        .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 模型选择与快捷预设

    private func modelSectionCard(
        title: String,
        subtitle: String,
        text: Binding<String>,
        visionOnly: Bool,
        showSyncWithChat: Bool = false
    ) -> some View {
        let presets = AIModelPreset.presets(for: draft.provider).filter { !visionOnly || $0.supportsVision }

        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Spacer()
                if showSyncWithChat && draft.visionModel != draft.chatModel {
                    Button {
                        draft.visionModel = draft.chatModel
                    } label: {
                        Text("同步对话模型")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.green)
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("输入或点选下方模型 ID", text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 13).fill(Palette.cardSoft))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets) { preset in
                        let active = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines) == preset.id
                        Button {
                            text.wrappedValue = preset.id
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.label)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(active ? Color.black : Palette.text)
                                Text(preset.summary)
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(active ? Color.black.opacity(0.75) : Palette.textFaint)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(active ? Palette.green : Palette.cardSoft)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(active ? Palette.green : Palette.stroke, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text(subtitle)
                .font(.system(size: 10.5))
                .foregroundStyle(Palette.textFaint)
        }
        .padding(14)
        .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 动态拉取账号可用 Gemini 模型

    private var remoteModelsDiscoveryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("拉取可用 Gemini 模型")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.text)
                    Text("填好 Key 后可实时读取你账号下支持对话与识食的模型列表")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Palette.textFaint)
                }
                Spacer()
                Button {
                    Task { await fetchAvailableModels() }
                } label: {
                    HStack(spacing: 5) {
                        if loadingModels {
                            ProgressView()
                                .scaleEffect(0.75)
                                .tint(Palette.text)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text(loadingModels ? "拉取中" : "获取列表")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Palette.cardSoft))
                    .overlay(Capsule().stroke(Palette.stroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(loadingModels || !draft.isConfigured)
                .opacity(draft.isConfigured ? 1 : 0.45)
            }

            if let modelsFetchError {
                Text(modelsFetchError)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !fetchedGeminiModels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(fetchedGeminiModels, id: \.self) { modelID in
                            let selected = draft.chatModel == modelID && draft.visionModel == modelID
                            Button {
                                draft.chatModel = modelID
                                draft.visionModel = modelID
                            } label: {
                                Text(modelID)
                                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(selected ? Color.black : Palette.text)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule().fill(selected ? Palette.blue : Palette.cardSoft)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Text("点击任意拉取到的模型，将同时设为对话模型与视觉模型。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Palette.textFaint)
            }
        }
        .padding(14)
        .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 接口地址

    private var baseURLCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("接口地址")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Spacer()
                if draft.baseURL != draft.provider.defaultBaseURL {
                    Button {
                        draft.baseURL = draft.provider.defaultBaseURL
                    } label: {
                        Text("恢复官方地址")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.blue)
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField(draft.provider.defaultBaseURL, text: $draft.baseURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .font(.system(size: 13.5, design: .monospaced))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 13).fill(Palette.cardSoft))

            Text(
                draft.provider == .gemini
                    ? "默认直连 Google 官方端点（.../v1beta）；若使用自建 Gemini 反代，直接替换为你的代理地址即可"
                    : "OpenAI 兼容地址，例如 https://api.openai.com/v1 或自建网关"
            )
            .font(.system(size: 10.5))
            .foregroundStyle(Palette.textFaint)
        }
        .padding(14)
        .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 温度

    private var temperatureCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("温度")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text(String(format: "%.1f", draft.temperature))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.green)
            }
            Slider(value: $draft.temperature, in: 0...1.2, step: 0.1)
                .tint(Palette.green)
        }
        .padding(14)
        .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 测试连接与保存

    private var testSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { await test() }
            } label: {
                HStack(spacing: 6) {
                    if testing {
                        ProgressView().tint(Palette.text)
                    } else {
                        Image(systemName: "bolt.horizontal.fill").font(.system(size: 12))
                    }
                    Text(testing ? "正在测试 \(draft.provider.shortName) 连接…" : "测试连接")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Palette.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .card(radius: 16, fill: Palette.card, stroke: Palette.stroke)
            }
            .buttonStyle(.plain)
            .disabled(testing)

            if let testResult {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: testOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 12.5))
                        .foregroundStyle(testOK ? Palette.green : Palette.red)
                    Text(testResult)
                        .font(.system(size: 12))
                        .foregroundStyle(testOK ? Palette.green : Palette.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(
                    radius: 12,
                    fill: (testOK ? Palette.green : Palette.red).opacity(0.09),
                    stroke: (testOK ? Palette.green : Palette.red).opacity(0.28)
                )
            }
        }
    }

    private var saveButton: some View {
        Button {
            var cleaned = draft
            cleaned.baseURL = cleaned.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            cleaned.apiKey = cleaned.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            cleaned.chatModel = cleaned.chatModel.trimmingCharacters(in: .whitespacesAndNewlines)
            cleaned.visionModel = cleaned.visionModel.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.baseURL.isEmpty { cleaned.baseURL = cleaned.provider.defaultBaseURL }
            if cleaned.chatModel.isEmpty { cleaned.chatModel = cleaned.provider.defaultChatModel }
            if cleaned.visionModel.isEmpty { cleaned.visionModel = cleaned.provider.defaultVisionModel }
            ai.config = cleaned
            dismiss()
        } label: {
            Text("保存配置")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - 操作

    private func test() async {
        testing = true
        testResult = nil
        defer { testing = false }
        do {
            let reply = try await AIClient.chat(
                system: nil,
                user: "只回复两个字：可用",
                config: draft,
                maxTokens: 64
            )
            testOK = true
            testResult = "连接成功（\(draft.provider.shortName) · \(draft.chatModel)）：\(reply.prefix(32))"
        } catch {
            testOK = false
            testResult = error.localizedDescription
        }
    }

    private func fetchAvailableModels() async {
        loadingModels = true
        modelsFetchError = nil
        defer { loadingModels = false }
        do {
            let models = try await AIClient.listGeminiModels(config: draft)
            fetchedGeminiModels = models
            if models.isEmpty {
                modelsFetchError = "未查询到支持对话的 Gemini 模型，请检查 Key 权限或地址。"
            }
        } catch {
            modelsFetchError = error.localizedDescription
        }
    }
}
