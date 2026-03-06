# 决策日志

## 变更记录 - 2026-03-04

- **上下文**：macOS 企业网络（6GHz WiFi + VPN）下 `navigator.geolocation` 间歇性失败，原有代码无重试、超时短、错误无持久化日志
- **关键变更**
  - 三层定位重试策略：offscreen 内部重试（高精度→低精度→等3s→再试低精度）、service-worker 层 10s 后重试一次、popup 层 3s 后重试整轮
  - 低精度超时从 15s 延长到 30s（Mac WiFi/IP 定位在弱网下需要更长时间）
  - 新增 `errlog_YYYY-MM-DD` 错误日志写入 `chrome.storage.local`，每天上限 20 条，popup 通过 `SAVE_ERROR_LOG` 消息委托 service-worker 写入
  - 版本号 2.0.0 → 2.1.0
- **理由**：企业网络环境不稳定但非永久故障，单次重试即可显著提高成功率；错误日志持久化便于事后排查定位失败模式
- **后续影响**：`chrome.storage.local` 新增 `errlog_` 前缀的 key，数据迁移逻辑无需调整（仅读 `day_`/`loc_` 前缀）；offscreen 单次定位最长耗时从 ~25s 增至 ~73s（10+30+3+30）

## 变更记录 - 2026-03-06

- **上下文**：多选日期后缺乏便捷的取消方式，原左键点击会同时选中日期导致 UX 混乱
- **关键变更**
  - 扩展名称更新为 "HQ天数统计工具"（manifest.name）
  - 多选交互重设计：左键 mousedown 不再写入 selectedDays，选中状态仅由右键 / 鼠标拖拽产生
  - document 级 click 监听：左键点击面板任意位置清除 selectedDays（context-menu 内部除外）
  - 新增 `justDragged` 标志：mouseup 时若正在拖拽则置 true，拦截紧随其后的 click 事件，避免拖拽释放后立即丢失选中状态
- **理由**：用户难以取消多选；右键/拖拽是选择动作，左键是确认/取消动作，语义更清晰
- **后续影响**：Shift+click 扩选逻辑已一并移除（mousedown 不再读 shiftKey）
