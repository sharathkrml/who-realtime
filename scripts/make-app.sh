#!/bin/sh
# Builds both release executables and wraps them in minimal .app bundles so
# macOS shows proper permission prompts (mic) and remembers consents.
# Two flavors share the package: the menu bar app and a regular windowed app.
# Both read/write one shared model cache (~/Library/Application Support/
# WhoRealtime/Models), so the ~550 MB download happens once per Mac.
set -eu

cd "$(dirname "$0")/.."

# VERSION is the single source of truth; CI reads the same file and both bundle
# plists get this value as CFBundleShortVersionString + CFBundleVersion.
VERSION=$(tr -d '[:space:]' < VERSION)
[ -n "$VERSION" ] || { echo "VERSION is empty" >&2; exit 1; }
BIN_DIR="${BIN_DIR:-.build/release}"

swift build -c release

# App icon (drawn, not asset-catalogued) so both bundles stop looking like
# blank boxes in Finder/Dock.
swift scripts/make-icon.swift

rm -rf "build/WhoRealtime.app" "build/WhoRealtime Windowed.app"

menu_bar_plist() {
    cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Who Realtime</string>
    <key>CFBundleDisplayName</key>
    <string>Who Realtime</string>
    <key>CFBundleIdentifier</key>
    <string>com.whorealtime.app</string>
    <key>CFBundleExecutable</key>
    <string>WhoMenuBar</string>
    <key>CFBundleIconFile</key>
    <string>WhoRealtime.icns</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Who Realtime listens to meetings to transcribe who said what. Everything runs on this Mac; nothing is uploaded.</string>
</dict>
</plist>
PLIST
}

windowed_plist() {
    cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Who Realtime Windowed</string>
    <key>CFBundleDisplayName</key>
    <string>Who Realtime Windowed</string>
    <key>CFBundleIdentifier</key>
    <string>com.whorealtime.windowed</string>
    <key>CFBundleExecutable</key>
    <string>WhoWindowed</string>
    <key>CFBundleIconFile</key>
    <string>WhoRealtime.icns</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Who Realtime listens to meetings to transcribe who said what. Everything runs on this Mac; nothing is uploaded.</string>
</dict>
</plist>
PLIST
}

bundle() { # $1 = app path, $2 = executable name, $3 = plist command name
    APP="$1"
    EXEC="$2"
    mkdir -p "$APP/Contents/MacOS"
    cp "$BIN_DIR/$EXEC" "$APP/Contents/MacOS/$EXEC"
    "$3" > "$APP/Contents/Info.plist"
    if [ -f "build/WhoRealtime.icns" ]; then
        mkdir -p "$APP/Contents/Resources"
        cp "build/WhoRealtime.icns" "$APP/Contents/Resources/"
    fi
    codesign --force --sign - "$APP"
}

bundle "build/WhoRealtime.app" WhoMenuBar menu_bar_plist
bundle "build/WhoRealtime Windowed.app" WhoWindowed windowed_plist

echo "Built build/WhoRealtime.app and build/WhoRealtime Windowed.app"
