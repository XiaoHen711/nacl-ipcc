#!/usr/bin/env bash
# 在 macOS 上构建未签名 IPA（TrollStore 可直接安装，或用爱思助手签名后安装）
set -euo pipefail
cd "$(dirname "$0")/.."

command -v xcodebuild >/dev/null || { echo "需要 Xcode"; exit 1; }
command -v xcodegen  >/dev/null || { echo "需要 xcodegen: brew install xcodegen"; exit 1; }

xcodegen generate

xcodebuild \
  -project NaCl.xcodeproj \
  -scheme NaCl \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  build

APP="build/Build/Products/Release-iphoneos/NaCl.app"
test -d "$APP" || { echo "找不到 $APP"; exit 1; }

rm -rf Payload dist
mkdir -p Payload dist
cp -R "$APP" Payload/
zip -qry dist/NaCl-unsigned.ipa Payload

echo
echo "产物: dist/NaCl-unsigned.ipa"
shasum -a 256 dist/NaCl-unsigned.ipa
