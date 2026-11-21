# 没有 Mac，怎么用 Sideloadly 把 IPA 装到 iPhone

未签名 IPA 由 GitHub Actions 的 macOS 运行器自动编译并通过单元测试后发布。你只需要一台 **Windows 或 macOS 电脑**，使用 **Sideloadly** 将 `.ipa` 签名安装到 iPhone，全程不需要 Mac、不需要 SideStore，也不需要 LocalDevVPN。

```
云端测试通过 → 编译未签名 IPA → GitHub Release 下载 Stride-1.1.N.ipa → 电脑 Sideloadly 签名安装到 iPhone
```

准备条件：一台 Windows / macOS 电脑、数据线、你的 iPhone（iOS 17+）、一个普通 Apple ID。

Bundle ID 固定为 `com.yg.stride`。不要修改，否则覆盖升级或续签时会被当成新 App，导致无法继承本机数据。

---

## 第一步：获取最新未签名 IPA

`ios/` 的改动推到 `main` 后：

1. 在 [Actions 构建页](https://github.com/yuanyeye0210-debug/stride-app/actions/workflows/stride-ios.yml) 确认本次构建为绿色通过（测试失败时不会生成 Release）。
2. 打开 [最新 Release 页面](https://github.com/yuanyeye0210-debug/stride-app/releases/latest)，点击下载附件 **`Stride-1.1.N.ipa`** 到电脑。
3. 如需核对文件完整性，可比对 Release 说明里提供的 `SHA-256` 校验值。

> Releases 同时保留当前版和上一版，如果新版有回退需求，可直接到 [全部 Releases](https://github.com/yuanyeye0210-debug/stride-app/releases) 下载上一版 IPA 覆盖安装。

---

## 第二步：电脑端准备 Sideloadly

1. 前往官网 [sideloadly.io](https://sideloadly.io/) 下载并安装对应版本（Windows / macOS）。
2. **Windows 用户特别注意**：请安装 Apple 官网提供的**网页安装包版 iTunes 与 iCloud**（不要使用 Microsoft Store 商店版），否则 Sideloadly 可能无法识别 iPhone 或提示 Anisette 错误。
3. 首次用数据线连接 iPhone 后，在手机上点「信任此电脑」；若 iTunes / 访达里已能识别设备，即可进行下一步。
4. **开启开发者模式（iOS 16+ 必做，仅首次）**：iPhone「设置 → 隐私与安全性 → 开发者模式」打开并按提示重启。

---

## 第三步：使用 Sideloadly 签名安装

1. 打开 **Sideloadly**，确认顶部 `iDevice` 下拉框已显示你的 iPhone。
2. 将下载好的 `Stride-1.1.N.ipa` 直接拖进左侧 IPA 图标区域。
3. 在 `Apple ID` 输入框填写你的 Apple ID 邮箱（无需付费开发者账号，普通免费账号即可）。
4. 展开 `Advanced Options`（可选检查）：
   - 确保没有手动改写 Bundle ID，保持默认 `com.yg.stride`；
   - 默认选择 `Normal install` 即可。
5. 点击 **Start**，首次使用按提示输入 Apple ID 密码和 6 位双重认证码。
6. 等待进度条显示 `Done.`，桌面出现「步迹」图标。
7. **首次信任证书**：打开 iPhone「设置 → 通用 → VPN 与设备管理」，点击你的 Apple ID 描述文件 → **信任**，然后回到桌面打开「步迹」。

---

## 第四步：版本更新与 7 天续签

- **版本升级**：下载新版 `Stride-1.1.N.ipa`，用**同一个 Apple ID** 在 Sideloadly 里直接覆盖安装即可，不用卸载旧版，所有本机训练、饮食、体重与照片数据全部保留。
- **7 天自动续签（推荐）**：
  1. 用数据线连着手机在 iTunes（Windows）或访达（macOS）中勾选「通过 Wi-Fi 同步此 iPhone」。
  2. 电脑后台保持 Sideloadly Daemon 运行，在 Sideloadly 列表里为「步迹」开启自动续签。
  3. 只要电脑和 iPhone 在同一 Wi-Fi 下，证书到期前会自动续签；也可以随时插数据线手动点一次 Start 续签。

---

## 免费 Apple ID 的限制

| 限制 | 说明 | 影响与应对 |
|---|---|---|
| **7 天过期** | 免费个人证书有效期 7 天 | 到期前用 Sideloadly 续签或开启 Wi-Fi 自动续签即可，无需卸载，本机数据不丢 |
| **最多 3 个自签 App** | 免费账号同设备最多同时保留 3 个自签 App | 如超限需先卸载一个其他自签 App |
| **每周 10 个 App ID** | 每次新注册 Bundle ID 占用 1 个额度 | 保持 `com.yg.stride` 不变，重复覆盖安装不会额外扣额度 |
| **无 HealthKit / iCloud 容器权限** | 免费描述文件不支持 HealthKit 与 iCloud 权限 | App 内「Apple 健康」同步受系统限制提示为正常现象，所有数据完整存在本机并支持 JSON 一键导出备份 |
| **无 Watch App Target** | 手表端需要独立 watchOS Target 与付费签名 | 手机端可完整使用全部功能，不会出现虚假手表连接 |

如果有 Apple 开发者账号（$99/年），同样可直接用 Sideloadly 登录该账号签名，证书有效期为 1 年。

---

## 常见问题排查

| 现象 | 原因与处理 |
|---|---|
| Sideloadly 找不到 iPhone（Windows） | 卸载商店版 iTunes/iCloud，改装 Apple 官方网页版驱动并重启电脑，重新插拔数据线点「信任」 |
| 提示 Anisette / Local Anisette 错误 | Windows 确认已安装网页版 iCloud 并登录或使用 Sideloadly 默认 Remote Anisette |
| 打开 App 提示「需要开发者模式」 | iPhone「设置 → 隐私与安全性 → 开发者模式」开启并重启手机 |
| 打开 App 提示「不受信任的开发者」 | iPhone「设置 → 通用 → VPN 与设备管理」中信任自己的 Apple ID |
| 7 天后点击闪退 | 免费证书已过期。**不要卸载 App**，直接用同一 Apple ID 在 Sideloadly 重新签名安装一次即可恢复，数据仍在 |
| 覆盖安装后希望回退上一版 | 去 Releases 下载上一版 `Stride-1.1.(N-1).ipa`，用 Sideloadly 直接覆盖安装 |

---

## 不想装电脑工具时

`web/` 是同一套 App 的轻量浏览器版。电脑上 `cd web` 后执行 `python -m http.server 8080`，iPhone 用 Safari 打开后「分享 → 添加到主屏幕」即可试用（不含相机视觉计数与原生部分特性）。详见 `web/README.md`。
