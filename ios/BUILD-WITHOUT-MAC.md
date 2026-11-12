# 没有 Mac，怎么把它装到 iPhone 上

IPA 由 GitHub 的 macOS 运行器编译。签名和安装在手机上用 **SideStore** 完成，刷新签名需要同时开着 **LocalDevVPN**。

```
云端测试通过 → 编译未签名 IPA → GitHub Release → SideStore 源 apps.json → 手机安装
```

需要：这个 GitHub 仓库、你的 iPhone、一个 Apple ID。第一次把 SideStore 装进手机，按 [SideStore 官方说明](https://sidestore.io) 做一次即可。

Bundle ID 是 `com.yg.stride`。不要改，否则收不到后续更新。

---

## 第一步：等云端编译

`ios/` 的改动推到 `main` 之后：

1. 打开 https://github.com/yuanyeye0210-debug/stride-app/actions/workflows/stride-ios.yml
2. 等这次运行变成绿色对勾。测试失败时不会发布安装包。
3. 完成后，Release 里会有 `Stride-1.1.N.ipa`，仓库根目录的 `apps.json` 会写上当前版和上一版。

源地址：

https://raw.githubusercontent.com/yuanyeye0210-debug/stride-app/main/apps.json

也可以从 https://github.com/yuanyeye0210-debug/stride-app/releases 直接看安装包。日常安装不用自己下载 IPA。

---

## 第二步：SideStore + LocalDevVPN

1. 按 SideStore 官方说明，把 SideStore 装到 iPhone（只需做一次）。
2. 安装并连接 **LocalDevVPN**。SideStore 靠它在后台刷新签名。
3. 打开 SideStore → **源** → 添加：

   `https://raw.githubusercontent.com/yuanyeye0210-debug/stride-app/main/apps.json`

4. 在源里找到 **步迹**，安装。SideStore 用你的 Apple ID 签名。
5. 若提示不受信任：设置 → 通用 → VPN 与设备管理 → 信任你的 Apple ID，再打开步迹。

源里同时放着当前版和上一版。新版出问题，可以装回上一版。

---

## 免费 Apple ID 的限制

| 限制 | 说明 | 影响 |
|---|---|---|
| **7 天过期** | 免费证书 7 天后失效 | 到期前打开 SideStore，保持 LocalDevVPN 连接，点刷新。数据还在，不用重装 |
| **最多 3 个 App** | 免费账号同时只能有 3 个自签 App | 要装别的就得删一个 |
| **每周 10 个 App ID** | 改 Bundle ID 会消耗额度 | 不要改 `com.yg.stride` |
| **没有 HealthKit 权限** | 免费描述文件带不了 HealthKit | 「Apple 健康」授权会失败，这是正常的 |
| **没有 Watch App** | 手表需要单独的 target | 手机里不显示假的手表连接 |

付费开发者账号（$99/年）可以把有效期拉长。没有的话，就靠 SideStore 加 LocalDevVPN 在到期前刷新。

---

## 常见问题

| 现象 | 处理 |
|---|---|
| SideStore 添加源失败 | 确认手机能打开上面的 `apps.json`。刚推上 `main` 时要等 Actions 跑完，源里才会出现版本 |
| 刷新失败 | 先打开 LocalDevVPN 并连接，再回 SideStore 刷新 |
| 打开就闪退 | 到「VPN 与设备管理」里信任描述文件 |
| 提示需要更新或打不开 | 证书过期了。SideStore 里刷新当前版本 |
| 源里没有更老的包 | 正常。只保留当前版和上一版 |

---

## 不想装 SideStore

`web/` 是同一套 App 的浏览器版。电脑上 `cd web` 后 `python -m http.server 8080`，手机用 Safari 打开，分享 → 添加到主屏幕。健康、Watch 和相机骨骼识别不在网页版里。见 `web/README.md`。
