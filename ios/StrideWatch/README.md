# StrideWatch（Apple Watch 6 轴动作识别独立工程目录）

说明：
- 为了确保免费 Apple ID + Sideloadly 能够单 Target 顺利自签名安装 `Stride.ipa`，默认 `ios/Stride.xcodeproj` 保持纯净单 Target（不嵌 watchOS 扩展）。
- 当你拥有付费 Apple 开发者账号（$99/年）或使用 Mac Xcode 真机签名时，可使用上一层的 `ios/project-with-watch.yml` 一键生成包含 Apple Watch 端的完整工程并编译安装到手腕：

```bash
cd ios
brew install xcodegen
xcodegen generate --spec project-with-watch.yml
open Stride.xcodeproj
```

在 Xcode 中选择 `StrideWatch` Scheme，分别勾选 `Stride` 与 `StrideWatch` 的付费团队签名（Signing & Capabilities -> 添加 HealthKit Background Workout 权限），直接 Run 即可在 Apple Watch 上实时采集 50Hz 6 轴 IMU、运行 `watch_exercise_classifier_v1.json` 神经网络分类与自适应计次，并每完成 1 次动作震动且回传到 iPhone `SessionView`。
