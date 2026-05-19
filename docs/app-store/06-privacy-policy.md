# 隐私政策 · DaysHere / 一年几天

> **本文档需要托管到一个公开 URL**（如 GitHub Pages、自有域名、Notion 公开页等），并把链接填到 App Store Connect 的"Privacy Policy URL"字段。
>
> 推荐：在仓库新建 `gh-pages` 分支或开启 GitHub Pages，把此文档导出为 HTML 后访问。
> URL 建议：`https://leaking.github.io/DaysHere/privacy/` 或 `https://harry.dev/dayshere/privacy`

**生效日期**：2026-05-20
**适用版本**：v1.0.0 起

## 简短版

DaysHere 不收集你的任何个人信息。所有数据保存在你自己的 Mac 上和你自己的 iCloud 账户里。我们没有服务器，没有分析 SDK，永远不会向任何第三方分享你的数据。

## 收集的数据

**无。**

DaysHere 不向任何外部服务器发送数据。我们没有用户账号体系。

## 存储的数据

DaysHere 在你的 Mac 上本地存储以下数据：

- 你手动标记的日期状态（"在某地"、"请假"）
- 你定义的"坐标档案"（名称、经纬度、半径）
- 应用界面偏好（主题、视图模式等）

存储路径：`~/Library/Containers/com.harry.dayshere/Data/Library/Application Support/DaysHere/`（沙盒目录）。

## 跨设备同步

如果你在"设置"中开启了"iCloud 同步"，上述本地数据会被复制到 Apple iCloud Key-Value Storage。该数据：

- 仅在你的 Apple ID 下的设备之间同步（同一个 Apple ID 登录的多台 Mac）
- 由 Apple 在端到端加密传输和存储
- DaysHere 开发者**无法**访问这部分数据
- 你可以随时关闭同步开关，已经同步的数据可以在 iCloud Drive 的「管理存储」中手动清除

## 定位服务

DaysHere 仅在你主动点击"使用当前位置"按钮时调用 `CLLocationManager`，用于在地图选点界面定位你当前位置。

- 定位结果**仅在内存中使用**，不会写入任何持久化存储
- 定位结果**不会**发送到任何外部服务器
- 你可以在 macOS 系统设置 → 隐私与安全性 → 定位服务 中随时撤销定位权限

## 不使用的服务

- ❌ 任何第三方分析 SDK（Google Analytics, Firebase, Mixpanel, etc.）
- ❌ 任何第三方崩溃报告（Sentry, Bugsnag, etc.）
- ❌ 任何广告 SDK
- ❌ 任何 IDFA / 设备指纹
- ❌ 任何远程配置 / A/B 测试

## 第三方服务

DaysHere 唯一调用的第三方服务是 **Apple Maps**（MapKit 框架）：
- 用于在"在地图上选择…"界面渲染地图瓦片
- 用于地址搜索（`MKLocalSearchCompleter`）
- 用于反向地理编码（`CLGeocoder`）

这些调用全部由 Apple 处理，受 [Apple 的服务条款与隐私政策](https://www.apple.com/legal/privacy/) 约束。

## 数据删除

你可以通过以下方式完全删除你的数据：

1. 在 DaysHere 设置中**删除全部坐标档案**（保留 1 个，然后删另 1 个，最后通过 macOS Finder 删除应用沙盒目录）
2. 卸载应用：删除 `/Applications/DaysHere.app` 后，运行：

```
rm -rf ~/Library/Containers/com.harry.dayshere
```

3. iCloud 同步数据：登录 [iCloud.com](https://icloud.com) → 账号设置 → 管理 → DaysHere → 删除

## 变更

我们如果将来收集任何数据（不打算），会更新本文并在应用内显著提示。

## 联系

issue / 反馈：[https://github.com/Leaking/DaysHere/issues](https://github.com/Leaking/DaysHere/issues)
邮件：[chenhuazhaoao@gmail.com](mailto:chenhuazhaoao@gmail.com)

---

# Privacy Policy · DaysHere / English Version

**Effective date**: 2026-05-20

## TL;DR

DaysHere collects nothing. All your data stays on your Mac and in your own iCloud. No servers, no analytics, no third-party sharing. Ever.

## Data we collect

**None.** DaysHere has no user account system and makes no network requests to any server we operate.

## Data stored on your device

DaysHere stores the following on your Mac:

- Day-level state you marked manually ("here", "leave")
- Location profiles you defined (name, latitude, longitude, radius)
- UI preferences (theme, view mode, etc.)

Storage path: `~/Library/Containers/com.harry.dayshere/Data/Library/Application Support/DaysHere/` (sandboxed).

## Sync between your devices

If you opt in to iCloud sync in Settings, the data above is copied to Apple iCloud Key-Value Storage. This sync:

- Goes only between devices signed in to the same Apple ID
- Uses Apple's encrypted transport and storage
- Is **not accessible** by the DaysHere developer
- Can be disabled at any time; synced data can be cleared in iCloud Drive → Manage Storage

## Location services

DaysHere only requests location through `CLLocationManager` when you tap "Use current location" in the map picker.

- Coordinates are used only in memory
- Coordinates are **never** transmitted to any external server
- You can revoke Location permission anytime in System Settings → Privacy & Security → Location Services

## Third-party services not used

- ❌ Any third-party analytics SDK
- ❌ Any third-party crash reporter
- ❌ Any ad SDK
- ❌ Any IDFA or device fingerprinting
- ❌ Any remote config or A/B testing

## Third-party services that ARE used

Only **Apple Maps** (via Apple's MapKit framework):
- Map tile rendering in the location picker
- Place search (`MKLocalSearchCompleter`)
- Reverse geocoding (`CLGeocoder`)

All such calls are handled by Apple under [Apple's privacy policy](https://www.apple.com/legal/privacy/).

## Data deletion

To fully delete your data:

1. Remove all location profiles in Settings (delete N-1 first, then delete the last one through Finder)
2. Uninstall the app: drag DaysHere.app to Trash, then run:
   ```
   rm -rf ~/Library/Containers/com.harry.dayshere
   ```
3. iCloud-synced data: sign in to [iCloud.com](https://icloud.com) → Account Settings → Manage → DaysHere → Delete

## Changes

If we ever start collecting any data (we don't plan to), this policy will be updated and you will be notified in-app.

## Contact

Issues / feedback: [https://github.com/Leaking/DaysHere/issues](https://github.com/Leaking/DaysHere/issues)
Email: [chenhuazhaoao@gmail.com](mailto:chenhuazhaoao@gmail.com)
