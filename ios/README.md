# Stride · 步迹

一个**独立实现的 iOS 健身 App**：训练记录、渐进式负荷、AI 热量识别与教练、足迹画风。
界面是深色的；**代码、素材、品牌全部原创**，不包含任何第三方 App 的二进制、资源或破解逻辑。

权益默认全部可用（`LaunchFlags.everythingUnlocked = true`）。会员付费墙已经去掉，不再出现购买页。启动时也不会模拟 Apple Watch 连接。

---

## 打开与运行

| 环境 | 做法 |
|---|---|
| Xcode 16+ | 直接双击 `Stride.xcodeproj`，选模拟器 ⌘R |
| Xcode 15 | 先 `brew install xcodegen`，在本目录执行 `xcodegen generate`，再打开生成的工程 |

- 部署目标 iOS 17.0，Swift 5 语言模式，零第三方依赖。
- 首次运行会写入一份演示数据（3 周训练、6 条轨迹、今日三餐），之后全部走本地存储：
  `~/Library/Application Support/Stride/state.json`
- 模拟器没有相机 / 健康数据 / GPS，相关页面会自动降级并给出提示。

### 需要在真机验证的能力

| 能力 | 需要打开的 Capability | 备注 |
|---|---|---|
| Apple 健康双向同步 | Signing & Capabilities → **HealthKit** | 不开也能编译，授权会失败并提示 |
| Apple Watch 实时同步 | 加一个 watchOS App target | 手机侧桥接已写好，见下 |
| 视觉动作计数 | 无需 Capability | 需要真相机；模拟器提示"没有可用相机" |
| 足迹记录 | 无需 Capability | 首次进入会请求定位权限 |

---

## 功能地图

### 免费版（全部已包含）

| 功能 | 文件 |
|---|---|
| 完整训练与记录 | `Features/Workout/SessionView.swift`、`TrainingHomeView.swift` |
| 每天 10 次 AI 热量识别 | `Features/Food/FoodScanView.swift` + `AI/FoodRecognition.swift` |
| AI 教练对话 20 次体验 | `Features/Coach/CoachView.swift` + `AI/CoachEngine.swift` |
| Apple Watch 连接与实时同步 | `Health/WatchSession.swift` |
| 插件市场全部小工具 | `Features/Me/PluginsView.swift`（1RM / 杠铃片 / 休息计时 / 节奏换算） |
| 视觉动作计数 | `Features/Camera/RepCounterView.swift`（Vision 关节角 + 组数状态机） |
| Apple 健康双向同步 | `Health/HealthKitManager.swift` |
| 3 套足迹画风 · 1 套分享模板 | `Features/Progress/RouteArtView.swift` |
| 歌词同步不限次数 | `Features/Music/LyricsView.swift`（LRC 解析 + 逐行跟读） |

额度网关还在 `Core/Entitlements.swift`，但 `LaunchFlags.everythingUnlocked` 为 true 时按最高档放行，界面上没有付费墙。

| 能力 | 实现 |
|---|---|
| AI 热量识别与教练 | `Core/Entitlements.swift` 的 `Gate`，当前不限额 |
| AI 生成训练计划 | `AI/PlanGenerator.swift`（本地周期化生成，可换模型重排） |
| 渐进式负荷 | `Core/ProgressiveEngine.swift`（e1RM、双进阶、RPE 自调节、减载判定） |
| 歌单链接导入解析 | `Features/Music/PlaylistImportView.swift` |
| 足迹画风与分享模板 | `RouteArtStyle`（6 种）/ `ShareTemplate`（4 种）+ `ImageRenderer` 出图 |
| 饮水 | `Core/Models.swift` 的 `WaterLog`，主页和记录页各一张卡 |
| 本周计划 | `Features/Workout/TrainingHomeView.swift`，长按「本周」卡片可调整 |

---

## 接一个真模型

「自己 → AI 服务」填三项即可，兼容任何 OpenAI 协议端点：

```
接口地址   https://api.openai.com/v1        （或自建网关 / 国内兼容服务）
API Key    sk-...
对话模型   gpt-4o-mini
视觉模型   gpt-4o-mini                      （必须支持图片输入，用于热量识别）
```

没填之前：教练走本地规则引擎（`CoachEngine.localReply`，会读你的真实训练记录、肌群组数、当日营养），
热量识别提示改手动记录（内置 40 种常见食物的营养库，`AI/FoodRecognition.swift`）。

---

## 改成你自己的产品

| 要改的 | 位置 |
|---|---|
| App 名 / 品牌名 / 会员名 | `App/Brand.swift` 一处 |
| Bundle ID | 工程 Build Settings 或 `project.yml` 的 `PRODUCT_BUNDLE_IDENTIFIER` |
| 配色 | `App/Theme.swift` 的 `Palette` |
| 默认档位 / 额度 | `Core/Entitlements.swift` 的 `Tier` |
| 是否全解锁 | `App/Brand.swift` 的 `LaunchFlags.everythingUnlocked` |

---

## 关于 Watch 端

手机侧 `WatchSession` 已经能把"当前动作 / 第几组 / 休息剩余"推给手表，并对未连接状态用
`updateApplicationContext` 兜底。要真正在腕上显示，加一个 watchOS App target：

1. File → New → Target → watchOS App，名字随意；
2. 在手表 target 里 `WCSession.default` 激活并实现 `didReceiveApplicationContext`；
3. 把 `Health/WatchSession.swift` 顶部的字段名（`kind/title/elapsed/setIndex/totalSets`）复用成手表端的解码结构。

这一步必须在 Xcode 里做（需要单独 target 与签名），我这边只交付了手机侧桥接层。

---

## 边界说明

- 不包含、也不依赖任何第三方 App 的安装包、逆向产物或授权绕过逻辑。
- 没有会员购买页。用户数据只写本机 `Application Support`；API Key 在钥匙串里，只有请求你填写的接口时才会发出去。拍照识别的图片只在配置了 AI 服务时发给那个端点。
