import Foundation
import Combine
import Security

// MARK: - 配置

struct AIConfig: Codable, Hashable {
    var baseURL: String = "https://api.openai.com/v1"
    var apiKey: String = ""
    var chatModel: String = "gpt-4o-mini"
    var visionModel: String = "gpt-4o-mini"
    var temperature: Double = 0.6

    var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !baseURL.isEmpty
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

enum AIError: LocalizedError {
    case notConfigured
    case badResponse(String)
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "还没有配置 AI 服务。到「我的 → AI 服务」填一个 OpenAI 兼容的地址和 Key。"
        case .badResponse(let s):
            return "返回格式不对：\(s)"
        case .http(let code, let body):
            return "HTTP \(code)：\(body.prefix(160))"
        }
    }
}

// MARK: - 客户端（OpenAI 兼容协议）

struct AIClient {

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

    static func complete(
        system: String?,
        messages: [Message],
        model: String,
        config: AIConfig,
        maxTokens: Int = 700
    ) async throws -> String {
        guard config.isConfigured else { throw AIError.notConfigured }

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

        return try await send(body, config: config)
    }

    static func chat(
        system: String?,
        user: String,
        config: AIConfig,
        model: String? = nil,
        maxTokens: Int = 700
    ) async throws -> String {
        try await complete(
            system: system,
            messages: [Message(role: "user", content: .text(user))],
            model: model ?? config.chatModel,
            config: config,
            maxTokens: maxTokens
        )
    }

    static func vision(
        imageBase64JPEG: String,
        prompt: String,
        config: AIConfig,
        maxTokens: Int = 800
    ) async throws -> String {
        let body = visionRequest(imageBase64JPEG: imageBase64JPEG, prompt: prompt, config: config, maxTokens: maxTokens)
        return try await send(body, config: config)
    }

    /// 视觉请求的 JSON，image_url 是 `{ "url": "data:image/jpeg;base64,..." }`。
    static func visionRequestJSON(
        imageBase64JPEG: String,
        prompt: String,
        config: AIConfig,
        maxTokens: Int = 800
    ) throws -> Data {
        try JSONEncoder().encode(visionRequest(imageBase64JPEG: imageBase64JPEG, prompt: prompt, config: config, maxTokens: maxTokens))
    }

    private static func visionRequest(
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

    private static func send(_ body: ChatRequest, config: AIConfig) async throws -> String {
        var urlString = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if urlString.hasSuffix("/") { urlString.removeLast() }
        if !urlString.hasSuffix("/chat/completions") { urlString += "/chat/completions" }

        guard let url = URL(string: urlString) else {
            throw AIError.badResponse("Base URL 不是合法网址")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIError.badResponse("没有 HTTP 响应")
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AIError.http(http.statusCode, text)
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content, !text.isEmpty else {
            throw AIError.badResponse("choices 为空")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
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
