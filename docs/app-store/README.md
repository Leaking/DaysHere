# Mac App Store 上架材料 · DaysHere / 一年几天

本目录收集所有 App Store Connect 提交需要的文案、合规文档与签名指引。
和应用业务规格无关，纯发布物。

## 目录

| 文件 | 用途 |
|---|---|
| [01-app-info.md](01-app-info.md) | 应用基本信息：名称、副标题、分类、bundle id、定价 |
| [02-description-zh.md](02-description-zh.md) | 中文版应用描述（用于简体中文、繁体中文区域） |
| [02-description-en.md](02-description-en.md) | 英文版应用描述（用于美国、英国等英文区域） |
| [03-keywords.md](03-keywords.md) | App Store 搜索关键词（中 / 英） |
| [04-promotional-text.md](04-promotional-text.md) | 推广文案（每次更新可改，不需要审核） |
| [05-whats-new.md](05-whats-new.md) | 版本更新说明模板 |
| [06-privacy-policy.md](06-privacy-policy.md) | 隐私政策正文（可作为静态页托管） |
| [07-app-review-info.md](07-app-review-info.md) | 给 Apple 审核员的备注：演示账号、测试说明 |
| [08-submission-checklist.md](08-submission-checklist.md) | **必读**：上架步骤、技术准备、需要你自己做的事 |

## 我（Claude）能准备 vs 你需要自己做

**能准备**（已写好上面那些 md）：
- 应用基本信息文案、描述、关键词、What's New、隐私政策
- 提交时给审核员的回答模板
- 上架流程清单

**只有你能做的**（在 `08-submission-checklist.md` 里列出）：
- 在 [App Store Connect](https://appstoreconnect.apple.com/) 创建 App 记录
- 上传 1024×1024 高清 app icon（当前仓库只有 128×128，需要重新绘制）
- 拍 / 渲染应用截图（1280×800、2880×1800 等指定尺寸）
- 把隐私政策托管到一个能公开访问的 URL（GitHub Pages 即可）
- 配置 Mac App Store distribution certificate + provisioning profile（与 Developer ID 不同）
- Notarization 或 Mac App Store 审核提交
- 定价、地区可用性、年龄分级问卷
