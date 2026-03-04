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
