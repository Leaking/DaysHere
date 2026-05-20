# 一年几天 / DaysHere

一款 macOS 菜单栏原生应用，帮助你统计自己一年内在**任意关心的地点**实际驻留的天数。

产品起源场景是 **珠海横琴粤澳深度合作区** 的法定居住认证（默认坐标档案 = 横琴，目标 **183 自然日 / 124 工作日**），通过多坐标档案可以覆盖任何地点。

技术栈：纯 SwiftUI + AppKit（NSPopover + NSWindow），CoreLocation + MapKit，iCloud KVS 跨设备同步。无外部依赖。

---

## 截图

<p align="center">
  <img src="docs/app-store/screenshots/01-main.png" width="640" alt="一年几天 主面板">
</p>

---

## 本地开发

```bash
swift build                 # 编译
swift run HengqinTracker    # 运行（裸构建，无 iCloud / 无签名）
swift test                  # 单元测试（HengqinCoreTests）
```

启动后菜单栏右侧会出现 `横 NNN`，点击展开年/月热力图面板。

> 裸 `swift run` 没有 entitlement，设置页会显示 "iCloud 同步不可用 · 当前为未签名构建"。本地数据、导入导出、定位、地图选点全部可用。

---

## 项目结构

```
Sources/
├── HengqinCore/        # 纯业务逻辑（日期 / 假期 / 桥接 / 统计），无 UI 依赖
└── HengqinTracker/     # 应用层（SwiftUI 视图 / AppKit 集成 / 存储 / iCloud）
    ├── Models/
    ├── Stores/
    ├── Views/
    └── Support/
Tests/HengqinCoreTests/  # XCTest 单元测试，覆盖统计 / 桥接 / 备份 / 档案
script/                  # 构建 + 签名 + MAS 打包脚本
docs/app-store/          # App Store 上架文案与素材
icons/icon1024.png       # 应用图标主源（构建脚本会生成 .icns）
SPEC.md                  # 业务规格权威源（修改业务逻辑必须同步）
decisions.md             # 决策日志（每次业务变更追加一条）
```

---

## 数据导入 / 导出

设置面板 → 坐标档案 → 每行右侧 4 个图标：⬇导入 / ⬆导出 / ✏编辑 / 🗑删除。

JSON 格式：

```json
{
  "version": 1,
  "exportDate": "2026-05-19T17:12:09.360Z",
  "data": {
    "day_2026-01-01": { "inHengqin": true, "isLeave": false, "manualHengqin": true }
  }
}
```

**导入会完全覆盖**对应档案的本地数据（弹出二次确认）。

---

## 签名打包 / iCloud 跨设备同步

`script/build_signed_app.sh` 一键产出 Developer ID 签名后的 `.app`，并在条件满足时自动启用 iCloud KVS 跨设备同步。

```bash
./script/build_signed_app.sh                 # 只 build + 签名
./script/build_signed_app.sh install         # 同时拷到 ~/Applications/
./script/build_signed_app.sh install run     # …并立即启动
```

### 两种模式

| 模式 | 触发条件 | 启用功能 |
|---|---|---|
| **LITE** | `script/embedded.provisionprofile` 不存在 | 仅本地数据 + 导入/导出。iCloud 同步显示「不可用」 |
| **FULL** | `script/embedded.provisionprofile` 存在 | 完整启用，包含 iCloud KVS 跨设备同步 |

脚本会自动探测 provisioning profile 是否存在并选择对应的 entitlements。**LITE 模式现在就能跑**，FULL 模式需要先完成下面这一次性的 Apple Developer 后台配置。

### 启用 iCloud 同步（一次性配置）

整套机制是：限制性 entitlement（`com.apple.developer.ubiquity-kvstore-identifier`）必须由一份嵌入的 provisioning profile 授权，否则 launchd 拒绝启动（错误 153，`taskgated: "no eligible provisioning profiles found"`）。

操作步骤：

1. **登录** [developer.apple.com](https://developer.apple.com/account) → Certificates, Identifiers & Profiles
2. **注册 App ID** → Identifiers → `+` → App IDs → App
   - Bundle ID（Explicit）：`com.harry.dayshere`
   - Capabilities：勾选 **iCloud**（选 "Include CloudKit support" 即可，KVS 不单独显示开关）
3. **创建 Profile** → Profiles → `+` → Distribution → **Developer ID** → 下一步选刚才注册的 App ID → 选 Developer ID Application 证书 → 取个名字（如 `HengqinTracker DevID`） → Generate → Download
4. 把下载到的 `.provisionprofile` 文件**重命名**为 `embedded.provisionprofile` 并放到仓库 `script/` 目录下
5. 重新执行 `./script/build_signed_app.sh install run`

控制台 / 设置页应能看到「已同步」状态。两台 Mac 同登 Apple ID + 同样的 `.app`，记录会自动双向合并（系统 last-write-wins）。

### Mac App Store 打包

`script/build_mas_app.sh` 产出可上传到 App Store Connect 的 `.pkg`。详见 `docs/app-store/`。

### Notarization（仅当要分发到其他人电脑时）

只在自己几台 Mac 间使用，可以**跳过** notarization（Gatekeeper 不会阻止你自己签的本地拷贝）。
如果要给别人，需要：

```bash
xcrun notarytool submit dist/HengqinTracker.app.zip \
    --apple-id <你的 Apple ID> --team-id HYF3XBWBL2 --password <App-specific password> \
    --wait
xcrun stapler staple dist/HengqinTracker.app
```
