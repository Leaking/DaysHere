# CLAUDE.md

本文件为 Claude Code 提供该仓库的开发指引。

## 项目概述

「一年几天 / DaysHere」是一款 **macOS 菜单栏原生应用**（SwiftUI + AppKit），用于统计用户一年内在任意关心的地点实际驻留的天数。默认坐标档案 = 横琴粤澳深度合作区，目标 **183 自然日 / 124 工作日**。

**SPEC.md** 是业务规格的权威来源，遇到规则疑问或变更时优先查阅。

---

## 开发方式

```bash
swift build                 # 编译
swift run HengqinTracker    # 运行（裸构建，无签名）
swift test                  # 单元测试（HengqinCoreTests）
```

签名打包 / MAS 打包见 `script/build_signed_app.sh` 与 `script/build_mas_app.sh`。

---

## 业务逻辑

### 横琴区域判定（默认档案）

- 中心坐标：**22.125°N, 113.535°E**，判定半径：**8 km**，算法：Haversine 公式
- 多坐标档案：用户可在设置中新建/编辑/删除任意档案；每个档案有独立的 DayRecord 集合
- 当天任意一次定位落在判定半径以内，该天即标记为 `inHengqin: true`

### 2026 年假期数据

**法定假日（放假日期）：**

| 节假日 | 日期范围 |
|--------|----------|
| 元旦 | 01-01 ~ 01-03 |
| 春节 | 02-15 ~ 02-23 |
| 清明节 | 04-04 ~ 04-06 |
| 劳动节 | 05-01 ~ 05-05 |
| 端午节 | 06-19 ~ 06-21 |
| 中秋节 | 09-25 ~ 09-27 |
| 国庆节 | 10-01 ~ 10-07 |

**调休上班日（周末需上班）：** `01-04`、`02-14`、`02-28`、`05-09`、`09-20`、`10-10`

**工作日定义：**`(周一至周五 且 不在法定假日) 或 在调休上班日`

### 每日状态模型

```swift
DayRecord {
  inHengqin: Bool        // 该天 GPS 命中 或 手动标记在档案地点
  isLeave: Bool          // 请假（视同在档案地点，用于桥接）
  manualHengqin: Bool    // 区分手动 vs GPS：手动标记的优先级最高
}
```

**取消手动标记的回退逻辑**：关闭 `manualHengqin` 时，若该天 GPS 日志存在 `inHengqin: true` 的样本则保持 `inHengqin: true`，否则置为 `false`。

### 天数统计规则

**自然日** — 满足以下任一条件计为一天：
- `inHengqin === true`（GPS 或手动）
- `isLeave === true`
- 被假期桥接规则覆盖

**工作日** = 自然日集合 ∩ 工作日集合

**假期桥接规则**：对每个法定假期段，若段前一天和段后一天都在档案地点（`inHengqin || isLeave`），且锚点均为工作日，则该假期段内所有尚未计入的天自动标记为 `bridged`。

> 示例：9/30 和 10/8 在横琴 → 国庆 10/1~10/7 全部桥接 → 自然日 +7。

### 日期渲染状态（按优先级）

详见 SPEC §5.5。简表：

| 优先级 | 类型 | 条件 |
|---|---|---|
| 1 | `leave` | bridged & isLeave |
| 2 | `bridge` | bridged & !isLeave |
| 3 | `manual` | hengqin & manualHengqin |
| 4 | `gps` | hengqin & !manualHengqin |
| 5 | `future` | date > today |
| 6 | `absent` | none |

---

## 架构模式

### 模块划分

- **HengqinCore**（`Sources/HengqinCore/`）：纯业务逻辑，无 UI / 无平台依赖。日期 / 假期 / 桥接 / 统计 / 备份 / 档案模型。可独立单测。
- **HengqinTracker**（`Sources/HengqinTracker/`）：应用层。SwiftUI 视图 + AppKit 集成（NSPopover + NSWindow）+ Store + iCloud + CoreLocation/MapKit。

### 定位

- CoreLocation `CLLocationManager` 提供位置；MapKit `Map` + `MKLocalSearchCompleter` 用于设置面板上的地图选点
- 定位 entitlement 是 `com.apple.security.personal-information.location`（sandbox-scoped，**不需要** provisioning profile，LITE 模式也开）

### 双层存储

| 存储 | 内容 | 路径 / Key |
|------|------|---------|
| 本地文件 | 档案列表 + 各档案 DayRecord | `~/Library/Application Support/HengqinTracker/profiles.json` + `records/<profileId>.json` |
| iCloud KVS（可选） | 各档案的 DayRecord 字典 | key = `hengqin.records.v1.<profileId>` |

档案列表本身**不**进 KVS（每台设备各自维护关心的档案集合）。冲突解决：系统级 last-write-wins。

### 启用 iCloud 同步的前提

- 签名 `.app` + Developer ID provisioning profile（授权 `com.apple.developer.ubiquity-kvstore-identifier`）
- 用户已登录 iCloud（`FileManager.default.ubiquityIdentityToken != nil`）

裸 `swift run` 没有 entitlement，设置页会显示「iCloud 同步不可用」，本地数据照常工作。

---

## UI 功能（面板 640 × 386）

- **Header**：当前档案名 + 副标题（年份 / 截至日期）+ 当前定位指示 + 4 个主题色卡
- **Stats Row**：自然日 / 工作日 双进度条 + 节奏对比（↑ 超前 / ↓ 落后）
- **View Toggle**：「全年 / 本月」切换
- **Heatmap Body**：年视图 12 月概览或月视图详细
- **Footer**：图例 + 日期·状态 + 分享按钮（复制看板图到剪贴板）+ 设置按钮
- **设置窗口**：独立 NSWindow，包含档案管理（多档案 CRUD + 地图选点）+ iCloud 同步开关 + 主题预览

### 交互

- 左键日期 → 选中
- 右键日期 → 标记/取消 在横琴/请假/清除
- 4 套主题色板：sequoia / tahoe / sonoma / graphite（映射到 default/warm/ocean/emerald 配色）
