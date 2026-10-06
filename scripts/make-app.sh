#!/usr/bin/env bash
# 메뉴바 전용 .app 번들(build/SitCheck.app)과 터미널 분석 도구(build/sitcheck-analyze)를 만든다.
# SwiftPM(Package.swift) 없이 swiftc로 직접 빌드하므로, Command Line Tools의
# PackageDescription이 깨져 있어도 동작한다.
#
# 서명: "SitCheck Local Signing" 인증서가 키체인에 있으면 그것으로 서명해 재빌드해도 카메라 권한이 유지된다
# (scripts/make-signing-identity.sh로 한 번 만들 수 있음). 없으면 ad-hoc 서명을 하고, 이 경우
# 재빌드할 때마다 macOS가 카메라 권한을 다시 물을 수 있다.
# SITCHECK_SIGN_IDENTITY=- 로 ad-hoc을 강제하거나 다른 인증서 이름을 지정할 수 있다.
set -euo pipefail
cd "$(dirname "$0")/.."

ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macos14.0"
OUT="build/obj"
APP="build/SitCheck.app"
SIGN_ID="${SITCHECK_SIGN_IDENTITY:-SitCheck Local Signing}"

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

echo "▶ 분석 도구 빌드"
swiftc -O -whole-module-optimization \
    -target "$TARGET" \
    -module-name sitcheck_analyze \
    -I "$OUT" -L "$OUT" -lSitCheckCore -lsqlite3 \
    -o build/sitcheck-analyze \
    Sources/sitcheck-analyze/main.swift

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
    <key>CFBundleShortVersionString</key><string>0.2.0</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>CFBundleDevelopmentRegion</key><string>ko</string>
    <key>NSCameraUsageDescription</key><string>앉은 자세가 오래 그대로인지, 화면에 가까워졌는지 확인하는 데 써요. 영상은 저장하거나 전송하지 않아요.</string>
    <key>NSMotionUsageDescription</key><string>실험 2: AirPods 머리 동작 데이터가 이 Mac에서 들어오는지 확인하는 데만 써요.</string>
</dict>
</plist>
PLIST

signed="ad-hoc"
if [[ "$SIGN_ID" != "-" ]] && security find-identity -p codesigning 2>/dev/null | grep -q "\"$SIGN_ID\""; then
    if codesign --force --sign "$SIGN_ID" "$APP" 2>/dev/null; then
        signed="$SIGN_ID"
    else
        echo "⚠️  '$SIGN_ID'로 서명하지 못해 ad-hoc으로 서명해요."
    fi
fi
if [[ "$signed" == "ad-hoc" ]]; then
    codesign --force --sign - "$APP"
fi
codesign --force --sign - build/sitcheck-analyze

echo "✅ 만들었어요: $APP (서명: $signed)"
echo "   분석 도구: build/sitcheck-analyze report"
echo "실행: open $APP   (로그인 시 자동 실행: 시스템 설정 > 일반 > 로그인 항목에 추가)"
if [[ "$signed" == "ad-hoc" ]]; then
    echo "참고: 재빌드할 때마다 카메라 권한을 다시 물을 수 있어요. 한 번만 묻게 하려면 ./scripts/make-signing-identity.sh"
fi
