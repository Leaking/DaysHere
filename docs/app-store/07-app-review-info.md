# App Review 信息

> 提交时 App Store Connect 会让你填 Review 备注、演示账号、联系方式。
> 这里准备好可直接复制粘贴的版本。

## Sign-in Information

> 是否需要登录账号才能使用？

**No** — DaysHere does not require any sign-in or account. All features work without authentication.

## Notes（给审核员的备注）

```
Dear App Review team,

DaysHere is a single-window menu bar utility for tracking how many days
per year you have actually spent at a place that matters to you (for
example, the Hengqin Cooperation Zone in China, which has a 183-day
residency rule for tax purposes).

Key points for review:

1. The app has no server. All data lives on the user's Mac and
   (optionally) the user's own iCloud Key-Value Storage. We collect
   nothing.

2. Location access is requested only when the user explicitly taps the
   "Use current location" button in the Profile Editor's map picker.
   Denial does not impact any other feature. The map picker itself is
   fully usable by manual pan/zoom or by typing an address in the
   search field.

3. The app uses standard sandbox entitlements:
   - com.apple.security.app-sandbox
   - com.apple.security.files.user-selected.read-write   (for JSON
     import/export through NSOpen/SavePanel)
   - com.apple.security.network.client                    (required by
     NSUbiquitousKeyValueStore for iCloud sync)
   - com.apple.security.personal-information.location     (for the
     optional map picker)
   - com.apple.developer.ubiquity-kvstore-identifier      (for iCloud
     sync)

4. There is no in-app purchase, no advertising, and no third-party
   analytics SDK.

5. Holiday data (Chinese public holidays for 2026) is bundled in code
   and not fetched at runtime.

6. The app icon and menubar item show the user's current day count
   (e.g. "111 天"). This number is computed entirely on-device and is
   never transmitted anywhere.

To test:

a) Launch the app — you should see "横 0 天" (or similar) appear in the
   menu bar. Click it to expand the panel.
b) Click "设置" at the bottom right to open the Settings window.
c) Try "新增" in the Coordinate Profiles section, then click
   "在地图上选择…" to test the map picker.
d) Toggle "通过 iCloud 跨设备同步" — status should switch to "已同步"
   if signed in to iCloud (or "不可用" otherwise).

Thank you for reviewing!
```

## Contact Information

| Field | Value |
|---|---|
| First name | Huazhao |
| Last name | Chen |
| Phone | （**填你愿意公开的手机号**；审核不会拨打，但表单要求必填） |
| Email | chenhuazhaoao@gmail.com |

## App Demo Account

**Not applicable** — DaysHere does not require an account.

## Attachments

不需要附加任何材料。无视频、无文档。
