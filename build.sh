#!/bin/bash
# Compile GTA VI Watch, crée le bundle .app et le paquet d'installation .pkg
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="GTA VI Watch"
BINARY="GTA6Watch"
BUNDLE_ID="com.torjant.gta6watch"
VERSION="1.4"
APP_DIR="build/$APP_NAME.app"

echo "── Nettoyage"
rm -rf build
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

echo "── Compilation Swift (optimisée, Apple Silicon natif)"
swiftc -O -wmo -parse-as-library \
  -target arm64-apple-macos14.0 \
  Sources/*.swift \
  -o "$APP_DIR/Contents/MacOS/$BINARY"

echo "── Icône"
swift make_icon.swift
iconutil -c icns build/AppIcon.iconset -o "$APP_DIR/Contents/Resources/AppIcon.icns"

echo "── Info.plist"
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>$BINARY</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHumanReadableCopyright</key><string>© 2026 Torjant — GNU AGPL v3</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSSupportsAutomaticTermination</key><false/>
    <key>NSAppTransportSecurity</key><dict>
        <key>NSAllowsArbitraryLoads</key><false/>
    </dict>
</dict>
</plist>
PLIST

echo "── Entitlements (App Sandbox : réseau sortant uniquement)"
cat > build/entitlements.plist <<'ENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key><true/>
    <key>com.apple.security.network.client</key><true/>
</dict>
</plist>
ENT

echo "── Signature (ad hoc + Hardened Runtime + Sandbox)"
codesign --force --options runtime \
  --entitlements build/entitlements.plist \
  --sign - "$APP_DIR"

echo "── Création du paquet .pkg"
pkgbuild --component "$APP_DIR" \
  --install-location /Applications \
  --identifier "$BUNDLE_ID.pkg" \
  --version "$VERSION" \
  "build/GTA-VI-Watch-$VERSION.pkg"

echo ""
echo "✅ Terminé :"
echo "   App  : $APP_DIR"
echo "   PKG  : build/GTA-VI-Watch-$VERSION.pkg"
