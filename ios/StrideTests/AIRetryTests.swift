import XCTest
@testable import Stride

final class AIRetryTests: XCTestCase {

    // MARK: - Task B1: 错误分级

    func testMapsTimeoutToFriendlyTimeout() {
        let mapped = AIRetryPolicy.mapNetworkError(URLError(.timedOut), statusCode: nil)
        XCTAssertEqual(mapped, .timeout)
        XCTAssertTrue(mapped.localizedDescription.contains("超时"))
    }

    func testMapsNotConnectedToOffline() {
        let mapped = AIRetryPolicy.mapNetworkError(URLError(.notConnectedToInternet), statusCode: nil)
        XCTAssertEqual(mapped, .offline)
        XCTAssertTrue(mapped.localizedDescription.contains("没网"))
    }

    func testMapsConnectionLostToOffline() {
        let mapped = AIRetryPolicy.mapNetworkError(URLError(.networkConnectionLost), statusCode: nil)
        XCTAssertEqual(mapped, .offline)
    }

    func testMaps429ToRateLimited() {
        XCTAssertEqual(AIRetryPolicy.mapHTTPStatus(429, body: "slow down"), .rateLimited)
    }

    func testMaps500ToServerBusy() {
        XCTAssertEqual(AIRetryPolicy.mapHTTPStatus(500, body: "boom"), .serverBusy)
        XCTAssertEqual(AIRetryPolicy.mapHTTPStatus(503, body: ""), .serverBusy)
    }

    func testMaps401ToHTTP() {
        XCTAssertEqual(AIRetryPolicy.mapHTTPStatus(401, body: "bad key"), .http(401, "bad key"))
    }

    // MARK: - Task B2: 超时与重试

    func testRetryOnlyTransientErrors() {
        for error in [AIError.timeout, .offline, .serverBusy, .rateLimited] as [AIError] {
            XCTAssertTrue(AIRetryPolicy.shouldRetry(error: error, attempt: 1), "\(error) 第 1 次应重试")
            XCTAssertTrue(AIRetryPolicy.shouldRetry(error: error, attempt: 2), "\(error) 第 2 次应重试")
            XCTAssertFalse(AIRetryPolicy.shouldRetry(error: error, attempt: 3), "\(error) 第 3 次不应再试")
        }
        for error in [AIError.notConfigured, .badResponse("x"), .http(400, "x"), .http(401, "x"), .imageTooLarge] as [AIError] {
            XCTAssertFalse(AIRetryPolicy.shouldRetry(error: error, attempt: 1), "\(error) 不应重试")
        }
    }

    func testBackoffIs1sThen2s() {
        XCTAssertEqual(AIRetryPolicy.backoffDelay(attempt: 1), 1.0, accuracy: 0.01)
        XCTAssertEqual(AIRetryPolicy.backoffDelay(attempt: 2), 2.0, accuracy: 0.01)
    }

    func testTimeoutAndMaxAttemptsArePinned() {
        XCTAssertEqual(AIRetryPolicy.timeoutInterval, 30, accuracy: 0.01)
        XCTAssertEqual(AIRetryPolicy.maxAttempts, 3)
    }

    // MARK: - Task B3: 图片上限

    func testImageLimitsArePinned() {
        XCTAssertEqual(VisionImageLimits.maxEdge, 900)
        XCTAssertEqual(VisionImageLimits.jpegQuality, 0.62, accuracy: 0.001)
        XCTAssertEqual(VisionImageLimits.maxBytes, 2_000_000)
        XCTAssertEqual(VisionImageLimits.maxImagesPerRequest, 1)
    }

    // MARK: - Task B4: 重试中提示

    func testRetryStatusTextFirstAttemptIsNil() {
        XCTAssertNil(AIRetryPolicy.retryStatusText(nextAttempt: 1))
    }

    func testRetryStatusTextSecondAttempt() {
        XCTAssertEqual(AIRetryPolicy.retryStatusText(nextAttempt: 2), "重试中…（第 2 次）")
    }

    func testRetryStatusTextThirdAttempt() {
        XCTAssertEqual(AIRetryPolicy.retryStatusText(nextAttempt: 3), "重试中…（第 3 次）")
    }

    func testRetryStatusTextOutOfRangeIsNil() {
        XCTAssertNil(AIRetryPolicy.retryStatusText(nextAttempt: 0))
        XCTAssertNil(AIRetryPolicy.retryStatusText(nextAttempt: 4))
    }
}
