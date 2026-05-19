#!/usr/bin/env bash
# Build a code-signed, entitlement-enriched .app of HengqinTracker
# suitable for cross-device iCloud KVS sync.
#
# Usage:
#   ./script/build_signed_app.sh                 # build + sign + verify
#   ./script/build_signed_app.sh install         # also copy into ~/Applications
#   ./script/build_signed_app.sh install run     # ...and launch
#
# Overridable via env:
#   BUNDLE_ID         (default: com.harry.dayshere)
#   APP_NAME          (default: HengqinTracker)
#   APP_DISPLAY_NAME  (default: 横琴驻留追踪)
#   APP_VERSION       (default: 1.0.0)
#   SIGNING_IDENTITY  (default: best Developer ID Application match)
#   TEAM_ID           (default: parsed from identity)
#   ENTITLEMENTS      (default: script/HengqinTracker.entitlements)
#   PROVISIONING_PROFILE  (default: script/embedded.provisionprofile if present)
#   SKIP_TIMESTAMP=1  (skip --timestamp; useful offline)
#   SKIP_SIGN=1       (build .app but do not sign — for emergency debug only)
#
# Provisioning profile:
#   The full entitlement set (with iCloud KVS) is *restricted* and requires
#   an embedded Developer ID provisioning profile that authorizes
#   com.apple.developer.ubiquity-kvstore-identifier. Without it the OS
#   refuses to launch the app (taskgated "no eligible provisioning profiles").
#
#   To enable iCloud sync:
#     1. developer.apple.com → Identifiers → register App ID com.harry.dayshere
#        with iCloud (Key-Value Storage) capability.
#     2. developer.apple.com → Profiles → "+" → Distribution → Developer ID
#        → pick that App ID + your Developer ID Application cert → download.
#     3. Copy the .provisionprofile into script/embedded.provisionprofile
#        (or set $PROVISIONING_PROFILE).
#     4. Re-run this script.
#
#   Without a profile, this script falls back to LITE entitlements
#   (no iCloud) so the build still launches and import/export still work.

set -euo pipefail

# ─── Defaults ─────────────────────────────────────────────────
BUNDLE_ID="${BUNDLE_ID:-com.harry.dayshere}"
APP_NAME="${APP_NAME:-HengqinTracker}"
APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-横琴驻留追踪}"
APP_VERSION="${APP_VERSION:-1.0.0}"
MIN_SYSTEM_VERSION="15.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ENTITLEMENTS="${ENTITLEMENTS:-$ROOT_DIR/script/HengqinTracker.entitlements}"

INSTALL_DIR="$HOME/Applications"
INSTALLED_APP_BUNDLE="$INSTALL_DIR/$APP_NAME.app"

PROVISIONING_PROFILE="${PROVISIONING_PROFILE:-$ROOT_DIR/script/embedded.provisionprofile}"
ENTITLEMENTS_LITE="$ROOT_DIR/script/HengqinTracker.entitlements.lite"

# ─── Discover signing identity ────────────────────────────────
discover_identity() {
    if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
        echo "$SIGNING_IDENTITY"
        return
    fi
    local found
    found=$(security find-identity -v -p codesigning 2>/dev/null \
        | grep "Developer ID Application" \
        | head -1 \
        | sed -E 's/^[[:space:]]*[0-9]+\)[[:space:]]+[A-F0-9]+[[:space:]]+"([^"]+)"$/\1/')
    if [[ -z "$found" ]]; then
        echo "ERROR: No 'Developer ID Application' identity in keychain." >&2
        echo "Run: security find-identity -v -p codesigning" >&2
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
    # Identities look like:  "Developer ID Application: Huazhao Chen (HYF3XBWBL2)"
    if [[ "$identity" =~ \(([A-Z0-9]{10})\) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "ERROR: Could not parse Team ID from identity: $identity" >&2
        exit 1
    fi
}

IDENTITY=$(discover_identity)
TEAM=$(derive_team_id "$IDENTITY")

# Pick entitlement set based on presence of provisioning profile.
if [[ -f "$PROVISIONING_PROFILE" ]]; then
    ACTIVE_ENTITLEMENTS="$ENTITLEMENTS"
    PROFILE_NOTE="with iCloud (profile embedded)"
else
    ACTIVE_ENTITLEMENTS="$ENTITLEMENTS_LITE"
    PROFILE_NOTE="LITE — no iCloud (no provisioning profile in $(basename "$PROVISIONING_PROFILE"))"
fi

echo "──────────────────────────────────────────"
echo " App name        : $APP_NAME ($APP_DISPLAY_NAME)"
echo " Bundle ID       : $BUNDLE_ID"
echo " Version         : $APP_VERSION"
echo " Signing identity: $IDENTITY"
echo " Team ID         : $TEAM"
echo " Entitlements    : ${ACTIVE_ENTITLEMENTS#$ROOT_DIR/}"
echo " Profile         : $PROFILE_NOTE"
echo "──────────────────────────────────────────"

# ─── Build release binary ─────────────────────────────────────
echo "▸ swift build -c release"
swift build -c release
BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"
if [[ ! -f "$BUILD_BINARY" ]]; then
    echo "ERROR: release binary not found at $BUILD_BINARY" >&2
    exit 1
fi

# ─── Lay out .app ─────────────────────────────────────────────
echo "▸ assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

# Build .icns if we have the high-res icon source
if [[ -f "$ROOT_DIR/icons/icon128.png" ]]; then
    ICONSET="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "$ICONSET"
    # iconutil requires a complete iconset with specific names.
    # We upscale from icon128 — quality won't be amazing but ships.
    for sz in 16 32 64 128 256 512; do
        sips -z "$sz" "$sz" "$ROOT_DIR/icons/icon128.png" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null 2>&1 || true
        retina_sz=$((sz * 2))
        sips -z "$retina_sz" "$retina_sz" "$ROOT_DIR/icons/icon128.png" --out "$ICONSET/icon_${sz}x${sz}@2x.png" >/dev/null 2>&1 || true
    done
    iconutil -c icns "$ICONSET" -o "$APP_RESOURCES/AppIcon.icns" 2>/dev/null && echo "  · AppIcon.icns generated" || true
    rm -rf "$(dirname "$ICONSET")"
fi

# Info.plist
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
  <string>用于在"在地图上选择…"中标定坐标档案的中心点</string>
</dict>
</plist>
PLIST

# ─── Embed provisioning profile (if any) ──────────────────────
if [[ -f "$PROVISIONING_PROFILE" ]]; then
    cp "$PROVISIONING_PROFILE" "$APP_CONTENTS/embedded.provisionprofile"
    echo "▸ embedded provisioning profile"
fi

# ─── Sign ─────────────────────────────────────────────────────
if [[ "${SKIP_SIGN:-}" == "1" ]]; then
    echo "▸ SKIP_SIGN=1 — skipping codesign"
else
    if [[ ! -f "$ACTIVE_ENTITLEMENTS" ]]; then
        echo "ERROR: entitlements file missing at $ACTIVE_ENTITLEMENTS" >&2
        exit 1
    fi

    # codesign does not perform the $(TeamIdentifierPrefix) substitution that
    # Xcode does at build time. Materialize a concrete copy with the real
    # team prefix injected.
    RESOLVED_ENTITLEMENTS="$DIST_DIR/HengqinTracker.entitlements.resolved.plist"
    sed -e "s|\\\$(TeamIdentifierPrefix)|${TEAM}.|g" "$ACTIVE_ENTITLEMENTS" > "$RESOLVED_ENTITLEMENTS"

    CODESIGN_ARGS=(
        --force
        --options runtime
        --sign "$IDENTITY"
        --entitlements "$RESOLVED_ENTITLEMENTS"
        --identifier "$BUNDLE_ID"
    )
    if [[ "${SKIP_TIMESTAMP:-}" != "1" ]]; then
        CODESIGN_ARGS+=(--timestamp)
    fi

    echo "▸ codesign $APP_BUNDLE"
    codesign "${CODESIGN_ARGS[@]}" "$APP_BUNDLE"

    echo "▸ codesign --verify --deep --strict"
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

    echo "▸ codesign --display --entitlements"
    codesign --display --entitlements - "$APP_BUNDLE" || true

    echo "▸ spctl assessment (Developer ID, not notarized — 'rejected' is expected until you run notarytool)"
    spctl --assess --verbose=4 --type execute "$APP_BUNDLE" || true
fi

echo "──────────────────────────────────────────"
echo " ✓ Signed bundle ready: $APP_BUNDLE"
echo "──────────────────────────────────────────"

# ─── Install / run ────────────────────────────────────────────
ACTIONS=("${@:-}")
for action in "${ACTIONS[@]}"; do
    case "$action" in
        install)
            echo "▸ install → $INSTALLED_APP_BUNDLE"
            pkill -x "$APP_NAME" >/dev/null 2>&1 || true
            mkdir -p "$INSTALL_DIR"
            rm -rf "$INSTALLED_APP_BUNDLE"
            cp -R "$APP_BUNDLE" "$INSTALLED_APP_BUNDLE"
            xattr -d com.apple.quarantine "$INSTALLED_APP_BUNDLE" 2>/dev/null || true
            ;;
        run)
            [[ -d "$INSTALLED_APP_BUNDLE" ]] || cp -R "$APP_BUNDLE" "$INSTALLED_APP_BUNDLE"
            /usr/bin/open -n "$INSTALLED_APP_BUNDLE"
            ;;
        "")
            ;;
        *)
            echo "WARN: unknown action '$action' (expected: install|run)" >&2
            ;;
    esac
done

echo "Done."
