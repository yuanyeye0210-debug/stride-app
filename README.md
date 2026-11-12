# 步迹

iOS 17+ 的 SwiftUI 健身 App，另有一份浏览器版。Bundle ID 是 `com.yg.stride`，不要改，否则已经装上的手机收不到更新。

```
.
├─ ios/                          原生工程（Stride.xcodeproj）
├─ web/                          浏览器版
├─ apps.json                     SideStore / AltStore 源
├─ .github/workflows/stride-ios.yml
├─ .github/scripts/sidestore_source.py
└─ RELEASE-RULE.md               版本和发布规则
```

## 装到 iPhone

推到 `main` 且 `ios/` 有改动时，GitHub Actions 会先跑测试，通过后再编译未签名 IPA、发到 Releases，并更新 SideStore 源。测试失败就不会发版。

SideStore 源：

https://raw.githubusercontent.com/yuanyeye0210-debug/stride-app/main/apps.json

手机上安装 [SideStore](https://sidestore.io) 和 LocalDevVPN，在 SideStore 里添加上面的地址，安装「步迹」。源里只有当前版和上一版。步骤写在 `ios/BUILD-WITHOUT-MAC.md`。

- 构建记录：https://github.com/yuanyeye0210-debug/stride-app/actions/workflows/stride-ios.yml
- 安装包：https://github.com/yuanyeye0210-debug/stride-app/releases

## ios/

| 项 | 说明 |
|---|---|
| 工程 | `ios/Stride.xcodeproj`（iOS 17+，Swift 5，无第三方依赖） |
| 源码 | `ios/Stride/`，按 App / Core / AI / Health / Features / Components 分组 |
| 测试 | `ios/StrideTests/`，Actions 在编译 IPA 之前跑 |
| 图标 | `ios/Stride/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` |
| 品牌 | `ios/Stride/App/Brand.swift` |
| Bundle ID | `com.yg.stride`（`ios/project.yml` 与工程设置） |
| 装机 | `ios/BUILD-WITHOUT-MAC.md` |

版本号由云端写成 `1.1.<运行序号>`，大于旧仓库发过的 `1.0.10`。规则见 `RELEASE-RULE.md`。

## web/

同一套 App 的浏览器版，不含 Apple 健康、Watch 和相机骨骼识别。

- 本机预览：`cd web` 后 `python -m http.server 8080`
- 永久部署：把 `web/` 放到 Netlify、Vercel 或 GitHub Pages
- 加到主屏幕：Safari 打开后分享 → 添加到主屏幕

细节见 `web/README.md`。
