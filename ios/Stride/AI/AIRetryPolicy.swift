import Foundation

// MARK: - AI 请求重试策略（纯函数，可单元测试）
//
// 只重试瞬时错误：超时、断网、对方服务忙（5xx）、限流（429）。
// 不重试：未配置、请求本身有问题（4xx 除 429 外）、返回格式不对、图片太大。
// 超时 30 秒、最多 3 次尝试、失败后退避 1 秒、2 秒。

enum AIRetryPolicy {

    static let maxAttempts = 3
    static let timeoutInterval: TimeInterval = 30

    static func shouldRetry(error: AIError, attempt: Int) -> Bool {
        guard attempt < maxAttempts else { return false }
        switch error {
        case .timeout, .offline, .serverBusy, .rateLimited:
            return true
        case .notConfigured, .badResponse, .http, .imageTooLarge:
            return false
        }
    }

    /// attempt 是刚失败的那次（从 1 开始）：第 1 次失败后等 1 秒，第 2 次后等 2 秒。
    static func backoffDelay(attempt: Int) -> TimeInterval {
        switch attempt {
        case 1: return 1
        case 2: return 2
        default: return 2
        }
    }

    /// 下一轮重试的提示文案：第 1 次还没重试不显示，超过最多次数也不显示。
    static func retryStatusText(nextAttempt: Int) -> String? {
        guard nextAttempt >= 2, nextAttempt <= maxAttempts else { return nil }
        return "重试中…（第 \(nextAttempt) 次）"
    }

    /// 传输层错误（没走到 HTTP 状态码时用）。
    static func mapNetworkError(_ error: Error, statusCode: Int?) -> AIError {
        if let code = statusCode {
            return mapHTTPStatus(code, body: "")
        }
        guard let urlError = error as? URLError else {
            return .badResponse(error.localizedDescription)
        }
        switch urlError.code {
        case .timedOut:
            return .timeout
        case .notConnectedToInternet, .networkConnectionLost:
            return .offline
        default:
            return .badResponse(urlError.localizedDescription)
        }
    }

    /// 已拿到 HTTP 状态码时用。
    static func mapHTTPStatus(_ code: Int, body: String) -> AIError {
        switch code {
        case 429:
            return .rateLimited
        case 500...599:
            return .serverBusy
        default:
            return .http(code, body)
        }
    }
}
