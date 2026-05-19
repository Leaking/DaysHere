# 上架清单 · 你（人）需要做的事

> 这份是**操作手册**。Claude 没法帮你点 Apple 后台的按钮，但所有需要的内容材料都准备好了，照下面一步步走即可。

## ❶ App Store Connect 应用记录

需要：登录 [appstoreconnect.apple.com](https://appstoreconnect.apple.com/)

1. My Apps → "+" → New App
2. 填入：
   - Platforms: **macOS**
   - Name: `一年几天`（中文）/ 之后会有 localization 添加英文
   - Primary Language: **Simplified Chinese**
   - Bundle ID: 选择 `com.harry.dayshere`（如果列表里没有，去 Identifiers 先建一个）
   - SKU: `dayshere-2026`
   - User Access: Full Access

3. 进入新建的应用，左侧 **App Information**：
   - Category: Primary = **Productivity**, Secondary = **Utilities**
   - Content Rights: 选 "No, it does not contain, show, or access third-party content"
   - Age Rating: 点开问卷，全部选 None
   - Copyright: `© 2026 Huazhao Chen`

## ❷ 提供 1024×1024 App Icon

仓库里现在只有 16/48/128 的小图。Mac App Store 强制要求 **1024×1024 PNG 无圆角无 Alpha**。

**你需要：**
- 拿到一个矢量源（SVG/Sketch/Figma 设计稿）
- 或找设计师重画
- 或用 [Bakery](https://apps.apple.com/cn/app/bakery-simple-icon-maker/id1575220747)、[Image2Icon](https://apps.apple.com/cn/app/image2icon-make-your-icons/id992115977) 等工具从现有 128 图升采样（**画质会差**，建议至少 512 源）

放到 `icons/icon1024.png`。后续如果加入 build_signed_app.sh 自动生成 icns，把 `icon128.png` 引用换成 `icon1024.png` 即可。

## ❸ 截图（Screenshots）

App Store Connect 要求至少**一组** macOS 截图：
- 1280 × 800
- 1440 × 900
- 2560 × 1600
- 2880 × 1800

实际只需上传**一种尺寸**（推荐 1280×800 或 2880×1800），系统会自动适配。

**怎么截：**
1. 启动 DaysHere
2. 调到一个数据漂亮的状态（建议导入 demo backup：选择 `~/Downloads/hq-backup-2026-05-20.json`）
3. macOS 截图：`Cmd + Shift + 4`，然后按 `Space` 锁定窗口，移到 popover 上点击截图
4. 至少准备 3 张：
   - 全年视图 + 沿用默认浅色主题
   - 月视图 + 切换到 sonoma 青绿主题
   - 设置页坐标档案区（展示多档案 + 导入导出按钮）

放到 `docs/app-store/screenshots/`（已为你预留目录）。

## ❹ 隐私政策托管

`06-privacy-policy.md` 是源文档，但 App Store Connect 要的是 **HTTPS 公开 URL**。

**最简单方案：GitHub Pages**

```bash
# 1. 在仓库根新建 gh-pages 分支
git checkout --orphan gh-pages
git rm -rf .
# 2. 把 privacy-policy 转成 HTML 放进去
mkdir -p privacy
# 把 06-privacy-policy.md 转成 index.html（可用 pandoc 或在线工具）
git add privacy/index.html
git commit -m "Publish privacy policy"
git push origin gh-pages
# 3. 仓库 Settings → Pages → 选 gh-pages 分支 → Save
# 4. 访问 https://leaking.github.io/DaysHere/privacy/ 确认能看见
```

把这个 URL 填到 App Store Connect → App Privacy → Privacy Policy URL。

## ❺ Mac App Store 分发证书 + Provisioning Profile

⚠️ 这是与 Developer ID 分发**完全不同**的链路。

1. [developer.apple.com](https://developer.apple.com/account/resources/certificates/list) → Certificates → "+" → **Mac App Distribution** 和 **Mac Installer Distribution** 各创建一份
2. Identifiers → 你的 App ID（`com.harry.dayshere`）→ 确保已勾上：
   - iCloud（Key-Value Storage）
   - 不需要勾 Location（这是 sandbox-only entitlement）
3. Profiles → "+" → **Mac App Store** → 选 App ID + 上面创建的 Mac App Distribution 证书 → 下载 `.provisionprofile`
4. 重命名为 `script/mas-distribution.provisionprofile` 放进项目（gitignore 已经 cover 任何 `embedded.provisionprofile`，建议把 mas 那个也加进 .gitignore）

## ❻ 改造 build_signed_app.sh 为 MAS 打包

当前 `build_signed_app.sh` 是 Developer ID 路径。Mac App Store 需要：

```bash
# 用 Mac App Distribution 证书签名
codesign --force --options runtime --sign \
  "3rd Party Mac Developer Application: Huazhao Chen (HYF3XBWBL2)" \
  --entitlements <带 MAS 限制条款的 entitlements> \
  dist/DaysHere.app

# 用 Mac Installer Distribution 证书打 pkg
productbuild --component dist/DaysHere.app /Applications \
  --sign "3rd Party Mac Developer Installer: Huazhao Chen (HYF3XBWBL2)" \
  dist/DaysHere.pkg
```

可以让 Claude 后续帮你写 `build_mas_app.sh`（这个我能做，等需要 MAS 上架时告诉我）。

## ❼ 上传二进制

两种方式：
- **Transporter.app**（推荐，简单）— App Store 下载，登录 Apple ID，把 `DaysHere.pkg` 拖进去上传
- **xcrun altool / notarytool**（命令行）

上传后 1-15 分钟在 App Store Connect 的 "TestFlight" 或 "Builds" 里看到新版本，绑定到你的 App 记录。

## ❽ 填材料

打开 App Store Connect 你的 App → 选择对应 version → 填这几栏（材料都在本目录）：

| 字段 | 复制自 |
|---|---|
| Subtitle | `01-app-info.md` 副标题 |
| Description（zh-Hans） | `02-description-zh.md` |
| Description（en-US） | `02-description-en.md` |
| Keywords（zh-Hans） | `03-keywords.md` 中文一段 |
| Keywords（en-US） | `03-keywords.md` 英文一段 |
| Promotional Text | `04-promotional-text.md` |
| What's New | `05-whats-new.md` v1.0.0 |
| Privacy Policy URL | 步骤 ❹ 拿到的 GitHub Pages URL |
| App Review Information → Notes | `07-app-review-info.md` |
| Sign-in Information | "No" |
| Demo Account | 空（不适用） |
| Screenshots | 步骤 ❸ 拍的图 |

App Privacy 问卷：所有数据收集类问题都选 **No**（详见 `01-app-info.md`）。最终标签为 **Data Not Collected**。

## ❾ 提交审核

**Save** → 顶部 **Add for Review** → **Submit for Review**

审核周期：通常 24-72 小时。如果被拒：
- 看拒绝原因
- 在 App Store Connect "Resolution Center" 里回复审核员
- 90% 的拒绝是因为权限说明不清晰，或截图不真实

## ❿ 上架后

- 监控 App Store Connect → Sales and Trends
- 用户评价：定期回复
- 后续更新走相同流程（步骤 ❺~❾ 重复，材料只改 `05-whats-new.md`）

---

## 我（Claude）现在能继续帮你做的事

- 写 MAS 版本的 `build_mas_app.sh`（步骤 ❻）
- 把 `06-privacy-policy.md` 转成 HTML 准备 GitHub Pages 部署（步骤 ❹）
- 写 GitHub Actions 自动化（每次 push tag → 自动签 + 上传 Transporter）
- App 内嵌一个"关于"页面，里面放隐私政策 URL（提交审核会更顺）

需要时直接说。
