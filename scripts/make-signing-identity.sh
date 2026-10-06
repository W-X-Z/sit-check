#!/usr/bin/env bash
# (선택) 이 Mac에서만 쓰는 자체 서명 코드 서명 인증서 "SitCheck Local Signing"을 로그인 키체인에 만든다.
#
# ad-hoc 서명은 빌드할 때마다 앱 신원(cdhash)이 바뀌어 macOS가 카메라 권한을 다시 묻는다.
# 같은 인증서로 서명하면 신원이 '식별자 + 인증서'로 고정되어 몇 주짜리 측정 중에 재빌드해도 권한이 유지된다.
# 인증서는 이 Mac 밖으로 나가지 않으며, 지우려면 키체인 접근에서 "SitCheck Local Signing"을 삭제하면 된다.
set -euo pipefail

NAME="${SITCHECK_SIGN_IDENTITY:-SitCheck Local Signing}"
KEYCHAIN="${SITCHECK_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
OPENSSL=/usr/bin/openssl   # macOS 기본 LibreSSL (Homebrew OpenSSL 3의 p12는 security import가 못 읽을 수 있음)

if security find-identity -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "\"$NAME\""; then
    echo "이미 있어요: $NAME"
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/openssl.cnf" <<CNF
[ req ]
distinguished_name = dn
x509_extensions = ext
prompt = no
[ dn ]
CN = $NAME
[ ext ]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF

"$OPENSSL" req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -config "$TMP/openssl.cnf" -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
PASS="sitcheck-$$-$RANDOM"
"$OPENSSL" pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$NAME" \
    -out "$TMP/identity.p12" -passout "pass:$PASS"
security import "$TMP/identity.p12" -k "$KEYCHAIN" -P "$PASS" -T /usr/bin/codesign >/dev/null

echo "✅ 만들었어요: $NAME ($KEYCHAIN)"
echo "이제 ./scripts/make-app.sh 로 다시 빌드하면 이 인증서로 서명해요."
echo "처음 서명할 때 'codesign이 키체인의 키를 사용하려고 합니다' 창이 뜨면 로그인 암호를 넣고 '항상 허용'을 누르세요."
echo "카메라 권한은 이 서명으로 처음 실행할 때 한 번 더 묻고, 그 뒤로는 재빌드해도 유지돼요."
