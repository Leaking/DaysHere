# 应用基本信息

## 标识

| 字段 | 值 |
|---|---|
| 名称（Name） | 一年几天 |
| 英文名 | DaysHere |
| Bundle ID | `com.harry.dayshere` |
| Team ID | `HYF3XBWBL2` |
| SKU（自定义编号） | `dayshere-2026` |
| Primary Language | Simplified Chinese (zh-Hans) |

## 副标题（Subtitle，最多 30 字符）

中文：「记录我在某处住过的每一天」
英文：「Track your days at any place」

> 副标题在每个语言版本都可单独写。中文副标题 13 字，留有余量；英文 32 字符已经超 30，需要简化为：`Days at a place you care about.`（27 字符）

## 描述（Promotional Text，最多 170 字符，可不送审更新）

见 [04-promotional-text.md](04-promotional-text.md)

## 分类

| | 主分类 | 副分类 |
|---|---|---|
| 推荐 | **效率** (Productivity) | **工具** (Utilities) |

理由：本应用核心是个人时间统计 + 数据归档，不属于 Lifestyle / Travel。"效率 + 工具"双标签对中国地区税务/补贴用户场景最容易被搜到。

## 定价

| 选项 | 推荐 |
|---|---|
| 0 元免费 + 无内购 | ✅ |
| 0 元免费 + 内购解锁高级 | 需要后续设计高级功能 |
| 付费 6/12 元 | 不推荐 — 早期种子用户摩擦大 |

建议**先 0 元上架**，后续视使用量再考虑商业模式。

## 年龄分级

填写问卷时全部选「无 / 否」，最终评级应为 **4+**。
不涉及色情、暴力、赌博、医疗信息、不受限网络浏览。

## 地区可用性

建议先开 **中国大陆 + 港澳台 + 美国 + 加拿大 + 新加坡** 5 个区。
中国地区合规问题：
- 不需要 ICP（应用不连接自有服务器）
- 不需要软著备案（个人开发者免）
- 不需要算法备案（无推荐算法）

## 版权 / 著作权人（Copyright）

格式：`© 2026 Huazhao Chen`（用真名或工作室名）

## App Privacy（隐私问卷）

参见 [06-privacy-policy.md](06-privacy-policy.md)。本应用：
- 不收集任何个人信息
- 不发任何网络请求（除 iCloud KVS，且数据仅同步到用户自己的 Apple ID）
- 定位数据仅本地使用，不上传

在 App Store Connect 的 Privacy 问卷里，所有"是否收集"全部选 **No**，最终标签为：
- **Data Not Collected**
