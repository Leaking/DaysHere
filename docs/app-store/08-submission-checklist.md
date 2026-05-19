# 上架清单 · 你（人）需要做的事

> 这份是**操作手册**。Claude 已经把能做的都做完了，剩下都是必须用浏览器登录 Apple 后台才能完成的。逐条勾掉就上线了。
>
> **Apple ID**：742223410@qq.com（登录用，不公开）
> **公开联系邮箱**：chenhuazhaoao@gmail.com（隐私政策、审核备注、用户反馈邮箱）

---

## ✅ Claude 已完成

| 项 | 状态 |
|---|---|
| 1024×1024 应用图标 | `icons/icon1024.png` |
| App Store 截图 (3 张 2560×1600 + 1 张 share card) | `docs/app-store/screenshots/` |
| 隐私政策托管 | https://leaking.github.io/DaysHere/privacy/ |
| MAS 打包脚本 | `script/build_mas_app.sh` |
| MAS entitlements 模板 | `script/HengqinTracker.entitlements.mas` |
| 所有上架文案（描述、关键词、推广文、审核备注） | `docs/app-store/01~07` |

---

## ❶ App Store Connect 应用记录（5 分钟）

登录 [appstoreconnect.apple.com](https://appstoreconnect.apple.com/)（用 `742223410@qq.com`）：

1. **My Apps → +（左上） → New App**
2. 填入：

   | 字段 | 值 |
   |---|---|
   | Platforms | ☑ macOS |
   | Name | `一年几天` |
   | Primary Language | 简体中文 |
   | Bundle ID | `com.harry.dayshere`（下拉选；如果没有，跳到下面 ❷ 注册 App ID 再回来） |
   | SKU | `dayshere-2026` |
   | User Access | Full Access |

3. 进入新建的应用，左侧 **App Information**：
   - Category: Primary = **Productivity**，Secondary = **Utilities**
   - Content Rights: "No"
   - **Age Rating** → 点 Set up → 问卷全部 None → 提交得 4+
   - **Copyright**: `© 2026 Huazhao Chen`
   - **Privacy Policy URL**: `https://leaking.github.io/DaysHere/privacy/`

4. 左侧 **App Privacy** → Get Started → "Does this app collect any data?" 选 **"No, we do not collect data from this app"** → 保存（最终徽章会显示 "Data Not Collected"）

---

## ❷ developer.apple.com 准备 App ID 与证书

登录 [developer.apple.com/account](https://developer.apple.com/account)（同样 `742223410@qq.com`）：

### App ID（可能已存在，先去看一眼）

**Identifiers** → 搜索 `com.harry.dayshere`：

- 存在：点进去，确保以下 capabilities 已勾：
  - ☑ iCloud（点配置 → 选 **CloudKit** + **Key-Value storage**；这两个一起勾）
- 不存在：**+** → App IDs → App → Explicit `com.harry.dayshere`，勾上上面那些 capabilities

### 两个证书（如果还没有）

**Certificates → +**：

| 证书类型 | 用途 |
|---|---|
| **3rd Party Mac Developer Application** | 签 .app |
| **3rd Party Mac Developer Installer** | 签 .pkg |

⚠️ 这两个**不是** Developer ID 证书（虽然名字很像）。MAS 与 Developer ID 是两条独立分发通道。

生成步骤：
1. 在你的 Mac 上"钥匙串访问.app" → 菜单 → 证书助理 → 从证书颁发机构请求证书 → 保存到磁盘得到 `.certSigningRequest`
2. 在 developer.apple.com 后台上传那个 CSR 文件
3. 下载生成的 `.cer` 文件，**双击**导入钥匙串

完成后验证：

```bash
security find-identity -v -p codesigning | grep "3rd Party"
```

应该看到两行 `3rd Party Mac Developer Application` 和 `3rd Party Mac Developer Installer`。

### Provisioning Profile

**Profiles → +**：

- Distribution → **Mac App Store**
- App ID: `com.harry.dayshere`
- Certificates: 选刚才创建的 `3rd Party Mac Developer Application` 这一份
- Profile Name: `DaysHere MAS Distribution`
- Generate → Download → 得到 `.provisionprofile` 文件
- **重命名为 `mas-distribution.provisionprofile`** 放到仓库 `script/` 目录下（.gitignore 已经覆盖任何 `*.provisionprofile` 不会误提交）

---

## ❸ 打包 + 上传（用现成的脚本）

证书和 profile 就位后：

```bash
./script/build_mas_app.sh
```

会产出 `dist/DaysHere.pkg`，签好的 MAS 包。

**上传方式**（任选其一）：

A. **Transporter.app**（推荐，最简单）
- App Store 搜 "Transporter" 下载安装
- 启动，用 742223410@qq.com 登录
- 把 `dist/DaysHere.pkg` 拖进去 → Deliver
- 1-15 分钟后在 App Store Connect 的 TestFlight / Builds 里看到

B. **命令行**（需要先在 [appleid.apple.com](https://appleid.apple.com) 生成 App-specific password，然后存到钥匙串）
```bash
# 一次性把 app-specific 密码存到钥匙串
xcrun notarytool store-credentials altool-credentials \
    --apple-id 742223410@qq.com \
    --team-id HYF3XBWBL2 \
    --password <你刚生成的 app-specific 密码>

# 之后每次：
./script/build_mas_app.sh upload
```

---

## ❹ 填提交材料（10 分钟）

回到 App Store Connect，进入 App → 选 `1.0 Prepare for Submission`，按下表逐项复制粘贴（**全部材料**都已经在 `docs/app-store/` 里准备好）：

| App Store Connect 字段 | 复制源 |
|---|---|
| **Subtitle** | `01-app-info.md` 副标题 → `记录我在某处住过的每一天` |
| **Description** (zh-Hans) | `02-description-zh.md` 全文 |
| **Description** (en-US) → 先点 + 加 English (U.S.) localization | `02-description-en.md` 全文 |
| **Keywords** (zh-Hans) | `03-keywords.md` 中文段 |
| **Keywords** (en-US) | `03-keywords.md` 英文段 |
| **Promotional Text** | `04-promotional-text.md` 中文段 |
| **Support URL** | `https://github.com/Leaking/DaysHere/issues` |
| **Marketing URL**（可选） | `https://github.com/Leaking/DaysHere` |
| **What's New** | `05-whats-new.md` v1.0.0 中文 |
| **Screenshots** | 把 `docs/app-store/screenshots/01~03-*.png` 拖入（不用全部 3 张，最少 1 张即可）|
| **App Review Information → Notes** | `07-app-review-info.md` Notes 段 |
| **Sign-in required** | No |
| **Demo account** | 留空 |
| **Contact** | 名 Huazhao / 姓 Chen / 邮箱 chenhuazhaoao@gmail.com / 电话填自己愿意公开的 |

**Build** 一栏：点 +, 选刚上传的 `DaysHere.pkg` 对应的构建版本。
**App Icon**: App Store 现在自动从 .pkg 里读取，不需要单独上传。
**Pricing and Availability**: 免费 + 地区可用性按你想要勾。

---

## ❺ 提交审核

顶部 **Add for Review** → 浏览一遍 → **Submit for Review**

审核周期：通常 24-72 小时。

被拒处理：
- 看 Apple 在 Resolution Center 里的 message
- 90% 的拒绝是因为"用法不清晰"或"截图与功能不符"。回复就行，附补充说明
- 如果是技术问题（崩溃、entitlement 缺失），看 Apple 给的 console log，修了重新打包重传

---

## ❻ 上架后

- 监控 App Store Connect → Sales and Trends
- 用户评价：定期回复
- 后续更新：改 `05-whats-new.md` v 字段，重打包重传，提交新版本审核

---

## 用 Claude 帮忙的快捷调用

| 我说的命令 | 我会做的事 |
|---|---|
| "改一下应用描述" | 修改 `02-description-{zh,en}.md`，下次提交审核会同步更新 |
| "重生成截图" | 修改 `AssetGenerator.swift` 然后跑 `swift run HengqinTracker --generate-assets --out .` |
| "version 1.1 release notes" | 改 `05-whats-new.md` 加新段 |
| "迁移到付费 X 元" | 改 `01-app-info.md` 价格段 + 提醒你 App Store Connect 里改价格 |
| "改隐私政策" | 改 `06-privacy-policy.md` + `gh-pages/privacy/index.html` |
