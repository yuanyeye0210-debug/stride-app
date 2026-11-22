import XCTest
@testable import Stride

final class GeminiClientTests: XCTestCase {

    func testDefaultAIConfigUsesGemini() {
        let config = AIConfig()
        XCTAssertEqual(config.provider, .gemini)
        XCTAssertEqual(config.baseURL, "https://generativelanguage.googleapis.com/v1beta")
        XCTAssertEqual(config.chatModel, "gemini-3.5-flash-lite")
        XCTAssertEqual(config.visionModel, "gemini-3.5-flash")
        XCTAssertFalse(config.isConfigured)
    }

    func testModuleAutoRoutingAndFallbackChains() {
        XCTAssertEqual(CoachEngine.useCase(for: "今天练什么"), .coachChat)
        XCTAssertEqual(CoachEngine.useCase(for: "帮我分析一下最近四周分化训练周期与瓶颈"), .coachDeepAnalysis)

        let chatChain = AIClient.geminiModelCandidates(primary: "", useCase: .coachChat)
        XCTAssertEqual(chatChain, ["gemini-3.5-flash-lite", "gemini-flash-lite-latest", "gemini-3.1-flash-lite", "gemini-3.6-flash"])

        let deepChain = AIClient.geminiModelCandidates(primary: "", useCase: .coachDeepAnalysis)
        XCTAssertEqual(deepChain.first, "gemini-3.6-flash")
        XCTAssertTrue(deepChain.contains("gemini-flash-lite-latest"))

        let visionChain = AIClient.geminiModelCandidates(primary: "", useCase: .foodVision)
        XCTAssertEqual(visionChain, ["gemini-3.5-flash", "gemini-3.6-flash", "gemini-3.5-flash-lite", "gemini-flash-lite-latest"])
    }

    func testFitnessKnowledgeBaseRAGAndLocalCoach() {
        XCTAssertGreaterThanOrEqual(FitnessKnowledgeBase.entries.count, 20)

        let benchHits = FitnessKnowledgeBase.retrieve(for: "卧推卡在70kg上不去怎么办")
        XCTAssertFalse(benchHits.isEmpty)
        XCTAssertTrue(benchHits.contains(where: { $0.id == "bench_press" || $0.id == "double_progression" }))

        let shoulderHits = FitnessKnowledgeBase.retrieve(for: "肩痛卧推怎么办")
        XCTAssertTrue(shoulderHits.contains(where: { $0.id == "shoulder_rehab" }))

        let dietHits = FitnessKnowledgeBase.retrieve(for: "减脂外卖怎么吃")
        XCTAssertTrue(dietHits.contains(where: { $0.id == "eating_out" || $0.id == "fat_loss_nutrition" }))

        let rag = FitnessKnowledgeBase.ragContext(for: "深蹲怎么练")
        XCTAssertFalse(rag.isEmpty)
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
        XCTAssertEqual(config.chatModel, "gemini-3.5-flash-lite")
        XCTAssertEqual(config.visionModel, "gemini-3.5-flash")
    }

    func testSanitizePlainTextStripsAllMarkdownSymbols() {
        let raw = """
        ### 今日居家方案
        > 注意热身与呼吸

        我给你准备了一套 **20分钟居家全身高效循环方案**：
        1. **上肢胸肩**：标准俯卧撑 `10-15` 次
        - **深度拉伸/泡沫轴**：参考 [拉伸指南](https://example.com/stretch)
        * *轻度放松* __补足睡眠__ ~~硬扛~~
        ---
        ```text
        3*8
        ```
        """

        let cleaned = CoachEngine.sanitizePlainText(raw)
        XCTAssertFalse(cleaned.contains("*"))
        XCTAssertFalse(cleaned.contains("#"))
        XCTAssertFalse(cleaned.contains("`"))
        XCTAssertFalse(cleaned.contains("_"))
        XCTAssertFalse(cleaned.contains("~~"))
        XCTAssertFalse(cleaned.contains("]("))
        XCTAssertTrue(cleaned.contains("今日居家方案"))
        XCTAssertTrue(cleaned.contains("20分钟居家全身高效循环方案："))
        XCTAssertTrue(cleaned.contains("1. 上肢胸肩：标准俯卧撑 10-15 次"))
        XCTAssertTrue(cleaned.contains("· 深度拉伸/泡沫轴：参考 拉伸指南"))
        XCTAssertTrue(cleaned.contains("· 轻度放松 补足睡眠 硬扛"))
        XCTAssertTrue(cleaned.contains("3×8"))
        XCTAssertTrue(CoachEngine.systemPrompt.contains("严禁使用任何 Markdown"))
    }

    func testParseStructuredReplyExtractsInlineWorkoutCard() {
        let reply = """
        下雨天窝在家里，其实正是低成本身体维护的好时机！

        如果你今天想动一动，我给你准备了一套 **20 分钟居家全身循环方案**（无器械，做 4 轮，组间歇 90 秒）：

        1. **上肢胸肩**：标准俯卧撑（或脚搭沙发上斜）10-15 次。
        2. **下肢核心**：保加利亚分腿蹲（后脚背搭沙发或床沿）每侧 12 次，酸爽度绝对够。
        3. **背部姿态**：俯身超人背伸（趴地上抬起手脚）15 次。
        4. **臀腿链条**：单腿臀桥（仰卧单腿蹬地）每侧 12 次。
        5. **核心收尾**：平板支撑或死虫（Dead Bug）45 秒。

        要是只想舒服一下，做 15 分钟静态拉伸，补足睡眠也是增肌期的一部分。
        """

        let parsed = CoachEngine.parseStructuredReply(reply)
        guard let card = parsed.workoutCard else {
            return XCTFail("预期能识别出结构化训练方案卡片")
        }

        XCTAssertFalse(parsed.intro.contains("*"))
        XCTAssertFalse(parsed.outro.contains("*"))
        XCTAssertTrue(parsed.intro.contains("低成本身体维护"))
        XCTAssertTrue(parsed.outro.contains("静态拉伸"))
        XCTAssertEqual(card.rounds, 4)
        XCTAssertTrue(card.metaSummary.contains("5 动作"))
        XCTAssertTrue(card.metaSummary.contains("4 轮"))
        XCTAssertTrue(card.title.contains("居家全身循环"))
        XCTAssertEqual(card.items.count, 5)
        XCTAssertEqual(card.items[0].title, "标准俯卧撑")
        XCTAssertEqual(card.items[0].dose, "10-15 次")
        XCTAssertEqual(card.items[1].dose, "每侧 12 次")
        XCTAssertEqual(card.items[4].title, "平板支撑或死虫")
        XCTAssertEqual(card.items[4].dose, "45 秒")

        let planned = card.toPlannedDay(weekday: 2)
        XCTAssertEqual(planned.weekday, 2)
        XCTAssertFalse(planned.rest)
        XCTAssertEqual(planned.exercises.count, 5)
        XCTAssertEqual(planned.exercises.first?.sets, 4)
        XCTAssertEqual(planned.exercises.first?.reps, "10-15 次")
    }

    func testParseStructuredReplyIgnoresNonWorkoutNumberedLists() {
        let plainListReply = """
        减脂期睡眠和饮水建议：

        1. 保持每天 7 到 8 小时规律作息，避免深夜刷手机。
        2. 优先保证三餐蔬菜与全谷物摄入，少吃高油零食。
        3. 餐后可以适当散步放松肠胃，减轻心理压力。
        """

        let parsed = CoachEngine.parseStructuredReply(plainListReply)
        XCTAssertNil(parsed.workoutCard)
        XCTAssertTrue(parsed.intro.contains("1. 保持每天"))
        XCTAssertTrue(parsed.outro.isEmpty)
    }
}
