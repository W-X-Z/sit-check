#!/usr/bin/env bash
# 메뉴바 전용 .app 번들(build/SitCheck.app)을 만든다.
# SwiftPM(Package.swift) 없이 swiftc로 직접 빌드하므로, Command Line Tools의
# PackageDescription이 깨져 있어도 동작한다. 개인용 로컬 빌드라 ad-hoc 서명만 한다.
set -euo pipefail
cd "$(dirname "$0")/.."

ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macos14.0"
OUT="build/obj"
APP="build/SitCheck.app"

rm -rf "$OUT" "$APP"
mkdir -p "$OUT" "$APP/Contents/MacOS"

hint() {
    cat <<'HINT'

[안내] 빌드에 실패했습니다. 대부분 Command Line Tools가 반쯤 업데이트된 경우입니다.
  1) sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install
  2) 그래도 안 되면 App Store에서 Xcode를 설치한 뒤:
     sudo xcode-select -s /Applications/Xcode.app
HINT
}
trap 'hint' ERR

echo "▶ SitCheckCore 빌드 ($TARGET)"
swiftc -O -whole-module-optimization -parse-as-library \
    -target "$TARGET" \
    -module-name SitCheckCore \
    -emit-library -static -o "$OUT/libSitCheckCore.a" \
    -emit-module -emit-module-path "$OUT/SitCheckCore.swiftmodule" \
    Sources/SitCheckCore/*.swift

echo "▶ SitCheck 앱 빌드"
swiftc -O -whole-module-optimization -parse-as-library \
    -target "$TARGET" \
    -module-name SitCheck \
    -I "$OUT" -L "$OUT" -lSitCheckCore -lsqlite3 \
    -o "$APP/Contents/MacOS/SitCheck" \
    Sources/SitCheck/*.swift

trap - ERR

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>SitCheck</string>
    <key>CFBundleDisplayName</key><string>자세 코치</string>
    <key>CFBundleIdentifier</key><string>local.sitcheck</string>
    <key>CFBundleExecutable</key><string>SitCheck</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>CFBundleDevelopmentRegion</key><string>ko</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "✅ 만들었어요: $APP"
echo "실행: open $APP   (로그인 시 자동 실행: 시스템 설정 > 일반 > 로그인 항목에 추가)"
