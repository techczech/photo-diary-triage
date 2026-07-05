#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SWIFT_BUILD_ARGS=()
if [[ -n "${PDT_BUILD_PATH:-}" ]]; then
    SWIFT_BUILD_ARGS+=(--build-path "$PDT_BUILD_PATH")
    BUILD_DIR="$PDT_BUILD_PATH/arm64-apple-macosx/debug"
else
    BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/debug"
fi
if [[ "${PDT_DISABLE_SWIFTPM_SANDBOX:-0}" == "1" ]]; then
    SWIFT_BUILD_ARGS+=(--disable-sandbox)
fi
APP_DIR="$ROOT_DIR/dist/Walkfolio.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
PLIST_PATH="$APP_DIR/Contents/Info.plist"
EXECUTABLE="$BUILD_DIR/PhotoDiaryTriage"
RELEASE_ENV="$ROOT_DIR/APP_RELEASE.env"

source "$RELEASE_ENV"

cd "$ROOT_DIR"
swift build "${SWIFT_BUILD_ARGS[@]}"

pkill -f "$APP_DIR/Contents/MacOS/PhotoDiaryTriage" 2>/dev/null || true
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$EXECUTABLE" "$MACOS_DIR/PhotoDiaryTriage"
cp "$RELEASE_ENV" "$RESOURCES_DIR/APP_RELEASE.env"
xattr -cr "$APP_DIR"
codesign --remove-signature "$MACOS_DIR/PhotoDiaryTriage" 2>/dev/null || true

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>PhotoDiaryTriage</string>
    <key>CFBundleIdentifier</key>
    <string>local.photo-diary-triage</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Walkfolio</string>
    <key>CFBundleDisplayName</key>
    <string>Walkfolio</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_BUILD}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>PDTLatestFeatureSlug</key>
    <string>${APP_FEATURE_SLUG}</string>
</dict>
</plist>
EOF

codesign --force --sign - --timestamp=none "$APP_DIR"

echo "Built app bundle at: $APP_DIR"
