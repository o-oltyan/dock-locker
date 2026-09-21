#!/bin/sh
# Creates the self-signed code-signing certificate DockLocker builds are signed
# with. A stable certificate gives the app a stable designated requirement, so
# the Accessibility grant survives updates (ad-hoc signatures change per build).
#
#   scripts/make-signing-cert.sh            # create + import into login keychain
#   scripts/make-signing-cert.sh --export   # also print base64 .p12 for CI
#
# For CI, store the base64 output as the SIGNING_CERT_P12 secret and the
# password you chose as SIGNING_CERT_PASSWORD. Keep the .p12 private: anyone
# holding it can produce builds that inherit your users' grants.
set -eu

NAME="${CERT_NAME:-DockLocker Self-Signed}"
KEYCHAIN="${KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
EXPORT=0
[ "${1:-}" = "--export" ] && EXPORT=1

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "Certificate '$NAME' already exists in $KEYCHAIN" >&2
    exit 1
fi

PASSWORD="${P12_PASSWORD:-}"
if [ -z "$PASSWORD" ]; then
    printf "Password for the exported .p12: " >&2
    stty -echo; read -r PASSWORD; stty echo; echo >&2
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cat >"$WORK/cert.conf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

# System LibreSSL on purpose: OpenSSL 3 writes a .p12 MAC that
# `security import` rejects.
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -config "$WORK/cert.conf" -keyout "$WORK/key.pem" -out "$WORK/cert.pem" 2>/dev/null
/usr/bin/openssl pkcs12 -export -name "$NAME" -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
    -out "$WORK/cert.p12" -passout "pass:$PASSWORD"

security import "$WORK/cert.p12" -k "$KEYCHAIN" -P "$PASSWORD" -T /usr/bin/codesign
echo "Imported '$NAME'. The first 'make app' may ask for keychain access — choose Always Allow." >&2

if [ "$EXPORT" = 1 ]; then
    base64 -i "$WORK/cert.p12"
fi
