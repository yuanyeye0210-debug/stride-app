# 版本与发布规则

1. **改了 iOS 代码就要推到 GitHub。测试和云端编译都通过，才算这个版本做好了。**
2. **每次出新版本，留下上一版。更老的自动删除，Releases 和 SideStore 源里都只留 2 个。**

旧仓库最后发过 `stride-v1.0.10`。这个仓库的版本从 **`1.1.<运行序号>`** 起，保证比 `1.0.10` 大，已经装过的手机会看到更新。

---

## 什么会出新版本

| 场景 | 结果 |
|---|---|
| 改了 `ios/` 并推到 `main` | Actions 先跑 `StrideTests`，通过后编译 `Stride-1.1.N.ipa`，发布 Release，更新 `apps.json` |
| 只改文档或 `web/` | 会同步，但**不会**编译，也不占用新版本号 |
| 测试失败 | 停在测试那一步，不编译、不发布 |
| Pull request | 跑测试并编译，不发布 |

判定：Actions 是绿的，Releases 里出现 `stride-v1.1.N`，`apps.json` 里有这个版本，才算成品。

---

## 版本与备份

| 项 | 约定 |
|---|---|
| 版本号 | `1.1.<运行序号>`，写进 App「自己 → 版本」 |
| 产物 | `Stride-1.1.N.ipa` |
| 存放 | GitHub **Releases**，tag = `stride-v1.1.N` |
| **保留** | **2 个**：当前 + 上一版 |
| 自动删除 | 第 3 个及更早的 release **连同 tag** 一起删 |
| SideStore 源 | 仓库根目录 `apps.json`，同样只写这 2 个版本 |
| Actions Artifacts | 额外留一份，7 天过期 |

排序按**版本号数字**，不按时间。

```
Releases / apps.json
├─ Stride 1.1.N     ← 当前
├─ Stride 1.1.(N-1) ← 上一版
└─ 更早的已被删除
```

改保留数量：`.github/workflows/stride-ios.yml` 里的 `KEEP_RELEASES`。

---

## SideStore

源地址（SideStore / AltStore 都能加）：

https://raw.githubusercontent.com/yuanyeye0210-debug/stride-app/main/apps.json

Bundle ID 固定为 `com.yg.stride`。安装和刷新要开着 LocalDevVPN。步骤见 `ios/BUILD-WITHOUT-MAC.md`。

---

## 在哪里看

- 构建历史和日志：https://github.com/yuanyeye0210-debug/stride-app/actions/workflows/stride-ios.yml
- 下载成品：https://github.com/yuanyeye0210-debug/stride-app/releases
