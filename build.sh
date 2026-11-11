#!/usr/bin/env bash
# Compila o Radar de Outliers sem Gradle: aapt2 + javac + d8 + apksigner.
set -euo pipefail
: "${KS_PASS:?Informe a senha da chave em KS_PASS}"
cd "$(dirname "$0")"
SDK="${SDK:-/tmp/claude-0/-home-user/a95a2058-830b-5f11-8b3e-0ec8952336aa/scratchpad/sdk}"
BT="$SDK/android-15"            # build-tools 35.0.1
JAR="$SDK/android-35/android.jar"
OUT=build
rm -rf "$OUT" && mkdir -p "$OUT/res" "$OUT/gen" "$OUT/classes" "$OUT/assets"

# chave de assinatura (guarde este arquivo: atualizações precisam da mesma chave)
if [ ! -f radar.keystore ]; then
  keytool -genkeypair -keystore radar.keystore -storepass "$KS_PASS" -keypass "$KS_PASS" \
    -alias radar -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Radar de Outliers" >/dev/null 2>&1
fi
SHA1=$(keytool -list -v -keystore radar.keystore -storepass "$KS_PASS" -alias radar 2>/dev/null | awk '/SHA1:/{print $2; exit}')

# assets (com o SHA-1 real na tela da chave)
cp -r assets/. "$OUT/assets/"
sed -i "s/__SHA1__/$SHA1/" "$OUT/assets/index.html"

"$BT/aapt2" compile --dir res -o "$OUT/res.zip"
"$BT/aapt2" link -I "$JAR" --manifest AndroidManifest.xml -A "$OUT/assets" \
  --min-sdk-version 26 --target-sdk-version 35 --version-code 8 --version-name 1.7 \
  --java "$OUT/gen" -o "$OUT/base.apk" "$OUT/res.zip"

javac -nowarn -source 11 -target 11 -encoding UTF-8 -classpath "$JAR" -d "$OUT/classes" \
  $(find src "$OUT/gen" -name '*.java') 2>&1 | grep -v "bootstrap classpath\|^1 warning\|^warning" || true
"$BT/d8" --release --min-api 26 --lib "$JAR" --output "$OUT" $(find "$OUT/classes" -name '*.class')

cp "$OUT/base.apk" "$OUT/unsigned.apk"
(cd "$OUT" && zip -q -j unsigned.apk classes.dex)
"$BT/zipalign" -f -p 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"
"$BT/apksigner" sign --ks radar.keystore --ks-pass pass:"$KS_PASS" --key-pass pass:"$KS_PASS" \
  --ks-key-alias radar --out RadarDeOutliers.apk "$OUT/aligned.apk"
"$BT/apksigner" verify --print-certs RadarDeOutliers.apk | head -3
echo "SHA-1: $SHA1"
ls -la RadarDeOutliers.apk
