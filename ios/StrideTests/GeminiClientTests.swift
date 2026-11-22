import XCTest
@testable import Stride

final class GeminiClientTests: XCTestCase {

    func testDefaultAIConfigUsesGemini() {
        let config = AIConfig()
        XCTAssertEqual(config.provider, .gemini)
        XCTAssertEqual(config.baseURL, "https://generativelanguage.googleapis.com/v1beta")
        XCTAssertEqual(config.chatModel, "gemini-flash-latest")
        XCTAssertEqual(config.visionModel, "gemini-flash-latest")
        XCTAssertFalse(config.isConfigured)
    }

    func testModuleAutoRoutingAndFallbackChains() {
        XCTAssertEqual(CoachEngine.useCase(for: "今天练什么"), .coachChat)
        XCTAssertEqual(CoachEngine.useCase(for: "帮我分析一下最近四周分化训练周期与瓶颈"), .coachDeepAnalysis)

        let chatChain = AIClient.geminiModelCandidates(primary: "", useCase: .coachChat)
        XCTAssertEqual(chatChain, ["gemini-flash-latest", "gemini-3.8-flash", "gemini-flash-lite-latest"])

        let deepChain = AIClient.geminiModelCandidates(primary: "", useCase: .coachDeepAnalysis)
        XCTAssertEqual(deepChain.first, "gemini-pro-latest")
        XCTAssertTrue(deepChain.contains("gemini-flash-lite-latest"))

        let visionChain = AIClient.geminiModelCandidates(primary: "", useCase: .foodVision)
        XCTAssertEqual(visionChain, ["gemini-flash-latest", "gemini-3.8-flash", "gemini-flash-lite-latest"])
    }

    func testLegacyJSONWithoutProviderDecodesBackwardCompatibly() throws {
        let legacyOpenAI = """
        {
          "baseURL": "https://api.openai.com/v1",
          "apiKey": "",
          "chatModel": "gpt-4o-mini",
          "visionModel": "gpt-4o-mini",
          "temperature": 0.5
        }
        """.data(using: .utf8)!
        let decodedOpenAI = try JSONDecoder().decode(AIConfig.self, from: legacyOpenAI)
        XCTAssertEqual(decodedOpenAI.provider, .openAICompatible)
        XCTAssertEqual(decodedOpenAI.chatModel, "gpt-4o-mini")

        let legacyGemini = """
        {
          "baseURL": "https://generativelanguage.googleapis.com/v1beta",
          "apiKey": "",
          "chatModel": "gemini-2.5-pro",
          "visionModel": "gemini-2.5-flash",
          "temperature": 0.4
        }
        """.data(using: .utf8)!
        let decodedGemini = try JSONDecoder().decode(AIConfig.self, from: legacyGemini)
        XCTAssertEqual(decodedGemini.provider, .gemini)
        XCTAssertEqual(decodedGemini.chatModel, "gemini-2.5-pro")

        let openAICompatLayer = AIConfig.inferProvider(
            baseURL: "https://generativelanguage.googleapis.com/v1beta/openai",
            model: "gemini-2.5-flash"
        )
        XCTAssertEqual(openAICompatLayer, .openAICompatible)
    }

    func testGeminiEndpointURLNormalization() {
        XCTAssertEqual(
            AIClient.geminiEndpointURL(
                baseURL: "https://generativelanguage.googleapis.com/v1beta/",
                model: "gemini-2.5-flash"
            )?.absoluteString,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
        )

        XCTAssertEqual(
            AIClient.geminiEndpointURL(
                baseURL: "https://generativelanguage.googleapis.com",
                model: "models/gemini-2.5-pro"
            )?.absoluteString,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent"
        )

        XCTAssertEqual(
            AIClient.geminiEndpointURL(
                baseURL: "https://my-proxy.example.com/v1beta",
                model: "gemini-3-flash-preview"
            )?.absoluteString,
            "https://my-proxy.example.com/v1beta/models/gemini-3-flash-preview:generateContent"
        )

        XCTAssertEqual(
            AIClient.geminiModelsListURL(
                baseURL: "https://generativelanguage.googleapis.com/v1beta/"
            )?.absoluteString,
            "https://generativelanguage.googleapis.com/v1beta/models"
        )
    }

    func testGeminiRequestJSONBuildsSystemInstructionAndRoleMapping() throws {
        let config = AIConfig(
            baseURL: "https://generativelanguage.googleapis.com/v1beta",
            apiKey: "AIza-test",
            chatModel: "gemini-2.5-flash",
            visionModel: "gemini-2.5-flash",
            temperature: 0.4,
            provider: .gemini
        )
        let messages: [AIClient.Message] = [
            .init(role: "user", content: .text("今天练什么")),
            .init(role: "assistant", content: .text("卧推 4 组")),
            .init(role: "user", content: .text("重量怎么定"))
        ]

        let data = try AIClient.geminiRequestJSON(
            system: "你是力量教练",
            messages: messages,
            config: config,
            maxTokens: 64
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let systemInstruction = json["systemInstruction"] as? [String: Any]
        let systemParts = systemInstruction?["parts"] as? [[String: Any]]
        XCTAssertEqual(systemParts?.first?["text"] as? String, "你是力量教练")

        let contents = try XCTUnwrap(json["contents"] as? [[String: Any]])
        XCTAssertEqual(contents.count, 3)
        XCTAssertEqual(contents[0]["role"] as? String, "user")
        XCTAssertEqual(contents[1]["role"] as? String, "model")
        XCTAssertEqual(contents[2]["role"] as? String, "user")

        let genConfig = try XCTUnwrap(json["generationConfig"] as? [String: Any])
        let maxOut = try XCTUnwrap(genConfig["maxOutputTokens"] as? Int)
        XCTAssertGreaterThanOrEqual(maxOut, AIClient.geminiMinimumMaxOutputTokens)
    }

    func testGeminiVisionRequestUsesInlineDataAndRejectsOversize() throws {
        let config = AIConfig(
            baseURL: "https://generativelanguage.googleapis.com/v1beta",
            apiKey: "AIza-test",
            chatModel: "gemini-2.5-flash",
            visionModel: "gemini-2.5-flash",
            temperature: 0.2,
            provider: .gemini
        )
        let data = try AIClient.visionRequestJSON(
            imageBase64JPEG: "AAAA",
            prompt: "识别这餐",
            config: config
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let contents = try XCTUnwrap(json["contents"] as? [[String: Any]])
        let parts = try XCTUnwrap(contents.first?["parts"] as? [[String: Any]])
        let inlinePart = parts.first { $0["inlineData"] != nil }
        let inlineData = inlinePart?["inlineData"] as? [String: Any]

        XCTAssertEqual(inlineData?["mimeType"] as? String, "image/jpeg")
        XCTAssertEqual(inlineData?["data"] as? String, "AAAA")

        let huge = String(repeating: "A", count: VisionImageLimits.maxBase64Length + 1)
        XCTAssertThrowsError(try AIClient.visionRequestJSON(
            imageBase64JPEG: huge,
            prompt: "识别这餐",
            config: config
        )) { error in
            XCTAssertEqual(error as? AIError, .imageTooLarge)
        }
    }

    func testParseGeminiResponseFiltersThoughtPartsAndHandlesBlocks() throws {
        let withThought = """
        {
          "candidates": [
            {
              "content": {
                "parts": [
                  { "text": "内部推理过程：检查用户重量...", "thought": true },
                  { "text": "今天卧推建议 75kg 4×8。" }
                ]
              },
              "finishReason": "STOP"
            }
          ]
        }
        """.data(using: .utf8)!
        let parsed = try AIClient.parseGeminiResponse(withThought)
        XCTAssertEqual(parsed, "今天卧推建议 75kg 4×8。")

        let blocked = """
        {
          "promptFeedback": {
            "blockReason": "SAFETY"
          }
        }
        """.data(using: .utf8)!
        XCTAssertThrowsError(try AIClient.parseGeminiResponse(blocked)) { error in
            guard case AIError.badResponse(let detail) = error else {
                return XCTFail("预期 badResponse，实际为 \(error)")
            }
            XCTAssertTrue(detail.contains("SAFETY"))
        }
    }

    func testSwitchProviderUpdatesDefaultsCleanly() {
        var config = AIConfig()
        XCTAssertEqual(config.provider, .gemini)
        config.apiKey = "AIza-123"

        config.switchProvider(to: .openAICompatible)
        XCTAssertEqual(config.provider, .openAICompatible)
        XCTAssertEqual(config.baseURL, "https://api.openai.com/v1")
        XCTAssertEqual(config.chatModel, "gpt-4o-mini")
        XCTAssertEqual(config.visionModel, "gpt-4o-mini")

        config.switchProvider(to: .gemini)
        XCTAssertEqual(config.provider, .gemini)
        XCTAssertEqual(config.baseURL, "https://generativelanguage.googleapis.com/v1beta")
        XCTAssertEqual(config.chatModel, "gemini-flash-latest")
        XCTAssertEqual(config.visionModel, "gemini-flash-latest")
    }
}
