#!/usr/bin/env bash
# build.sh — compiles Swift → .app, installs to /Applications, creates DMG
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/CORE.app"
DMG="$DIR/CORE.dmg"
RELEASE_DIR="$DIR/release-builds/macos"
LEGACY_APP="$DIR/Outlook Reminder Center.app"
LEGACY_DMG="$DIR/Outlook Reminder Center.dmg"
SRC_DIR="$DIR/src"
SCRIPT="$SRC_DIR/macos/outlook-reminder-center.sh"
BINARY="$APP/Contents/MacOS/CORE"
ICNS="$SRC_DIR/macos/AppIcon.icns"

# Remove stale legacy artifacts so Finder doesn't accidentally open old branding.
rm -rf "$LEGACY_APP"
rm -f "$LEGACY_DMG"

# ── 1. Validate icon ─────────────────────────────────────────────────────────
echo "▶ Validating icon…"
if [[ ! -f "$ICNS" ]]; then
    echo "❌ Missing required icon: $ICNS"
    exit 1
fi
echo "   Icon: $ICNS"

# ── 2. Compile Swift binary ──────────────────────────────────────────────────
echo "▶ Compiling Swift…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

swiftc "$SRC_DIR"/shared/*.swift "$SRC_DIR"/macos/*.swift \
  -o "$BINARY" \
  -framework Cocoa \
  -framework Foundation \
  2>&1

# ── 3. Bundle icon ────────────────────────────────────────────────────────────
cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"

# ── 4. Write Info.plist ───────────────────────────────────────────────────────
echo "▶ Writing Info.plist…"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>CORE</string>
    <key>CFBundleIdentifier</key>
    <string>com.core-reminder.menubar</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>CORE</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "▶ Writing PkgInfo…"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# ── 6. Embed shell script in bundle ──────────────────────────────────────────
echo "▶ Embedding shell script in bundle…"
cp "$SCRIPT" "$APP/Contents/Resources/outlook-reminder-center.sh"
chmod +x "$APP/Contents/Resources/outlook-reminder-center.sh"
cp "$DIR/ABOUT.md"   "$APP/Contents/Resources/ABOUT.md"
echo "▶ Installing to /Applications…"
pkill -f "CORE" 2>/dev/null || true
if cp -rf "$APP" "/Applications/" 2>/dev/null; then
    echo "   Installed: /Applications/CORE.app"
else
    echo "   Needs admin rights — requesting password…"
    osascript -e "do shell script \"cp -rf '${APP}' '/Applications/'\" \
        with administrator privileges" \
        && echo "   Installed: /Applications/CORE.app" \
        || echo "   ⚠ Skipped /Applications install (cancelled or denied)"
fi

# ── 7. Build DMG with drag-to-install Applications symlink ───────────────────
echo "▶ Building DMG…"
rm -rf /tmp/orc-dmg-staging
mkdir -p /tmp/orc-dmg-staging
cp -r "$APP"    /tmp/orc-dmg-staging/
ln -s /Applications /tmp/orc-dmg-staging/Applications

rm -f "$DMG"
hdiutil create \
  -volname "CORE" \
  -srcfolder /tmp/orc-dmg-staging \
  -format UDZO \
  "$DMG"

echo "▶ Publishing release artifacts…"
mkdir -p "$RELEASE_DIR"
rm -rf "$RELEASE_DIR/CORE.app"
cp -R "$APP" "$RELEASE_DIR/CORE.app"
cp -f "$DMG" "$RELEASE_DIR/CORE.dmg"

echo ""
echo "✅  Done:"
echo "   App : $APP"
echo "   App : /Applications/CORE.app"
echo "   DMG : $DMG"
echo "   Release : $RELEASE_DIR"
echo ""
echo "To launch: open -a 'CORE'"
