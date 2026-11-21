import Foundation

/// 品牌与可替换常量。改名只动这里 + 工程 Build Settings 里的 Bundle ID。
enum Brand {
    static let name = "Stride"
    static let nameZH = "步迹"
    static let tagline = "练得清楚，才练得下去"
    static let bundleID = "com.yg.stride"
    static let supportEmail = "support@example.com"

    /// 品牌衍生展示名（严格本地化，不出现外部品牌或登录/付费入口）
    static let canteenTitle = "\(name) 食堂"
    static let intelligenceName = "\(name) Intelligence"

    /// 兼容既有引用的档位名称（当前发行版默认全部开放）
    static let tierMax = "\(name) Max"
    static let tierPro = "\(name) Pro"
}

/// 全局开关：这是你自己的发行版，所有权益默认全开。
/// 想真做订阅时把它设为 false，并把 PurchaseService 换成 StoreKit 2 实现。
enum LaunchFlags {
    static let everythingUnlocked = true
    /// 会员墙已去掉，不再提供入口。
    static let showMembershipEntry = false
    /// 启动时不模拟手表连接，避免出现假的在线状态。
    static let simulateWatch = false
}
