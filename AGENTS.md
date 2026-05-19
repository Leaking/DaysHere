# AGENTS.md

本文件为 Codex 提供该仓库的开发指引。

## 项目概述

HQ（横琴天数统计）是一个 Chrome 浏览器扩展（Manifest V3），用于统计用户在珠海横琴粤澳深度合作区的年度驻留天数，目标为 **183 自然日** 和 **124 工作日**。

**SPEC.md** 是业务规格的权威来源，遇到规则疑问或变更时优先查阅。

---

## 开发方式

无需构建步骤，纯原生 JavaScript。

1. 在 Chrome 打开 `chrome://extensions/`，加载已解压的扩展
2. 目录指向 `hengqin-tracker/`
3. 修改代码后点击扩展卡片上的刷新图标即可生效

无 package.json、构建工具、Lint 或测试框架。

---

## 业务逻辑

### 横琴区域判定

- 中心坐标：**22.125°N, 113.535°E**，判定半径：**8 km**，算法：Haversine 公式
- 当天任意一次定位落在 8 km 以内，该天即标记为 `inHengqin: true`，不可被后续不在横琴的定位覆盖

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

```js
DayStatus {
  inHengqin: boolean     // 是否在横琴（GPS 检测到 或 手动标记）
  isLeave: boolean       // 是否请假（视同在横琴）
  manualHengqin: boolean // 区分手动标记与 GPS 自动检测
}
```

**取消手动标记的回退逻辑**：关闭 `manualHengqin` 时，检查当天 GPS 日志，若存在任一 `inHengqin: true` 的记录则保持 `inHengqin: true`，否则置为 `false`。

### 天数统计规则

**自然日** — 满足以下任一条件计为一天：
- `inHengqin === true`（GPS 或手动）
- `isLeave === true`
- 被假期桥接规则覆盖

**工作日** = 自然日集合 ∩ 工作日集合

**假期桥接规则**：对每个法定假期段，若段前一天和段后一天都在横琴（`inHengqin || isLeave`），则该假期段内所有尚未计入的天自动标记为 `bridged`。

> 示例：9/30 和 10/8 在横琴 → 国庆 10/1~10/7 全部桥接 → 自然日 +7。

### 日期渲染状态（按优先级）

| 优先级 | 状态 | 条件 | 日历颜色 |
|--------|------|------|---------|
| 1 | `leave` | `isLeave === true` | 蓝色 |
| 2 | `hengqin` | `inHengqin === true` | 绿色 |
| 3 | `bridged` | 在桥接集合中 | 黄色 |
| 4 | `none` | 以上均不满足 | 默认 |

---

## 架构模式

### Offscreen Document 定位代理

MV3 Service Worker 无法直接调用 Geolocation API，采用 offscreen document 作为代理：
1. Service worker 通过 `chrome.offscreen` 创建 offscreen 页面
2. 发送消息请求定位
3. Offscreen 页面调用 `navigator.geolocation`，将坐标回传
4. Service worker 将结果写入存储

**定位降级策略**：Offscreen 和 Popup 均采用高精度优先（10s）→ 低精度兜底（15s）。Mac 无 GPS，依赖 WiFi/IP 定位，8km 判定半径下低精度足够。

### 双层存储策略

| 存储 | 内容 | Key 格式 | 同步 |
|------|------|---------|------|
| `chrome.storage.sync` | 日状态标记（DayStatus） | `day_YYYY-MM-DD` | 跨设备同步 |
| `chrome.storage.local` | GPS 定位日志数组 | `loc_YYYY-MM-DD` | 仅本地 |

sync 存储预估占用 ~29 KB（365 天 × ~80 字节），上限 100 KB / 512 条。

### 数据流

```
chrome.alarms（每 30 分钟）
  → service worker 唤醒
  → 创建 offscreen doc → 获取 GPS 坐标
  → isInHengqin() 判断
  → 写入 chrome.storage.sync（日状态）+ local（GPS 日志）

Popup 打开
  → 直接调用 navigator.geolocation（无需 offscreen）
  → 读取 sync + local 存储
  → calculateBridgedDays() + calculateYearStats()
  → 渲染日历 + 统计数字
```

---

## UI 功能

- **日历视图**：按月展示，周一起始，支持上/下月切换（限 2026 年）
- **日期角标**：`休` 法定假日、`班` 调休上班、`标` 手动标记、`假` 请假
- **右键菜单**：切换"在横琴"手动标记 / 切换请假（法定假日禁用）
- **顶部统计栏**：全年自然日 `N / 183`，全年工作日 `N / 124`
- **月份小统计**：当月自然日、当月工作日
- **定位状态指示**（右上角圆点）：绿色 = 当前在横琴，灰色 = 不在横琴，红色 = 定位失败
