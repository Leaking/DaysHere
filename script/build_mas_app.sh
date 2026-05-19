#!/usr/bin/env bash
# Build + sign + package the Mac App Store version of DaysHere.
#
# Output: dist/DaysHere.pkg   (Mac App Store .pkg, ready for Transporter upload)
#
# Usage:
#   ./script/build_mas_app.sh                  # build + sign + productbuild
#   ./script/build_mas_app.sh upload           # ...then upload via Transporter
#
# Required keychain identities:
#   3rd Party Mac Developer Application: <Name> (<TeamID>)
#   3rd Party Mac Developer Installer:    <Name> (<TeamID>)
#
# Required provisioning profile:
#   script/mas-distribution.provisionprofile   ← Mac App Store profile from
#                                                developer.apple.com → Profiles
#                                                → Distribution → Mac App Store
#
# Override via env:
#   BUNDLE_ID                 (default: com.harry.dayshere)
#   APP_NAME                  (default: HengqinTracker, the executable name)
#   APP_DISPLAY_NAME          (default: 一年几天)
#   APP_VERSION               (default: 1.0.0)
#   APP_SIGNING_IDENTITY      (default: best "3rd Party Mac Developer
#                                        Application" match)
#   INSTALLER_SIGNING_IDENTITY (default: best "3rd Party Mac Developer
#                                        Installer" match)
#   PROVISIONING_PROFILE      (default: script/mas-distribution.provisionprofile)
#   TEAM_ID                   (default: parsed from APP_SIGNING_IDENTITY)

set -euo pipefail

BUNDLE_ID="${BUNDLE_ID:-com.harry.dayshere}"
APP_NAME="${APP_NAME:-HengqinTracker}"
APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-一年几天}"
APP_VERSION="${APP_VERSION:-1.0.0}"
MIN_SYSTEM_VERSION="15.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/DaysHere.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
PKG_PATH="$DIST_DIR/DaysHere.pkg"

ENTITLEMENTS="$ROOT_DIR/script/HengqinTracker.entitlements.mas"
PROVISIONING_PROFILE="${PROVISIONING_PROFILE:-$ROOT_DIR/script/mas-distribution.provisionprofile}"

# ─── Discover signing identities ──────────────────────────────
discover_identity() {
    local needle="$1"
    local override="$2"
    if [[ -n "$override" ]]; then
        echo "$override"
        return
    fi
    local found
    found=$(security find-identity -v -p codesigning 2>/dev/null \
        | grep "$needle" \
        | head -1 \
        | sed -E 's/^[[:space:]]*[0-9]+\)[[:space:]]+[A-F0-9]+[[:space:]]+"([^"]+)"$/\1/')
    if [[ -z "$found" ]]; then
        echo "ERROR: No '$needle' identity in keychain." >&2
        echo "  Mac App Store requires both:" >&2
        echo "    · 3rd Party Mac Developer Application: <Name> (<Team>)" >&2
        echo "    · 3rd Party Mac Developer Installer:   <Name> (<Team>)" >&2
        echo "  Create them at developer.apple.com → Certificates → +" >&2
        exit 1
    fi
    echo "$found"
}

derive_team_id() {
    local identity="$1"
    if [[ -n "${TEAM_ID:-}" ]]; then
        echo "$TEAM_ID"
        return
    fi
    if [[ "$identity" =~ \(([A-Z0-9]{10})\) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "ERROR: Could not parse Team ID from identity: $identity" >&2
        exit 1
    fi
}

APP_IDENTITY=$(discover_identity "3rd Party Mac Developer Application" "${APP_SIGNING_IDENTITY:-}")
INSTALLER_IDENTITY=$(discover_identity "3rd Party Mac Developer Installer" "${INSTALLER_SIGNING_IDENTITY:-}")
TEAM=$(derive_team_id "$APP_IDENTITY")

if [[ ! -f "$PROVISIONING_PROFILE" ]]; then
    echo "ERROR: Mac App Store provisioning profile missing." >&2
    echo "  Expected at: ${PROVISIONING_PROFILE#$ROOT_DIR/}" >&2
    echo "" >&2
    echo "  How to get one:" >&2
    echo "    1. developer.apple.com → Profiles → '+'" >&2
    echo "    2. Distribution → Mac App Store" >&2
    echo "    3. Pick App ID com.harry.dayshere" >&2
    echo "    4. Pick the 3rd Party Mac Developer Application certificate" >&2
    echo "    5. Download and save as $PROVISIONING_PROFILE" >&2
    exit 1
fi

echo "──────────────────────────────────────────"
echo " Target          : Mac App Store distribution"
echo " App name        : $APP_DISPLAY_NAME ($APP_NAME executable)"
echo " Bundle ID       : $BUNDLE_ID"
echo " Version         : $APP_VERSION"
echo " App identity    : $APP_IDENTITY"
echo " Installer ident.: $INSTALLER_IDENTITY"
echo " Team ID         : $TEAM"
echo " Entitlements    : ${ENTITLEMENTS#$ROOT_DIR/}"
echo " Profile         : ${PROVISIONING_PROFILE#$ROOT_DIR/}"
echo "──────────────────────────────────────────"

# ─── Build release binary ─────────────────────────────────────
echo "▸ swift build -c release"
swift build -c release
BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"
if [[ ! -f "$BUILD_BINARY" ]]; then
    echo "ERROR: release binary not found at $BUILD_BINARY" >&2
    exit 1
fi

# ─── Assemble .app ────────────────────────────────────────────
echo "▸ assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE" "$PKG_PATH"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$PROVISIONING_PROFILE" "$APP_CONTENTS/embedded.provisionprofile"

# AppIcon.icns from the highest-res source
ICON_SOURCE=""
for candidate in icon1024.png icon512.png icon128.png; do
    if [[ -f "$ROOT_DIR/icons/$candidate" ]]; then
        ICON_SOURCE="$ROOT_DIR/icons/$candidate"
        break
    fi
done
if [[ -n "$ICON_SOURCE" ]]; then
    ICONSET="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for sz in 16 32 64 128 256 512; do
        sips -z "$sz" "$sz" "$ICON_SOURCE" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null 2>&1 || true
        retina_sz=$((sz * 2))
        sips -z "$retina_sz" "$retina_sz" "$ICON_SOURCE" --out "$ICONSET/icon_${sz}x${sz}@2x.png" >/dev/null 2>&1 || true
    done
    iconutil -c icns "$ICONSET" -o "$APP_RESOURCES/AppIcon.icns" 2>/dev/null && \
        echo "  · AppIcon.icns generated from $(basename "$ICON_SOURCE")" || true
    rm -rf "$(dirname "$ICONSET")"
fi

# Info.plist — same shape as the Developer ID path, plus MAS-specific keys
cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>© 2026 Huazhao Chen</string>
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>"一年几天"用于在"在地图上选择…"中标定坐标档案的中心点</string>
  <key>ITSAppUsesNonExemptEncryption</key>
  <false/>
</dict>
</plist>
PLIST

# ─── Sign ─────────────────────────────────────────────────────
RESOLVED_ENTITLEMENTS="$DIST_DIR/HengqinTracker.entitlements.mas.resolved.plist"
sed -e "s|\\\$(TeamIdentifierPrefix)|${TEAM}.|g" "$ENTITLEMENTS" > "$RESOLVED_ENTITLEMENTS"

echo "▸ codesign $APP_BUNDLE (Mac App Distribution)"
codesign --force \
    --options runtime \
    --timestamp \
    --sign "$APP_IDENTITY" \
    --entitlements "$RESOLVED_ENTITLEMENTS" \
    --identifier "$BUNDLE_ID" \
    "$APP_BUNDLE"

echo "▸ codesign --verify"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

# ─── productbuild → .pkg ──────────────────────────────────────
echo "▸ productbuild $PKG_PATH (Mac Installer Distribution)"
productbuild \
    --component "$APP_BUNDLE" /Applications \
    --sign "$INSTALLER_IDENTITY" \
    --product "$INFO_PLIST" \
    "$PKG_PATH"

echo "▸ pkgutil --check-signature"
pkgutil --check-signature "$PKG_PATH" | head -10

echo "──────────────────────────────────────────"
echo " ✓ MAS package ready: ${PKG_PATH#$ROOT_DIR/}"
echo "──────────────────────────────────────────"

# ─── Upload (optional) ────────────────────────────────────────
case "${1:-}" in
    upload)
        if ! command -v xcrun >/dev/null 2>&1; then
            echo "xcrun not on PATH; cannot upload" >&2
            exit 1
        fi
        echo "▸ xcrun altool --upload-app"
        echo "  NOTE: This requires App-specific password in keychain item"
        echo "  'altool-credentials', OR set APP_STORE_CONNECT_API_KEY env vars."
        xcrun altool --upload-app \
            --type osx \
            --file "$PKG_PATH" \
            --username "742223410@qq.com" \
            --password "@keychain:altool-credentials"
        ;;
    "")
        echo ""
        echo "Next steps:"
        echo "  1. Open Transporter.app, sign in with 742223410@qq.com"
        echo "  2. Drag $PKG_PATH into Transporter, click Deliver"
        echo "  Or: $0 upload   (uses xcrun altool with keychain credentials)"
        ;;
    *)
        echo "Unknown action: $1" >&2
        exit 2
        ;;
esac
