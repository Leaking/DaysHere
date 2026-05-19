---
name: publish
description: 一键发布：版本号更新、git 提交、打包 zip、上传并发布到 Chrome Web Store
triggers:
  - publish
  - release
  - 发布
  - 打包
  - bump version
  - 发布到商店
  - 上传商店
  - chrome web store
---

# /publish - 一键发布到 Chrome Web Store

## 参数说明

- **无参数**：自动 minor bump 版本号（如 2.5.0 → 2.6.0），提交、打包、上传、发布
- **`<version>`**：指定版本号（如 `/publish 3.0.0`）

---

## 凭证配置文件

凭证存放在 `~/.config/hengqin-cws.json`（不进 git），格式：

```json
{
  "extension_id": "你的 Extension ID",
  "client_id":    "xxx.apps.googleusercontent.com",
  "client_secret": "GOCSPX-xxx",
  "refresh_token": "1//xxx"
}
```

---

## 执行流程

### 1. 前置检查

- 运行 `git status` 确认有待提交的变更；若工作区干净，提示"无变更可发布"并退出
- 读取 `~/.config/hengqin-cws.json`；若文件不存在或字段缺失，**停止并输出首次配置指南**（见下方）

### 2. 版本号更新

- 读取 `manifest.json` 当前版本
- 若用户指定了版本号则使用之，否则自动 minor bump（如 2.5.0 → 2.6.0）
- 更新 `manifest.json` 中的 `"version"` 字段

### 3. 提交代码

- `git add` 所有已修改的被跟踪文件（不 add untracked 文件，除非它们属于本次功能变更）
- 生成 commit message，格式：`feat: v{版本号} {一句话总结本次变更}`
- 提交时附带 `Co-Authored-By: Codex Opus 4.6 <noreply@anthropic.com>`

### 4. 打包 zip

- 输出路径：`/Users/bytedance/Documents/workspace/hengqin/hengqin-tracker.zip`
- **必须先删除旧 zip**（`rm -f`），因为 `zip -r` 是追加模式，不删会导致多份 manifest 共存
- 排除项：`.git/*`、`.Codex/*`、`.DS_Store`、`*.zip`、`__MACOSX/*`
- 命令：`rm -f <输出路径> && zip -r <输出路径> . -x '.git/*' '.Codex/*' '.DS_Store' '*.zip' '__MACOSX/*'`

### 5. 获取 Access Token

```bash
curl -s -X POST https://oauth2.googleapis.com/token \
  -d "client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&refresh_token=$REFRESH_TOKEN&grant_type=refresh_token"
```

从响应 JSON 中提取 `access_token`。若获取失败（无 access_token），输出错误信息并退出。

### 6. 上传 zip

```bash
curl -s -X PUT \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "x-goog-api-version: 2" \
  -T /Users/bytedance/Documents/workspace/hengqin/hengqin-tracker.zip \
  "https://www.googleapis.com/upload/chromewebstore/v1.1/items/$EXTENSION_ID"
```

检查响应：
- `uploadState: "SUCCESS"` → 继续
- 其他 → 输出响应内容并退出

### 7. 提交发布

```bash
curl -s -X POST \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "x-goog-api-version: 2" \
  -H "Content-Length: 0" \
  "https://www.googleapis.com/chromewebstore/v1.1/items/$EXTENSION_ID/publish"
```

检查响应：
- `status` 包含 `"OK"` 或 `"PUBLISHED"` → 成功
- 其他 → 输出完整响应

### 8. 输出确认

完成后输出：
- 新版本号
- commit hash（短）
- zip 文件路径及大小
- Extension ID
- 发布状态
- 商店链接：`https://chromewebstore.google.com/detail/<extension_id>`

---

## 首次配置指南（凭证不存在时输出）

当 `~/.config/hengqin-cws.json` 不存在时，向用户输出以下完整步骤：

---

### 一、获取 Extension ID

1. 打开 [Chrome Web Store Developer Dashboard](https://chrome.google.com/webstore/devconsole)
2. 点击你的插件 → 地址栏或"项目主页"中找到形如 `abcdefghijklmnopqrstuvwxyz123456` 的 32 位 ID

---

### 二、创建 OAuth2 凭证

1. 打开 [Google Cloud Console](https://console.cloud.google.com/)
2. 创建项目（或选择已有项目）
3. 左侧菜单 → **API 和服务 → 库** → 搜索 `Chrome Web Store API` → 启用
4. 左侧 → **API 和服务 → 凭据** → **创建凭据 → OAuth 客户端 ID**
   - 应用类型：**桌面应用**
   - 名称随意，如 `hengqin-publisher`
5. 创建后下载 JSON，或记下 `client_id` 和 `client_secret`

---

### 三、获取 Refresh Token（只需操作一次）

在终端执行（替换 CLIENT_ID）：

```bash
open "https://accounts.google.com/o/oauth2/auth?client_id=CLIENT_ID&redirect_uri=urn:ietf:wg:oauth:2.0:oob&response_type=code&scope=https://www.googleapis.com/auth/chromewebstore"
```

浏览器会弹出授权页面，登录开发者账号并同意授权，页面显示一段 **authorization code**。

复制该 code，执行（替换三个占位符）：

```bash
curl -X POST https://oauth2.googleapis.com/token \
  -d "code=AUTH_CODE&client_id=CLIENT_ID&client_secret=CLIENT_SECRET&redirect_uri=urn:ietf:wg:oauth:2.0:oob&grant_type=authorization_code"
```

响应 JSON 中的 `refresh_token` 即为所需。

---

### 四、写入配置文件

```bash
mkdir -p ~/.config
cat > ~/.config/hengqin-cws.json << 'EOF'
{
  "extension_id": "你的32位ID",
  "client_id":    "xxx.apps.googleusercontent.com",
  "client_secret": "GOCSPX-xxx",
  "refresh_token": "1//xxx"
}
EOF
```

配置完成后重新运行 `/publish`。
