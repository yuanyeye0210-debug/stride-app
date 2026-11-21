import Foundation

/// 构建期由 GitHub Actions CI 从仓库 Secret 注入内置 Gemini API Key；
/// 源码仓库中仅保留空字符串占位，避免密钥明文入库。
enum BuiltInAISecrets {
    static let geminiAPIKey = ""
}
