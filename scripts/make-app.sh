#!/usr/bin/env bash
# 릴리스 빌드 후 메뉴바 전용 .app 번들(build/SitCheck.app)을 만든다.
# 개인용 로컬 빌드라 ad-hoc 서명만 한다.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! out="$(swift build -c release 2>&1)"; then
    echo "$out" | tail -30
    if grep -q "SDK is not supported by the compiler" <<<"$out"; then
        cat <<'HINT'

[안내] Swift 컴파일러와 macOS SDK 버전이 서로 맞지 않습니다 (Command Line Tools가 일부만 업데이트된 상태).
  해결: Command Line Tools를 다시 설치하세요.
    sudo rm -rf /Library/Developer/CommandLineTools
    xcode-select --install
  (Xcode가 설치되어 있다면: sudo xcode-select -s /Applications/Xcode.app)
HINT
    fi
    exit 1
fi
BIN="$(swift build -c release --show-bin-path)/SitCheck"
APP="build/SitCheck.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/SitCheck"

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
echo "만들었어요: $APP"
echo "실행: open $APP   (로그인 시 자동 실행: 시스템 설정 > 일반 > 로그인 항목에 추가)"
