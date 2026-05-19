# What's New（版本说明）

> 每次更新都要写。最长 4000 字符，但一般 3-5 句话足够。
> 关键：**写用户视角的变化**，不是 commit message。

## v1.0.0 — 首次上架

中文：
```
首次发布。

· macOS 菜单栏一眼看天数，年度自然日与工作日双进度条
· 全年热力图 + 月度日历视图，4 套主题色板可切
· 多坐标档案：横琴、深圳、老家、海外，每个地点独立数据
· 法定假期智能桥接：假期前后都在追踪地点，假期自动计入
· iCloud Key-Value Storage 跨 Mac 同步，无账号、零追踪
· 内置 Apple 地图选点，支持 POI 搜索 + 反向地理编码
· JSON 导入导出兼容 Chrome 扩展版

需要 macOS 15 及以上。
```

English:
```
Initial release.

· At-a-glance day count and yearly progress (natural days / workdays) in the menu bar
· Year heatmap + month calendar with 4 theme palettes
· Multiple location profiles — each place keeps its own dataset
· Smart holiday bridging — if you were here before and after a holiday, it counts
· Cross-Mac sync via iCloud Key-Value Storage — no account required, zero tracking
· Built-in Apple Maps picker with POI search & reverse geocoding
· JSON import / export compatible with the companion Chrome extension

Requires macOS 15 or later.
```

## 后续模板

把 commit log 中跟用户**看得见的功能或修复**相关的 2-4 行翻译成动作描述。
内部重构、性能微调、文档更新一律不写。

例：

```
v1.1.0
· 修复了 6 月切换月份时面板高度抖动的问题
· 设置页坐标档案行新增导入/导出快捷按钮
· 菜单栏标题文案优化
```
