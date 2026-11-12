import XCTest
@testable import Stride

final class VisionRequestTests: XCTestCase {

    func testVisionImageURLIsObjectWithURL() throws {
        let config = AIConfig(
            baseURL: "https://api.openai.com/v1",
            apiKey: "sk-test",
            chatModel: "gpt-4o-mini",
            visionModel: "gpt-4o-mini",
            temperature: 0.2
        )
        let data = try AIClient.visionRequestJSON(
            imageBase64JPEG: "AAAA",
            prompt: "识别这餐",
            config: config
        )
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let messages = json?["messages"] as? [[String: Any]]
        let content = messages?.first?["content"] as? [[String: Any]]
        let image = content?.first { $0["type"] as? String == "image_url" }
        let imageURL = image?["image_url"] as? [String: Any]

        XCTAssertEqual(imageURL?["url"] as? String, "data:image/jpeg;base64,AAAA")
        XCTAssertEqual(json?["model"] as? String, "gpt-4o-mini")
    }

    func testVisionRejectsOversizeImage() {
        let config = AIConfig(
            baseURL: "https://api.openai.com/v1",
            apiKey: "sk-test",
            chatModel: "gpt-4o-mini",
            visionModel: "gpt-4o-mini",
            temperature: 0.2
        )
        let huge = String(repeating: "A", count: VisionImageLimits.maxBase64Length + 1)
        XCTAssertThrowsError(try AIClient.visionRequestJSON(
            imageBase64JPEG: huge,
            prompt: "识别这餐",
            config: config
        )) { error in
            XCTAssertEqual(error as? AIError, .imageTooLarge)
        }
    }
}
