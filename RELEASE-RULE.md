# 版本与发布规则（Sideloadly IPA 交付）

1. **改了 iOS 代码就要推到 GitHub。单元测试和云端编译都通过，才算这个版本做好了。**
2. **项目以未签名 `.ipa` 方式通过 GitHub Releases 交付，由电脑端 Sideloadly 签名安装到 iPhone。**
3. **每次出新版本，保留上一版方便回退；更早的自动删除，Releases 里只留 2 个版本。**

旧仓库最后发过 `stride-v1.0.10`。这个仓库的版本从 **`1.1.<运行序号>`** 起，保证版本号递增，Sideloadly 覆盖安装时可平滑保留本机数据。

---

## 什么会出新版本

| 场景 | 结果 |
|---|---|
| 改了 `ios/` 或工作流并推到 `main` | Actions 先跑 `StrideTests`，通过后编译未签名 `Stride-1.1.N.ipa`，校验 Bundle ID 与 SHA-256，发布到 Releases |
| 只改文档或 `web/` | 会同步到仓库，但**不会**编译，也不占用新版本号 |
| 测试失败 | 停在测试那一步，不编译、不发布 |
| Pull request | 跑测试并编译未签名 IPA（仅留 Actions Artifact），不发布 Release |

判定：Actions 是绿的，且 Releases 里出现 `stride-v1.1.N` 及其附件 `Stride-1.1.N.ipa`，才算成品交付完成。

---

## 版本与产物保留

| 项 | 约定 |
|---|---|
| 版本号 | `1.1.<运行序号>`，写入 App「个人 → 设置 → 版本」 |
| 交付产物 | `Stride-1.1.N.ipa`（未签名 IPA，供 Sideloadly 自签） |
| 校验信息 | Release 说明附带文件字节数与 `SHA-256` 校验值 |
| 存放位置 | GitHub **Releases**，tag = `stride-v1.1.N` |
| **保留数量** | **2 个**：当前版 + 上一版 |
| 自动清理 | 第 3 个及更早的 Release **连同 tag** 一起自动删除 |
| Actions Artifacts | 额外保留一份构建归档，7 天过期 |

排序按**版本号数字**，不按时间。

```
GitHub Releases
├─ Stride 1.1.N     ← 当前版（Stride-1.1.N.ipa）
├─ Stride 1.1.(N-1) ← 上一版（回退备用）
└─ 更早版本与 tag 已自动删除
```

修改保留数量：编辑 `.github/workflows/stride-ios.yml` 里的 `KEEP_RELEASES`。

---

## Sideloadly 安装与续签

- 最新版本直链：https://github.com/yuanyeye0210-debug/stride-app/releases/latest
- Bundle ID 固定为 `com.yg.stride`（在 Sideloadly 高级选项中保持原 Bundle ID，不要勾改写）。
- 升级或 7 天续签时，使用**同一 Apple ID** 覆盖安装新版 IPA，或在 Sideloadly 中开启 **Wi-Fi 自动续签**，本机所有训练、饮食、体重与照片记录均不会丢失。
- 完整操作与常见问题排查见 `ios/BUILD-WITHOUT-MAC.md`。

---

## 在哪里看

- 构建历史与测试日志：https://github.com/yuanyeye0210-debug/stride-app/actions/workflows/stride-ios.yml
- 下载成品 IPA：https://github.com/yuanyeye0210-debug/stride-app/releases
