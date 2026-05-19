# 一年几天 / DaysHere · 业务规格

> **本文件是产品业务逻辑的权威来源。** 实现细节出现歧义时优先以本文为准。
>
> 任何业务规则变更（新增天数判定、状态字段、同步策略、UI 含义变化等）必须同步更新本文件，并向 [`decisions.md`](decisions.md) 追加一条变更记录。
>
> - **Last updated**: 2026-05-20 (e)
> - **维护方式**：每次涉及业务逻辑的 PR 末尾必须列出对本文档的修改项（即使没改也明确写 "SPEC 未变更"）

---

## 0. 产品目标

「一年几天」（DaysHere）帮助用户统计自己一年内在**任意关心的地点**实际驻留的天数。产品起源场景是 **珠海横琴粤澳深度合作区** 的法定居住认证（默认坐标档案 = 横琴），但通过多坐标档案可以覆盖任何地点。两条法定阈值靠拢：

| 指标 | 目标值 | 来源 |
|---|---|---|
| **自然日**（calendar days） | **183 天** | 用于"在横琴居住满半年"判定 |
| **工作日**（business days） | **124 天** | 用于个税/补贴优惠资格判定 |

阈值为产品级常量，不随用户档案变化（见 §3 关于多档案的影响）。

---

## 1. 双端形态

| 形态 | 角色 | 关键能力 |
|---|---|---|
| **Chrome 扩展**（`popup/` `background/` `offscreen/`） | 自动数据来源 | 每 30 分钟后台 GPS 检测；写入 `chrome.storage.sync` 同步到 Google 账号 |
| **macOS 菜单栏 App**（`Sources/HengqinTracker`） | 可视化 + 编辑 + 跨设备同步 | 年/月热力图；手动标记；导入导出；iCloud KVS 跨设备同步 |

两端**共用同一份业务规则**（坐标判定、桥接规则、状态优先级），**不共用存储**：
- Chrome：`chrome.storage.sync`（受 Google 账号限制，无法被 macOS 读取）
- macOS：Application Support + iCloud KVS（受 Apple ID 限制）
- 桥梁：**导入/导出 JSON**（格式见 §6）由用户手动跨端搬运

---

## 2. 坐标与判定

### 2.1 横琴坐标

| 参数 | 值 |
|---|---|
| 中心点 | **22.125°N, 113.535°E** |
| 半径 | **8 km** |
| 算法 | Haversine 公式 |

### 2.2 当天判定

> 当天任意一次定位落在 8 km 以内 → 该天 `inHengqin = true`，**不可被后续不在横琴的定位覆盖**。

这是"宽松判定"，符合"只要这一天来过即视为驻留"的产品意图。

---

## 3. 坐标档案（Location Profile） · macOS only

macOS 端支持**多坐标档案**，便于追踪除横琴外其他地点的驻留（例：在深圳办事处、在老家等）。Chrome 端目前**只跟踪横琴**，不与档案系统对接。

### 3.1 档案模型

```swift
LocationProfile {
  id: UUID
  name: String              // "横琴" / "深圳" / 自定义
  latitude: Double          // 中心点纬度
  longitude: Double         // 中心点经度
  radiusKilometers: Double  // 判定半径（km）
  createdAt: Date
}
```

- 默认档案：`横琴 (22.125, 113.535, 8km)`，UUID 固定为 `11111111-1111-1111-1111-111111111111`
- 首次启动自动创建默认档案
- 至少保留一个档案（最后一个不允许删除）

### 3.2 切换语义

- 每个档案拥有**独立**的 DayRecord 集合（独立存储 + 独立 iCloud KVS 命名空间）
- 切换档案 = 切换可见的数据集
- 当前活动档案 ID 持久化在 `profiles.json`
- 统计目标值 (183/124) **不**随档案变化；目前所有档案共用同一阈值（未来如有需要可在档案上加 `naturalDayTarget` 字段）

### 3.3 与 Chrome 扩展的关系

- Chrome 扩展不感知档案。它只会把数据写到自己的 `chrome.storage.sync`
- 导入到 macOS 时，用户必须自己**选择目标档案**（即先在设置中切到目标档案再点导入）
- 导出从当前活动档案出
- 这是约束而非缺陷 — Chrome 端没必要做多档案

---

## 4. 法定假期数据（2026）

### 4.1 法定假日（放假日期）

| 节日 | 日期范围 |
|---|---|
| 元旦 | 01-01 ~ 01-03 |
| 春节 | 02-15 ~ 02-23 |
| 清明节 | 04-04 ~ 04-06 |
| 劳动节 | 05-01 ~ 05-05 |
| 端午节 | 06-19 ~ 06-21 |
| 中秋节 | 09-25 ~ 09-27 |
| 国庆节 | 10-01 ~ 10-07 |

### 4.2 调休上班日（周末需上班）

`2026-01-04`、`2026-02-14`、`2026-02-28`、`2026-05-09`、`2026-09-20`、`2026-10-10`

### 4.3 工作日定义

```
isWorkday(d) = (周一至周五 且 不在 §4.1) 或 在 §4.2
```

---

## 5. 每日数据与状态

### 5.1 DayRecord 字段

```swift
DayRecord {
  inHengqin: Bool        // 该天 GPS 命中 或 手动标记在横琴
  isLeave: Bool          // 请假（视同在横琴，用于桥接）
  manualHengqin: Bool    // 区分手动 vs GPS：手动标记的优先级最高，关闭时回退到 GPS 历史
}
```

### 5.2 关闭手动标记的回退

关闭 `manualHengqin` 时：
- 若该天 GPS 日志中存在 `inHengqin: true` 的样本，保持 `inHengqin: true`
- 否则置为 `false`

### 5.3 桥接规则（bridge）

> 一个法定假期段，若**段前一天**和**段后一天**都在横琴（GPS 或手动或请假），则该假期段内所有未独立标记的天**自动计入**（标记为 `bridged`）。

**桥接锚点必须是工作日**（见 [`decisions.md`](decisions.md) `v2.14.0` 锚点修复）。

**示例**：9-30 和 10-08 均工作日且 inHengqin → 国庆 10-01 ~ 10-07 全部桥接 → 自然日 +7。

### 5.4 状态判定

工作日：
```
hengqin    if record.inHengqin
bridged    elif date ∈ bridgedDays
none       otherwise
```

非工作日（周末/法定假日）：
```
hengqin    if record.manualHengqin
bridged    elif date ∈ bridgedDays
none       otherwise
```

**关键差异**：非工作日的 GPS 命中（`inHengqin && !manualHengqin`）**不**计入自然日 — 见 [`decisions.md`](decisions.md) `2026-03-09` 条目。

### 5.5 渲染优先级（热力图色块）

| 优先级 | 类型 | 条件 | 默认色（sequoia） |
|---|---|---|---|
| 1 | `leave`    | bridged & isLeave         | 蓝 `#3D7BF0` |
| 2 | `bridge`   | bridged & !isLeave        | 黄 `#F2BC3D` |
| 3 | `manual`   | hengqin & manualHengqin   | 深绿 `#2F8F3F` |
| 4 | `gps`      | hengqin & !manualHengqin  | 浅绿 `#7AC07A` |
| 5 | `future`   | date > today              | 浅灰 `#EAEDED` |
| 6 | `absent`   | none                      | 灰 `#D1D3D4` |

---

## 6. 统计

```
naturalDays = | { date | dayStatus(date) ≠ none } |
workdays    = | { date | dayStatus(date) ≠ none ∧ isWorkday(date) } |
```

**Pace（节奏）显示**：
- 期望自然日 = round(dayOfYear / 365 × 183)
- 期望工作日 = round(elapsedWorkdays / totalWorkdays × 124)
- diff = 实际 − 期望，正值显示「↑ 超前 N 天」（绿），负值显示「↓ 落后 N 天」（红），±0 显示「持平」（灰）
- 进度条宽度 = min(value / target, 1)，竖线标记期望位置

---

## 7. 数据持久化（macOS）

### 7.1 本地

```
~/Library/Application Support/HengqinTracker/
├── profiles.json                       # 档案列表 + activeProfileId
└── records/
    ├── <profileId-1>.json              # 该 profile 的所有 DayRecord（dict { "day_2026-01-01": {...} } 形式，与 Chrome 扩展对齐）
    └── <profileId-2>.json
```

旧版本（v1.x）仅有 `records.json`，首次启动新版本时自动迁移到默认档案的 `records/<defaultId>.json`。

### 7.2 iCloud KVS

KVS 限额：1 MB / 1024 keys / 单 key ≤ 1 MB。一年记录 ~29 KB，单档案安全；十档案 × 29 KB ≈ 290 KB，仍远低于上限。

key 命名：
- 档案列表：当前**不上同步**（仅本地）。每台设备各自维护自己关心的档案集合
- 每档案记录：`hengqin.records.v1.<profileId>`
- 同步状态/最后同步时间：`UserDefaults`（设备本地，不进 KVS）

> 不同步档案列表是有意为之：不同 Mac 上想看的档案可能不一样。如果未来要同步档案列表，新增 key `hengqin.profiles.v1`。

冲突解决：**系统级 last-write-wins**（KVS 本身的语义），不在应用层做额外合并。

### 7.3 enabled 由谁决定

- iCloud 同步默认**关闭**
- 用户在设置页打开 → 整个 KVS 链路启用
- 关闭后，本地数据保留，仅停止推送/拉取

### 7.4 启用前提

- 签名 `.app` + Developer ID provisioning profile（授权 `com.apple.developer.ubiquity-kvstore-identifier`）
- 用户已登录 iCloud（`FileManager.default.ubiquityIdentityToken != nil`）

详细打包流程见 [README.md](README.md) "签名打包" 一节。

---

## 8. 导入 / 导出（双端兼容）

### 8.1 JSON Schema

```jsonc
{
  "version": 1,
  "exportDate": "2026-05-19T17:12:09.360Z",
  "data": {
    "day_2026-01-01": { "inHengqin": true, "isLeave": false, "manualHengqin": true },
    "day_2026-02-11": { "inHengqin": false, "isLeave": true,  "manualHengqin": false }
    // ...
  }
}
```

key 形如 `day_YYYY-MM-DD` 的条目计入；其它前缀（`loc_*` GPS 日志、`errlog_*` 错误日志）解码时**静默忽略**。

### 8.2 macOS 导入策略

> **按 Profile 显式触发**：导入/导出按钮直接挂在每条档案的右侧，操作对象就是那一条档案，**不需要先切换到该档案**。

- 设置页 → 坐标档案 → 每行右侧 4 个图标：⬇导入 / ⬆导出 / ✏编辑 / 🗑删除
- 导入前弹 `confirmationDialog`，确认按钮 `role: .destructive`，文案明确"覆盖到「<name>」"
- 只影响目标档案的数据，其它档案完全不动
- 如果目标是当前活动档案，立即调 KVS push 同步到云端
- 如果目标不是活动档案，直接写入对应的 `records/<id>.json` 文件，下次用户切到该档案时 `sync.bootstrap` 会自动推送到 KVS

### 8.3 macOS 导出策略

- 按下哪条档案的导出按钮，就导出哪条档案的全部 DayRecord
- 文件名：`hq-backup-<profileName>-<today>.json`
- 同样的格式可被 Chrome 扩展导入（向后兼容）

---

## 9. macOS UI 规范

### 9.1 面板布局（640 × 386 popover）

```
┌─ Header ───────────────────────────────────────────────┐
│ [横] <profile name>                  [当前在 ●] [○○○○]  │
│      一年几天 · 2026 年度 · 截至 2026-05-19            │
├─ Stats Row ────────────────────────────────────────────┤
│ 自然日                       工作日                     │
│ 111 / 183  ↑超前 41 天      71 / 124  ↑超前 25 天       │
│ ▰▰▰▰▰▰▱▱▱▱▱▱▱│              ▰▰▰▰▰▰▰▱▱▱▱▱▱│             │
├─ View Toggle Divider ──────────────────────────────────┤
│ [全年 | 本月]  12 个月概览                              │
├─ Heatmap Body ─────────────────────────────────────────┤
│ ...                                                    │
├─ Footer ───────────────────────────────────────────────┤
│ ● GPS ● 手动 ● 请假 ● 桥接 ● 未计  日期·状态  [分享][设置]│
└────────────────────────────────────────────────────────┘
```

- **Header title**：直接显示当前坐标档案名（例如「横琴」「深圳」）
- **Header subtitle**：`一年几天 · 2026 年度 · 截至 YYYY-MM-DD`
- **Theme swatches**：4 个圆形色卡水平排列直接展示 4 套主题色调，点击切换；当前主题外圈描边 + 略放大
- **分享按钮**：点击渲染 HeatmapExportView (980×420) → NSImage → NSPasteboard，即"复制看板图到剪贴板"
- **导出按钮已移除**（导入导出现在按 profile 行触发，见 §8.2）

### 9.2 关键交互

- 单击日期 → 选中
- 右键日期 → 标记/取消 在横琴/请假/清除
- 单击「设置」 → 打开独立 NSWindow（含 §3.1 档案管理、§8 导入导出、§7.2 iCloud 开关）
- 切换主题：4 套预设（sequoia/tahoe/sonoma/graphite），映射到 default/warm/ocean/emerald 4 套色板

### 9.3 今日提示

- 年视图：今天单元格双层描边 + 1.1 秒呼吸脉冲动画；**不再**显示"今天"文字（脉冲已足够指示）
- 月视图：今天单元格 1.5pt 主色描边 + 数字加粗

### 9.4 坐标档案的地图选择交互

`ProfileEditorView` 的「坐标」字段提供「在地图上选择…」按钮，弹出 `LocationPickerSheet`：

| 元素 | 行为 |
|---|---|
| 顶部搜索框 | `MKLocalSearchCompleter`（类型 `.address + .pointOfInterest`），输入即时返回候选 |
| 候选列表 | 点击 → `MKLocalSearch.start()` 取出 `MKMapItem` 经纬度，地图飞到该点 |
| SwiftUI `Map` | 拖拽 / 缩放任意操作，**中心点永远是被选坐标**（瞄准镜模式），通过 `onMapCameraChange` 更新 |
| 中心钉 | 红色 `mappin` SF Symbol + 阴影，仅做视觉提示，不可拖动 |
| 反向地理编码 | `CLGeocoder.reverseGeocodeLocation(_, preferredLocale: zh_CN)`，400ms 节流防抖 |
| "使用当前位置"按钮 | `CLLocationManager.requestWhenInUseAuthorization()` → `requestLocation()` 一次性读取 |
| "使用此处"按钮 | 把当前中心坐标 + 反向地理编码出的地名回填到 ProfileEditorView |

提交后：
- 经纬度填入对应输入框，6 位小数（~10cm 精度），去尾零
- 若 ProfileEditorView 的「名称」字段为空，自动用地址名作为默认名（用户可改）

---

## 10. 权限与同步前置条件（macOS）

| 能力 | Sandbox entitlement | Info.plist 配套 | 限制性？需要 provisioning profile？ |
|---|---|---|---|
| 文件导入/导出 | `com.apple.security.files.user-selected.read-write` | — | 否 |
| 网络（KVS 走 Apple 服务） | `com.apple.security.network.client` | — | 否 |
| **定位（地图选点 + 当前位置）** | `com.apple.security.personal-information.location` | `NSLocationWhenInUseUsageDescription` | **否** |
| **iCloud KVS 跨设备同步** | `com.apple.developer.ubiquity-kvstore-identifier` | — | **是**（需 Developer ID profile） |

定位 entitlement 是 `com.apple.security.*` 命名空间（sandbox-scoped），**不需要** provisioning profile，因此 `script/HengqinTracker.entitlements.lite` 和正式版都开。
iCloud KVS 仍属 `com.apple.developer.*` 命名空间（restricted），LITE 模式无法启用，详见 README.md "签名打包"。

macOS 上 `CLAuthorizationStatus` **不**区分 `.authorizedWhenInUse` 与 `.authorizedAlways` —— 同意后状态值统一为 `.authorizedAlways`。

---

## 11. 文档维护规约

1. 任何改动 §2 ~ §8 任一节内容的 PR 必须**同步**修改本文件
2. 修改本文件时同步在 `decisions.md` 末尾追加一条变更记录（上下文 / 关键变更 / 理由 / 后续影响）
3. 修改时将顶部 `Last updated` 日期改为当天（UTC+8）
4. 当 SPEC 与实现冲突时，**以 SPEC 为准**，调整实现而非 SPEC（除非 PR 显式声明"这是 SPEC 变更"）
5. Claude 在执行业务相关任务时，应在动手前先读本文件；若发现陈旧条目，**主动**提出更新建议而不是默默继续

---

## Appendix A：技术栈速查

| 层 | 技术 | 文件起点 |
|---|---|---|
| Chrome 扩展业务 | Vanilla JS, Manifest V3 | `manifest.json`, `popup/popup.js`, `background/service-worker.js` |
| Chrome 扩展业务规则 | `utils/holidays.js`, `utils/calculator.js` | — |
| macOS Core | Swift 6, 单元测试 | `Sources/HengqinCore/` |
| macOS App | SwiftUI + AppKit (NSPopover + NSWindow) | `Sources/HengqinTracker/` |
| 同步 | `NSUbiquitousKeyValueStore` | `Sources/HengqinTracker/Stores/iCloudSyncManager.swift` |
| 定位 / 地图选点 | CoreLocation + MapKit (SwiftUI `Map`, `MKLocalSearchCompleter`, `CLGeocoder`) | `Sources/HengqinTracker/Views/LocationPickerSheet.swift`, `Stores/LocationPermissionManager.swift` |
| 打包 | `script/build_signed_app.sh` | — |
| 测试 | XCTest | `Tests/HengqinCoreTests/` |
