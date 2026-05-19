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

## 变更记录 - 2026-05-20

- **上下文**：macOS 原生菜单栏 App 完成第三轮迭代：UI 按 v1 设计稿重做、数据导入导出、iCloud KVS 跨设备同步、Developer ID 签名脚本，并把单一坐标硬编码升级为**多坐标档案**
- **关键变更**
  - `Color+Heatmap.swift`：4 套主题色板替换为设计稿 default/warm/ocean/emerald
  - `MenuBarPanelView.swift`：整面板重构（Header / 双栏 Stats + 进度条 + 期望标记 / SegmentedToggle / Footer）
  - `YearHeatmapView.swift`：今天单元格双层描边 + 呼吸脉冲；**移除**"今天"文字标签（脉冲已足够指示）
  - `MonthHeatmapView.swift`：卡片式日期格（左上数字 / 右上 休·班 角标 / 底部 manual·leave 小圆点）
  - 新增 `DataBackup.swift` / `iCloudSyncManager.swift` / `SettingsView.swift`：Chrome 兼容 JSON 备份格式 + KVS 单 key 整体同步 + 设置窗口
  - 新增 `LocationProfile.swift` / `ProfileStore.swift`：多坐标档案模型 + 列表持久化（`profiles.json`）+ 每档案独立 records 文件（`records/<id>.json`）+ KVS key 加 profile 后缀
  - `ResidencyStore`：观察 `ProfileStore.$collection`，活动档案切换时重新载入 records + 重新订阅 KVS
  - `script/build_signed_app.sh`：Developer ID 签名 + 自适应 LITE / FULL entitlements（按是否存在 `embedded.provisionprofile` 决定）
  - 新建 `SPEC.md`：业务规则权威文档
- **理由**：用户需要追踪除横琴外的其他地点驻留（如深圳办事处、老家），同时希望跨设备同步而无需自建服务器
- **后续影响**：
  - 旧版本 `records.json` 会被一次性迁移到 `records/<defaultId>.json`，对用户无感
  - iCloud KVS key 命名从 `hengqin.records.v1` 改为 `hengqin.records.v1.<profileId>`；老版本同步过的数据需要导入/导出一次重新关联到默认档案
  - 档案列表**不**走 iCloud（不同 Mac 关心的档案集合可能不同），仅 records 走云
  - 至少保留一个档案（删除按钮在只剩一个时禁用）

## 变更记录 - 2026-05-20 (c)

- **上下文**：
  - 月视图实际渲染比年视图高出 ~50pt，导致切换视图时弹出面板抖动
  - 导入/导出按钮放在独立"数据"区，隐式作用于当前活动档案，多档案下让用户先切档再操作太绕
- **关键变更**
  - `MenuBarPanelView`：年/月分支统一 `frame(height: 150)`，常量 `heatmapBodyHeight = 150`
  - `MonthHeatmapView`：
    - `visibleWeeks` 裁掉尾部全空行（6月只剩 5 行而非硬留 6 行）
    - 网格用 `GeometryReader` 按可用高度动态算 `cellHeight`：`(geo.h - (rows-1)*3) / rows`，下限 14pt
    - `dayCell` 从 `VStack { day; Spacer; dots }` 改成单行 `HStack { day; Spacer; badge }`，去掉冗余底部小圆点（颜色已能区分 manual/leave/桥接/GPS）
  - `ResidencyStore.exportBackupData(for:)` / `importBackupReplacingAll(from:into:)` 增加 profileId 参数；非活动档案走"读/写该档案的 records 文件 + 不动 iCloud"路径，活动档案路径保持立即 push
  - `ImportSummary` 增 `profileName` 字段，summary 文案改成 `"「<name>」已导入 N 天 · 替换原有 M 天"`
  - `SettingsView`：
    - 删除独立"数据"区
    - 每个 profile 行右侧新增 4 个图标按钮：⬇导入 / ⬆导出 / ✏编辑 / 🗑删除
    - 导入二次确认 dialog 标题改为 `"确认覆盖「<name>」？"`，主按钮文案 `"覆盖导入到「<name>」"`
    - inline 错误/成功提示移到坐标档案区底部
  - SPEC §8 改写为"按 Profile 显式触发"语义
- **理由**：
  - 用户切换视图时面板抖动不可接受；月视图本身只是另一种呈现，不应该改变容器尺寸
  - 多档案下导入导出的目标必须显式，"按哪行按钮就操作哪行"比"先切档再操作"省一步交互
- **后续影响**：
  - 月视图单格更紧凑（16-20pt 高），底部小圆点取消；后续如果用户反馈需要区分 manual 和 GPS，可以考虑在单元格右下加 2pt 小三角而不是占行高的 dot
  - 非活动档案导入不会立即同步到 iCloud，需要用户主动切到该档案触发 push；这是有意为之，避免后台改其他档案的云端数据

## 变更记录 - 2026-05-20 (b)

- **上下文**：手动填经纬度对普通用户不友好；用户希望"打开地图找位置"。Apple 没有打包好的位置选择器，但 MapKit + CoreLocation 提供了所有积木
- **关键变更**
  - 新增 `Sources/HengqinTracker/Stores/LocationPermissionManager.swift`：CLLocationManager 包装；macOS 上 `.authorizedWhenInUse` 不可用，统一用 `.authorizedAlways`
  - 新增 `Sources/HengqinTracker/Views/LocationPickerSheet.swift`：SwiftUI Map 瞄准镜模式 + `MKLocalSearchCompleter` 搜索候选 + `MKLocalSearch.start()` 取坐标 + `CLGeocoder` 反向编码（400ms 节流）+ "使用当前位置"按钮
  - `ProfileEditorView.swift`：加「在地图上选择…」按钮 → 弹 sheet → 回填 lat/lng（6 位小数去尾零），若名字为空自动用反向编码出的地址作建议
  - `script/HengqinTracker.entitlements` + `.lite` 都加 `com.apple.security.personal-information.location`；这是 sandbox-scoped entitlement，不需要 provisioning profile，所以 LITE 模式也可用
  - `script/build_signed_app.sh` 生成的 Info.plist 加 `NSLocationWhenInUseUsageDescription` 说明文案
  - MapKit 类型尚未 Sendable，`LocationPickerSheet.swift` 用 `@preconcurrency import MapKit` 静默 Swift 6 strict-concurrency 警告
  - SPEC.md 增 §9.4 地图交互、§10 权限与同步前置条件对照表
- **理由**：让 Apple 自家组件承担"找位置"的复杂度，避免引入第三方 SDK
- **后续影响**：
  - 第一次点"使用当前位置"会弹系统权限对话框；用户拒绝后只能去系统设置打开
  - LocationPickerSheet 完全本地，无需联网（地图瓦片走 Apple Maps CDN，由 MapKit 自动处理）
  - 如果你的 Developer ID provisioning profile 之前没勾 Location capability，**不影响**——sandbox-scoped entitlement 不需要 profile 授权

## 变更记录 - 2026-03-09

- **上下文**：原 `getDayStatus()` 对工作日和非工作日使用相同的判定逻辑，导致非工作日的 GPS/手动标记也被计入自然日统计
- **关键变更**
  - `getDayStatus()` 拆分为工作日/非工作日两条路径：工作日保持 GPS→手动→桥接 的优先级；非工作日仅桥接（bridged）计入
  - Tooltip 逻辑调整：请假桥接与普通假期桥接合并到 `bridged` 分支下按 `isLeave` 区分文案；`isLeave` 警告仅在 `status === 'none'` 时显示
  - 版本号 2.5.0 → 2.6.0
- **理由**：183 自然日目标中，非工作日（周末/法定假日）本身不应因 GPS 在横琴就自动计入，只有通过桥接规则覆盖时才计入，与业务规则一致
- **后续影响**：非工作日即使 GPS 检测到在横琴也不再显示绿色，减少用户困惑；统计数字可能比之前低（排除了非工作日的误计）
