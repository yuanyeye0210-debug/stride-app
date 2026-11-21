import Foundation
import Combine
import Security

// MARK: - AI 服务商与预设模型

/// 支持的 AI 协议服务商：默认优先原生 Google Gemini REST API，同时兼容 OpenAI 协议。
enum AIProvider: String, Codable, CaseIterable, Hashable, Identifiable {
    case gemini = "gemini"
    case openAICompatible = "openai"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini: return "Google Gemini"
        case .openAICompatible: return "OpenAI 兼容"
        }
    }

    var shortName: String {
        switch self {
        case .gemini: return "Gemini"
        case .openAICompatible: return "OpenAI"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta"
        case .openAICompatible: return "https://api.openai.com/v1"
        }
    }

    var defaultChatModel: String {
        switch self {
        case .gemini: return "gemini-2.5-flash"
        case .openAICompatible: return "gpt-4o-mini"
        }
    }

    var defaultVisionModel: String {
        switch self {
        case .gemini: return "gemini-2.5-flash"
        case .openAICompatible: return "gpt-4o-mini"
        }
    }
}

/// 界面快捷选择的模型预设项。
struct AIModelPreset: Identifiable, Hashable {
    let id: String
    let label: String
    let summary: String
    let supportsVision: Bool

    static let geminiPresets: [AIModelPreset] = [
        AIModelPreset(
            id: "gemini-2.5-flash",
            label: "2.5 Flash",
            summary: "推荐 · 均衡快速 · 对话与识食全能",
            supportsVision: true
        ),
        AIModelPreset(
            id: "gemini-2.5-pro",
            label: "2.5 Pro",
            summary: "深度推理 · 适合复杂计划与动作分析",
            supportsVision: true
        ),
        AIModelPreset(
            id: "gemini-2.5-flash-lite",
            label: "2.5 Flash-Lite",
            summary: "极速轻量 · 低延迟低成本",
            supportsVision: true
        ),
        AIModelPreset(
            id: "gemini-3-flash-preview",
            label: "3 Flash 预览",
            summary: "新一代多模态快速预览版",
            supportsVision: true
        ),
        AIModelPreset(
            id: "gemini-3.1-pro-preview",
            label: "3.1 Pro 预览",
            summary: "旗舰推理预览版",
            supportsVision: true
        )
    ]

    static let openAIPresets: [AIModelPreset] = [
        AIModelPreset(
            id: "gpt-4o-mini",
            label: "gpt-4o-mini",
            summary: "均衡快速 · 支持视觉",
            supportsVision: true
        ),
        AIModelPreset(
            id: "gpt-4o",
            label: "gpt-4o",
            summary: "旗舰通用 · 支持视觉",
            supportsVision: true
        ),
        AIModelPreset(
            id: "deepseek-chat",
            label: "deepseek-chat",
            summary: "高性价比对话模型",
            supportsVision: false
        ),
        AIModelPreset(
            id: "qwen-vl-max",
            label: "qwen-vl-max",
            summary: "通义千问多模态视觉",
            supportsVision: true
        )
    ]

    static func presets(for provider: AIProvider) -> [AIModelPreset] {
        switch provider {
        case .gemini: return geminiPresets
        case .openAICompatible: return openAIPresets
        }
    }
}

// MARK: - 配置

struct AIConfig: Codable, Hashable {
    var provider: AIProvider
    var baseURL: String
    var apiKey: String
    var chatModel: String
    var visionModel: String
    var temperature: Double

    enum CodingKeys: String, CodingKey {
        case provider, baseURL, apiKey, chatModel, visionModel, temperature
    }

    /// 兼容原有参数顺序：新安装默认推荐 Google Gemini；
    /// 若调用方显式指定非 Gemini 的 baseURL / chatModel 且未传 provider，则自动推断为 OpenAI 兼容。
    init(
        baseURL: String? = nil,
        apiKey: String = "",
        chatModel: String? = nil,
        visionModel: String? = nil,
        temperature: Double = 0.6,
        provider: AIProvider? = nil
    ) {
        let resolvedProvider: AIProvider
        if let provider {
            resolvedProvider = provider
        } else if let baseURL {
            resolvedProvider = Self.inferProvider(baseURL: baseURL, model: chatModel)
        } else if let chatModel, !chatModel.lowercased().contains("gemini") {
            resolvedProvider = .openAICompatible
        } else {
            resolvedProvider = .gemini
        }

        self.provider = resolvedProvider
        self.baseURL = baseURL ?? resolvedProvider.defaultBaseURL
        self.apiKey = apiKey
        self.chatModel = chatModel ?? resolvedProvider.defaultChatModel
        self.visionModel = visionModel ?? resolvedProvider.defaultVisionModel
        self.temperature = temperature
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decodedBaseURL = try c.decodeIfPresent(String.self, forKey: .baseURL)
        let decodedApiKey = try c.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        let decodedChat = try c.decodeIfPresent(String.self, forKey: .chatModel)
        let decodedVision = try c.decodeIfPresent(String.self, forKey: .visionModel)
        let decodedTemp = try c.decodeIfPresent(Double.self, forKey: .temperature) ?? 0.6

        let resolvedProvider: AIProvider
        if let explicit = try c.decodeIfPresent(AIProvider.self, forKey: .provider) {
            resolvedProvider = explicit
        } else if let decodedBaseURL {
            resolvedProvider = Self.inferProvider(baseURL: decodedBaseURL, model: decodedChat)
        } else {
            resolvedProvider = .gemini
        }

        self.provider = resolvedProvider
        self.baseURL = decodedBaseURL ?? resolvedProvider.defaultBaseURL
        self.apiKey = decodedApiKey
        self.chatModel = decodedChat ?? resolvedProvider.defaultChatModel
        self.visionModel = decodedVision ?? resolvedProvider.defaultVisionModel
        self.temperature = decodedTemp
    }

    /// 根据接口地址与模型名推断协议类型，用于旧版持久化数据升级兼容。
    static func inferProvider(baseURL: String, model: String? = nil) -> AIProvider {
        let lowerURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Google 官方 OpenAI 兼容层路径含 /openai，走 OpenAI 协议。
        if lowerURL.contains("/openai") {
            return .openAICompatible
        }
        if lowerURL.contains("generativelanguage.googleapis.com") || lowerURL.contains(":generatecontent") {
            return .gemini
        }
        if let model, model.lowercased().hasPrefix("gemini") && lowerURL.isEmpty {
            return .gemini
        }
        return .openAICompatible
    }

    /// 切换服务商时同步更新接口地址与模型预设，避免把旧协议地址带入新协议。
    mutating func switchProvider(to target: AIProvider) {
        guard provider != target else { return }
        provider = target
        baseURL = target.defaultBaseURL
        chatModel = target.defaultChatModel
        visionModel = target.defaultVisionModel
    }

    var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

protocol AISecretBox: AnyObject {
    func read(account: String) -> String?
    func write(_ value: String, account: String) -> Bool
    func delete(account: String)
}

final class KeychainSecretBox: AISecretBox {
    let service: String

    init(service: String) {
        self.service = service
    }

    func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func write(_ value: String, account: String) -> Bool {
        delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum AIKeyVault {
    static let defaultsKey = "stride.ai.config"
    static let service = "com.yg.stride.ai"
    static let account = "apiKey"

    static func load(
        defaults: UserDefaults = .standard,
        box: AISecretBox = KeychainSecretBox(service: service),
        account: String = account
    ) -> AIConfig {
        var config = decode(defaults) ?? AIConfig()
        let legacyKey = config.apiKey
        if let stored = box.read(account: account), !stored.isEmpty {
            config.apiKey = stored
            if !legacyKey.isEmpty {
                writeDefaults(withoutKey(config), defaults: defaults)
            }
        } else if !legacyKey.isEmpty {
            if box.write(legacyKey, account: account) {
                writeDefaults(withoutKey(config), defaults: defaults)
            }
        }
        return config
    }

    static func save(
        _ config: AIConfig,
        defaults: UserDefaults = .standard,
        box: AISecretBox = KeychainSecretBox(service: service),
        account: String = account
    ) {
        if config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            box.delete(account: account)
        } else {
            _ = box.write(config.apiKey, account: account)
        }
        writeDefaults(withoutKey(config), defaults: defaults)
    }

    private static func withoutKey(_ config: AIConfig) -> AIConfig {
        var copy = config
        copy.apiKey = ""
        return copy
    }

    private static func decode(_ defaults: UserDefaults) -> AIConfig? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(AIConfig.self, from: data)
    }

    private static func writeDefaults(_ config: AIConfig, defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: defaultsKey)
        }
    }
}

final class AISettings: ObservableObject {
    static let shared = AISettings()

    @Published var config: AIConfig {
        didSet { persist() }
    }

    private init() {
        config = AIKeyVault.load()
    }

    private func persist() {
        AIKeyVault.save(config)
    }

    var isConfigured: Bool { config.isConfigured }
}

// MARK: - 错误

enum AIError: LocalizedError, Equatable {
    case notConfigured
    case badResponse(String)
    case http(Int, String)
    case timeout
    case offline
    case serverBusy
    case rateLimited
    case imageTooLarge

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "还没有配置 AI 服务。到「个人 → AI 服务接口与 Key」配置 Google Gemini 或 OpenAI 兼容 Key。"
        case .badResponse(let s):
            return "返回格式不对：\(s)"
        case .http(let code, let body):
            return "HTTP \(code)：\(body.prefix(160))"
        case .timeout:
            return "请求超时了，请检查网络后重试。"
        case .offline:
            return "现在没网，检查网络后重试。本地教练仍可用。"
        case .serverBusy:
            return "对方服务正忙，请稍后再试。"
        case .rateLimited:
            return "请求太频繁了，稍等一下再试。"
        case .imageTooLarge:
            return "这张图太大了，换一张小一点的再试。"
        }
    }
}

// MARK: - 客户端（支持 Google Gemini 原生 REST API 与 OpenAI 兼容协议）

struct AIClient {

    /// Gemini 2.5 / 3 思考模型在输出正文前会占用内部推理预算，确保 maxOutputTokens 留有充足余量避免空回。
    static let geminiMinimumMaxOutputTokens = 2048

    struct Message: Encodable {
        let role: String
        let content: Content

        enum CodingKeys: String, CodingKey { case role, content }

        enum Content: Encodable {
            case text(String)
            case parts([ContentPart])

            func encode(to encoder: Encoder) throws {
                var c = encoder.singleValueContainer()
                switch self {
                case .text(let s):
                    try c.encode(s)
                case .parts(let p):
                    try c.encode(p)
                }
            }
        }

        struct ContentPart: Encodable {
            let type: String
            var text: String?
            var imageURL: ImageURL?

            struct ImageURL: Encodable {
                let url: String
            }

            enum CodingKeys: String, CodingKey {
                case type, text
                case imageURL = "image_url"
            }

            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(type, forKey: .type)
                try c.encodeIfPresent(text, forKey: .text)
                try c.encodeIfPresent(imageURL, forKey: .imageURL)
            }
        }
    }

    // MARK: OpenAI 兼容载荷

    private struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Msg: Decodable { let content: String? }
            let message: Msg
        }
        let choices: [Choice]
    }

    // MARK: Google Gemini 原生 REST 载荷

    private struct GeminiRequest: Encodable {
        struct Content: Encodable {
            let role: String?
            let parts: [Part]
        }

        struct Part: Encodable {
            var text: String?
            var inlineData: InlineData?

            struct InlineData: Encodable {
                let mimeType: String
                let data: String
            }
        }

        struct GenerationConfig: Encodable {
            let temperature: Double
            let maxOutputTokens: Int
        }

        let systemInstruction: Content?
        let contents: [Content]
        let generationConfig: GenerationConfig
    }

    private struct GeminiResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable {
                    let text: String?
                    let thought: Bool?
                }
                let parts: [Part]?
            }
            let content: Content?
            let finishReason: String?
        }

        struct PromptFeedback: Decodable {
            let blockReason: String?
        }

        let candidates: [Candidate]?
        let promptFeedback: PromptFeedback?
    }

    private struct GeminiModelsListResponse: Decodable {
        struct ModelItem: Decodable {
            let name: String
            let supportedGenerationMethods: [String]?
        }
        let models: [ModelItem]?
    }

    private struct APIErrorEnvelope: Decodable {
        struct Detail: Decodable {
            let message: String?
        }
        let error: Detail?
    }

    // MARK: 公开调用入口

    static func complete(
        system: String?,
        messages: [Message],
        model: String,
        config: AIConfig,
        maxTokens: Int = 700,
        onRetry: (@MainActor (Int) -> Void)? = nil
    ) async throws -> String {
        guard config.isConfigured else { throw AIError.notConfigured }

        switch config.provider {
        case .gemini:
            let reqBody = buildGeminiRequest(
                system: system,
                messages: messages,
                config: config,
                maxTokens: maxTokens
            )
            return try await sendGemini(reqBody, model: model, config: config, onRetry: onRetry)

        case .openAICompatible:
            var payload: [Message] = []
            if let system, !system.isEmpty {
                payload.append(Message(role: "system", content: .text(system)))
            }
            payload.append(contentsOf: messages)

            let body = ChatRequest(
                model: model,
                messages: payload,
                temperature: config.temperature,
                max_tokens: maxTokens
            )
            return try await sendOpenAI(body, config: config, onRetry: onRetry)
        }
    }

    static func chat(
        system: String?,
        user: String,
        config: AIConfig,
        model: String? = nil,
        maxTokens: Int = 700,
        onRetry: (@MainActor (Int) -> Void)? = nil
    ) async throws -> String {
        try await complete(
            system: system,
            messages: [Message(role: "user", content: .text(user))],
            model: model ?? config.chatModel,
            config: config,
            maxTokens: maxTokens,
            onRetry: onRetry
        )
    }

    static func vision(
        imageBase64JPEG: String,
        prompt: String,
        config: AIConfig,
        maxTokens: Int = 800,
        onRetry: (@MainActor (Int) -> Void)? = nil
    ) async throws -> String {
        guard config.isConfigured else { throw AIError.notConfigured }
        try VisionImageLimits.validateBase64Length(imageBase64JPEG)

        switch config.provider {
        case .gemini:
            let reqBody = buildGeminiVisionRequest(
                imageBase64JPEG: imageBase64JPEG,
                prompt: prompt,
                config: config,
                maxTokens: maxTokens
            )
            return try await sendGemini(reqBody, model: config.visionModel, config: config, onRetry: onRetry)

        case .openAICompatible:
            let body = openAIVisionRequest(
                imageBase64JPEG: imageBase64JPEG,
                prompt: prompt,
                config: config,
                maxTokens: maxTokens
            )
            return try await sendOpenAI(body, config: config, onRetry: onRetry)
        }
    }

    /// 拉取当前 Gemini API Key 可用且支持 generateContent 的 Gemini 模型 ID 列表。
    static func listGeminiModels(config: AIConfig) async throws -> [String] {
        guard config.isConfigured else { throw AIError.notConfigured }
        guard let url = geminiModelsListURL(baseURL: config.baseURL) else {
            throw AIError.badResponse("Gemini 接口地址不是合法网址")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = AIRetryPolicy.timeoutInterval
        request.setValue(config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "x-goog-api-key")

        let data = try await executeWithRetry(request: request, onRetry: nil)
        let decoded = try JSONDecoder().decode(GeminiModelsListResponse.self, from: data)
        let rawIDs = (decoded.models ?? [])
            .filter { ($0.supportedGenerationMethods ?? []).contains("generateContent") }
            .map { normalizeGeminiModelName($0.name) }
            .filter { $0.lowercased().hasPrefix("gemini") }

        let unique = Array(Set(rawIDs))
        let preferredOrder = AIModelPreset.geminiPresets.map(\.id)
        return unique.sorted { lhs, rhs in
            let li = preferredOrder.firstIndex(of: lhs) ?? Int.max
            let ri = preferredOrder.firstIndex(of: rhs) ?? Int.max
            if li != ri { return li < ri }
            return lhs > rhs
        }
    }

    // MARK: - 序列化与解析（可单元测试）

    /// 视觉请求的 JSON：
    /// - OpenAI 兼容：`image_url` 为 `{ "url": "data:image/jpeg;base64,..." }`
    /// - Google Gemini：原生 `inlineData` `{ "mimeType": "image/jpeg", "data": "..." }`
    static func visionRequestJSON(
        imageBase64JPEG: String,
        prompt: String,
        config: AIConfig,
        maxTokens: Int = 800
    ) throws -> Data {
        try VisionImageLimits.validateBase64Length(imageBase64JPEG)
        switch config.provider {
        case .gemini:
            let req = buildGeminiVisionRequest(
                imageBase64JPEG: imageBase64JPEG,
                prompt: prompt,
                config: config,
                maxTokens: maxTokens
            )
            return try JSONEncoder().encode(req)
        case .openAICompatible:
            let req = openAIVisionRequest(
                imageBase64JPEG: imageBase64JPEG,
                prompt: prompt,
                config: config,
                maxTokens: maxTokens
            )
            return try JSONEncoder().encode(req)
        }
    }

    /// 导出 Gemini `generateContent` 请求体 JSON，用于测试与诊断。
    static func geminiRequestJSON(
        system: String?,
        messages: [Message],
        config: AIConfig,
        maxTokens: Int = 700
    ) throws -> Data {
        let req = buildGeminiRequest(system: system, messages: messages, config: config, maxTokens: maxTokens)
        return try JSONEncoder().encode(req)
    }

    /// 拼接并规整 Gemini `generateContent` 接口地址。
    static func geminiEndpointURL(baseURL: String, model: String) -> URL? {
        var root = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while root.hasSuffix("/") { root.removeLast() }
        guard !root.isEmpty else { return nil }

        // 若用户直接粘贴完整 :generateContent 地址，直接放行。
        if root.hasSuffix(":generateContent") {
            return URL(string: root)
        }

        let normalizedRoot = normalizeGeminiRootURL(root)
        let cleanModel = normalizeGeminiModelName(model)
        guard !cleanModel.isEmpty else { return nil }
        return URL(string: "\(normalizedRoot)/models/\(cleanModel):generateContent")
    }

    /// 拼接并规整 Gemini 模型列表查询地址（GET /models）。
    static func geminiModelsListURL(baseURL: String) -> URL? {
        var root = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while root.hasSuffix("/") { root.removeLast() }
        guard !root.isEmpty else { return nil }
        if let range = root.range(of: "/models/") {
            root = String(root[..<range.lowerBound])
        }
        let normalizedRoot = normalizeGeminiRootURL(root)
        return URL(string: "\(normalizedRoot)/models")
    }

    /// 解析 Gemini `generateContent` 响应体，自动过滤内部思考块（`thought == true`）。
    static func parseGeminiResponse(_ data: Data) throws -> String {
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)

        if let blockReason = decoded.promptFeedback?.blockReason, !blockReason.isEmpty {
            throw AIError.badResponse("请求被安全策略拦截：\(blockReason)")
        }

        guard let candidate = decoded.candidates?.first else {
            throw AIError.badResponse("Gemini 返回的 candidates 为空")
        }

        let parts = candidate.content?.parts ?? []
        let visibleTexts = parts
            .filter { $0.thought != true }
            .compactMap(\.text)
            .filter { !$0.isEmpty }

        let combined = visibleTexts.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        if !combined.isEmpty {
            return combined
        }

        if let reason = candidate.finishReason, !reason.isEmpty {
            throw AIError.badResponse("Gemini 未返回正文（\(reason)）")
        }
        throw AIError.badResponse("Gemini 返回正文为空")
    }

    // MARK: - 内部请求构造

    private static func normalizeGeminiRootURL(_ raw: String) -> String {
        if raw == "https://generativelanguage.googleapis.com" {
            return "\(raw)/v1beta"
        }
        return raw
    }

    private static func normalizeGeminiModelName(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("models/") {
            trimmed = String(trimmed.dropFirst("models/".count))
        }
        return trimmed
    }

    private static func buildGeminiRequest(
        system: String?,
        messages: [Message],
        config: AIConfig,
        maxTokens: Int
    ) -> GeminiRequest {
        var systemParts: [GeminiRequest.Part] = []
        if let system, !system.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            systemParts.append(.init(text: system, inlineData: nil))
        }

        var contents: [GeminiRequest.Content] = []
        for msg in messages {
            let parts = convertPartsToGemini(msg.content)
            guard !parts.isEmpty else { continue }
            if msg.role.lowercased() == "system" {
                systemParts.append(contentsOf: parts)
                continue
            }
            let geminiRole = msg.role.lowercased() == "assistant" ? "model" : "user"
            contents.append(.init(role: geminiRole, parts: parts))
        }

        let systemInstruction = systemParts.isEmpty ? nil : GeminiRequest.Content(role: nil, parts: systemParts)
        let effectiveMaxTokens = max(maxTokens, geminiMinimumMaxOutputTokens)

        return GeminiRequest(
            systemInstruction: systemInstruction,
            contents: contents,
            generationConfig: .init(temperature: config.temperature, maxOutputTokens: effectiveMaxTokens)
        )
    }

    private static func buildGeminiVisionRequest(
        imageBase64JPEG: String,
        prompt: String,
        config: AIConfig,
        maxTokens: Int
    ) -> GeminiRequest {
        let parts: [GeminiRequest.Part] = [
            .init(text: prompt, inlineData: nil),
            .init(text: nil, inlineData: .init(mimeType: "image/jpeg", data: imageBase64JPEG))
        ]
        let effectiveMaxTokens = max(maxTokens, geminiMinimumMaxOutputTokens)
        return GeminiRequest(
            systemInstruction: nil,
            contents: [.init(role: "user", parts: parts)],
            generationConfig: .init(temperature: config.temperature, maxOutputTokens: effectiveMaxTokens)
        )
    }

    private static func convertPartsToGemini(_ content: Message.Content) -> [GeminiRequest.Part] {
        switch content {
        case .text(let s):
            return [.init(text: s, inlineData: nil)]
        case .parts(let items):
            var result: [GeminiRequest.Part] = []
            for item in items {
                if let text = item.text, !text.isEmpty {
                    result.append(.init(text: text, inlineData: nil))
                } else if let urlStr = item.imageURL?.url, let inline = parseDataURI(urlStr) {
                    result.append(.init(text: nil, inlineData: inline))
                }
            }
            return result
        }
    }

    private static func parseDataURI(_ uri: String) -> GeminiRequest.Part.InlineData? {
        guard uri.hasPrefix("data:"), let comma = uri.firstIndex(of: ",") else { return nil }
        let header = String(uri[uri.index(uri.startIndex, offsetBy: 5)..<comma])
        let mimeType = header.split(separator: ";").first.map(String.init) ?? "image/jpeg"
        let base64 = String(uri[uri.index(after: comma)...])
        guard !base64.isEmpty else { return nil }
        return .init(mimeType: mimeType, data: base64)
    }

    private static func openAIVisionRequest(
        imageBase64JPEG: String,
        prompt: String,
        config: AIConfig,
        maxTokens: Int
    ) -> ChatRequest {
        let parts: [Message.ContentPart] = [
            Message.ContentPart(type: "text", text: prompt, imageURL: nil),
            Message.ContentPart(
                type: "image_url",
                text: nil,
                imageURL: Message.ContentPart.ImageURL(url: "data:image/jpeg;base64,\(imageBase64JPEG)")
            )
        ]
        return ChatRequest(
            model: config.visionModel,
            messages: [Message(role: "user", content: .parts(parts))],
            temperature: config.temperature,
            max_tokens: maxTokens
        )
    }

    // MARK: - 传输

    private static func sendGemini(
        _ body: GeminiRequest,
        model: String,
        config: AIConfig,
        onRetry: (@MainActor (Int) -> Void)? = nil
    ) async throws -> String {
        guard let url = geminiEndpointURL(baseURL: config.baseURL, model: model) else {
            throw AIError.badResponse("Gemini 接口地址或模型名不合法")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = AIRetryPolicy.timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(body)

        let data = try await executeWithRetry(request: request, onRetry: onRetry)
        return try parseGeminiResponse(data)
    }

    private static func sendOpenAI(
        _ body: ChatRequest,
        config: AIConfig,
        onRetry: (@MainActor (Int) -> Void)? = nil
    ) async throws -> String {
        var urlString = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if urlString.hasSuffix("/") { urlString.removeLast() }
        if !urlString.hasSuffix("/chat/completions") { urlString += "/chat/completions" }

        guard let url = URL(string: urlString) else {
            throw AIError.badResponse("Base URL 不是合法网址")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = AIRetryPolicy.timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let data = try await executeWithRetry(request: request, onRetry: onRetry)
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content, !text.isEmpty else {
            throw AIError.badResponse("choices 为空")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 通用重试传输器：只重试瞬时错误（超时、断网、5xx、429），最多 3 次，退避 1 秒、2 秒。
    private static func executeWithRetry(
        request: URLRequest,
        onRetry: (@MainActor (Int) -> Void)?
    ) async throws -> Data {
        var attempt = 0
        while true {
            attempt += 1
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw AIError.badResponse("没有 HTTP 响应")
                }
                guard (200..<300).contains(http.statusCode) else {
                    let message = extractErrorMessage(from: data)
                    throw AIRetryPolicy.mapHTTPStatus(http.statusCode, body: message)
                }
                return data
            } catch is CancellationError {
                throw CancellationError()
            } catch let aiError as AIError {
                if AIRetryPolicy.shouldRetry(error: aiError, attempt: attempt) {
                    // 先告诉界面下一轮是第几次，再退避等一会儿。
                    await MainActor.run { onRetry?(attempt + 1) }
                    try await Task.sleep(nanoseconds: UInt64(AIRetryPolicy.backoffDelay(attempt: attempt) * 1_000_000_000))
                    continue
                }
                throw aiError
            } catch {
                // 有些 Foundation 版本把取消报成 URLError(.cancelled) 而不是 CancellationError。
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    throw CancellationError()
                }
                let mapped = AIRetryPolicy.mapNetworkError(error, statusCode: nil)
                if AIRetryPolicy.shouldRetry(error: mapped, attempt: attempt) {
                    await MainActor.run { onRetry?(attempt + 1) }
                    try await Task.sleep(nanoseconds: UInt64(AIRetryPolicy.backoffDelay(attempt: attempt) * 1_000_000_000))
                    continue
                }
                throw mapped
            }
        }
    }

    /// 优先从 Gemini / OpenAI 的 JSON 错误包提取可读 message，失败则退回原始文本。
    private static func extractErrorMessage(from data: Data) -> String {
        if let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data),
           let msg = envelope.error?.message,
           !msg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return msg
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - JSON 提取工具

enum JSONExtract {
    /// 从模型回复里抠出第一段 JSON（容忍 ```json 包裹和前后废话）
    static func firstObject(from text: String) -> Data? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else { return nil }
        let slice = text[start...end]
        return String(slice).data(using: .utf8)
    }
}
