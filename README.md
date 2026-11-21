# 步迹

iOS 17+ 的 SwiftUI 健身 App，另有一份浏览器版。Bundle ID 是 `com.yg.stride`，不要改，否则覆盖升级时本机数据无法平滑延续。

```
.
├─ ios/                          原生工程（Stride.xcodeproj）
├─ web/                          浏览器版
├─ .github/workflows/stride-ios.yml   云端测试与 Sideloadly IPA 发布工作流
└─ RELEASE-RULE.md               版本和交付规则
```

## 装到 iPhone（Sideloadly IPA 交付）

推到 `main` 且 `ios/` 有改动时，GitHub Actions 会先运行 `StrideTests` 单元测试，通过后再编译未签名 `Stride-1.1.N.ipa` 并发布到 GitHub Releases。测试失败不会发版。

1. 打开最新安装包页面下载 `Stride-1.1.N.ipa`：
   - 最新版本：https://github.com/yuanyeye0210-debug/stride-app/releases/latest
   - 全部保留版本（当前版 + 上一版）：https://github.com/yuanyeye0210-debug/stride-app/releases
2. 在 Windows 或 macOS 上打开 [Sideloadly](https://sideloadly.io/)，连接 iPhone。
3. 把下载好的 `Stride-1.1.N.ipa` 拖进 Sideloadly，填入你的 Apple ID（保持 Bundle ID `com.yg.stride` 不变），点击 **Start** 完成签名与安装。
4. 首次安装后在 iPhone「设置 → 通用 → VPN 与设备管理」信任自己的 Apple ID。

完整安装与 7 天续签步骤写在 `ios/BUILD-WITHOUT-MAC.md`。

- 构建记录：https://github.com/yuanyeye0210-debug/stride-app/actions/workflows/stride-ios.yml
- 安装包发布页：https://github.com/yuanyeye0210-debug/stride-app/releases

## ios/

| 项 | 说明 |
|---|---|
| 工程 | `ios/Stride.xcodeproj`（iOS 17+，Swift 5，无第三方依赖） |
| 源码 | `ios/Stride/`，按 App / Core / AI / Health / Features / Components 分组 |
| 测试 | `ios/StrideTests/`，Actions 在编译 IPA 之前自动执行 |
| 图标 | `ios/Stride/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` |
| 品牌 | `ios/Stride/App/Brand.swift` |
| Bundle ID | `com.yg.stride`（`ios/project.yml` 与工程设置） |
| 装机 | `ios/BUILD-WITHOUT-MAC.md`（Sideloadly 图文步骤） |

版本号由云端写成 `1.1.<运行序号>`，大于旧仓库发过的 `1.0.10`。规则见 `RELEASE-RULE.md`。

## web/

同一套 App 的浏览器版，不含 Apple 健康、Watch 和相机骨骼识别。

- 本机预览：`cd web` 后 `python -m http.server 8080`
- 永久部署：把 `web/` 放到 Netlify、Vercel 或 GitHub Pages
- 加到主屏幕：Safari 打开后分享 → 添加到主屏幕

细节见 `web/README.md`。
